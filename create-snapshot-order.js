const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL, SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY, RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
const uuid=v=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v||"");
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error("Database request failed");e.status=r.status;throw e}return d}
async function rpc(name,body){return db("rpc/"+name,{method:"POST",body:JSON.stringify(body)});}
async function rp(path,options={}){const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");const r=await fetch("https://api.razorpay.com/v1/"+path,{...options,headers:{Authorization:"Basic "+auth,"Content-Type":"application/json",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error(d?.error?.description||"Razorpay request failed");e.status=r.status;throw e}return d}
async function verifyCustomer(authorization,booking){
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization||"");
 if(!match||match[1].length>8192){const e=new Error("Customer login required");e.httpStatus=401;throw e;}
 const r=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
 if(!r.ok){const e=new Error("Customer session invalid");e.httpStatus=401;throw e;}
 const user=await r.json(),digits=v=>String(v||"").replace(/\D/g,""),norm=v=>digits(v).length===10?"91"+digits(v):digits(v);
 if(!user.id||!user.phone_confirmed_at||user.id!==booking.customer_user_id||norm(user.phone)!==norm(booking.phone)){const e=new Error("Booking ownership mismatch");e.httpStatus=403;throw e;}
 return user.id;
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 try{
  const body=JSON.parse(event.body||"{}"),snapshotId=body.snapshot_id;
  if(!uuid(snapshotId))return json(400,{success:false,error:"Payable Snapshot ID सही नहीं है।"});
  const snapshots=await db("srk_booking_payable_snapshots?select=id,booking_id,bill_id,amount_paise,currency&id=eq."+encodeURIComponent(snapshotId)+"&limit=1");
  const snapshot=snapshots?.[0];if(!snapshot)return json(404,{success:false,error:"अंतिम भुगतान snapshot नहीं मिला।"});
  const bookings=await db("service_bookings?select=id,phone,customer_user_id,payment_status,payment_method,service_category_code,final_bill_id,timer_state&id=eq."+encodeURIComponent(snapshot.booking_id)+"&limit=1");
  const booking=bookings?.[0];if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
  await verifyCustomer(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(!booking.service_category_code||booking.timer_state!=="stopped"||booking.final_bill_id!==snapshot.bill_id)return json(409,{success:false,error:"यह snapshot अब इस अंतिम टाइमर बिल से मेल नहीं खाता।"});
  if(booking.payment_status==="paid")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही हो चुका है।"});
  if(String(booking.payment_method||"").toLowerCase()==="cash")return json(409,{success:false,error:"आपने नकद भुगतान चुना है। इलेक्ट्रिशियन की प्राप्ति पुष्टि की प्रतीक्षा करें।"});
  const cashIntents=await db("srk_cash_payment_intents?select=id,status&payable_snapshot_id=eq."+encodeURIComponent(snapshotId)+"&limit=1");
  if(cashIntents?.length)return json(409,{success:false,error:"इस snapshot के लिए नकद भुगतान चुना जा चुका है। Razorpay ऑर्डर नहीं बनाया जा सकता।"});
  if(snapshot.currency!=="INR"||!Number.isSafeInteger(Number(snapshot.amount_paise))||Number(snapshot.amount_paise)<100)return json(409,{success:false,error:"इस राशि के लिए Razorpay भुगतान उपलब्ध नहीं है।"});
  const token=crypto.randomUUID();
  const claim=await rpc("srk_claim_razorpay_snapshot_order",{p_snapshot_id:snapshotId,p_creation_token:token});
  const state=Array.isArray(claim)?claim[0]:claim;
  if(!state?.success&&state?.busy)return json(409,{success:false,error:"पेमेंट ऑर्डर बन रहा है। कुछ सेकंड बाद दोबारा कोशिश करें।",retry_after_seconds:state.retry_after_seconds||5});
  if(!state?.success)return json(409,{success:false,error:"पेमेंट ऑर्डर अभी उपलब्ध नहीं है।"});
  if(state.status==="paid")return json(409,{success:false,error:"इस snapshot का भुगतान पहले ही दर्ज है।"});
  if(!state.claimed){
   if(!state.provider_order_id)return json(409,{success:false,error:"पहले बने पेमेंट ऑर्डर का विवरण उपलब्ध नहीं है।"});
   return json(200,{success:true,key_id:RAZORPAY_KEY_ID,order_id:state.provider_order_id,amount:state.amount_paise,currency:state.currency,snapshot_id:snapshotId,reused:true});
  }
  const order=await rp("orders",{method:"POST",body:JSON.stringify({
   amount:Number(state.amount_paise),currency:state.currency,receipt:("SRK-"+snapshotId).slice(0,40),
   notes:{service:"SRK ELECTRONIC",booking_id:booking.id,payable_snapshot_id:snapshotId,bill_id:snapshot.bill_id}
  })});
  if(order.status!=="created"||order.amount!==Number(state.amount_paise)||order.currency!==state.currency)throw new Error("Razorpay returned an order that does not match the payable snapshot");
  const bound=await rpc("srk_bind_razorpay_snapshot_order",{
   p_snapshot_id:snapshotId,p_creation_token:token,p_provider_order_id:order.id,
   p_amount_paise:Number(order.amount),p_currency:order.currency
  });
  const boundResult=Array.isArray(bound)?bound[0]:bound;
  if(!boundResult?.success)throw new Error("Razorpay order could not be bound to payable snapshot");
  return json(200,{success:true,key_id:RAZORPAY_KEY_ID,order_id:order.id,amount:order.amount,currency:order.currency,snapshot_id:snapshotId,reused:false});
 }catch(e){
  if(e.httpStatus===401||e.httpStatus===403)return json(e.httpStatus,{success:false,error:e.httpStatus===401?"भुगतान के लिए ग्राहक OTP लॉगिन करें।":"यह snapshot आपके सत्यापित ग्राहक खाते से जुड़ा नहीं है।"});
  console.error("create-snapshot-order error:",e?.status||e?.name||"Unknown");
  return json(502,{success:false,error:"अंतिम snapshot से पेमेंट ऑर्डर नहीं बन पाया। कुछ देर बाद कोशिश करें।"});
 }
};

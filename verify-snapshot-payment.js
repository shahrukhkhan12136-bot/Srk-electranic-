const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL, SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY, RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error("Database request failed");e.status=r.status;throw e}return d}
async function rpc(name,body){return db("rpc/"+name,{method:"POST",body:JSON.stringify(body)});}
async function verifyCustomer(authorization,booking){
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization||"");
 if(!match||match[1].length>8192){const e=new Error("Customer login required");e.httpStatus=401;throw e;}
 const r=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
 if(!r.ok){const e=new Error("Customer session invalid");e.httpStatus=401;throw e;}
 const user=await r.json(),digits=v=>String(v||"").replace(/\D/g,""),norm=v=>digits(v).length===10?"91"+digits(v):digits(v);
 if(!user.id||!user.phone_confirmed_at||user.id!==booking.customer_user_id||norm(user.phone)!==norm(booking.phone)){const e=new Error("Booking ownership mismatch");e.httpStatus=403;throw e;}
}
async function payment(id){const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");const r=await fetch("https://api.razorpay.com/v1/payments/"+encodeURIComponent(id),{headers:{Authorization:"Basic "+auth}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok)throw new Error("Payment lookup failed");return d}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 try{
  const body=JSON.parse(event.body||"{}"),snapshotId=body.snapshot_id,payId=body.razorpay_payment_id,orderId=body.razorpay_order_id,sig=body.razorpay_signature;
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(snapshotId||"")||!/^pay_[A-Za-z0-9]+$/.test(payId||"")||!/^order_[A-Za-z0-9]+$/.test(orderId||"")||!/^[a-f0-9]{64}$/i.test(sig||""))return json(400,{success:false,error:"भुगतान विवरण सही नहीं हैं।"});
  const expected=crypto.createHmac("sha256",RAZORPAY_KEY_SECRET).update(orderId+"|"+payId).digest("hex"),a=Buffer.from(expected,"hex"),b=Buffer.from(sig,"hex");
  if(a.length!==b.length||!crypto.timingSafeEqual(a,b))return json(400,{success:false,error:"भुगतान signature सत्यापित नहीं हुआ।"});
  const orders=await db("srk_razorpay_orders?select=snapshot_id,booking_id,provider_order_id,amount_paise,currency,status&provider_order_id=eq."+encodeURIComponent(orderId)+"&snapshot_id=eq."+encodeURIComponent(snapshotId)+"&limit=1");
  const order=orders?.[0];if(!order)return json(404,{success:false,error:"यह Razorpay ऑर्डर इस payable snapshot से जुड़ा नहीं है।"});
  const bookings=await db("service_bookings?select=id,phone,customer_user_id,payment_status,service_category_code,final_bill_id,timer_state&id=eq."+encodeURIComponent(order.booking_id)+"&limit=1");
  const booking=bookings?.[0];if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
  await verifyCustomer(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(!booking.service_category_code||booking.timer_state!=="stopped"||booking.final_bill_id!==snapshotId&&booking.final_bill_id==null)return json(409,{success:false,error:"बुकिंग का अंतिम टाइमर बिल सत्यापित नहीं हुआ।"});
  if(booking.payment_status==="paid")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही दर्ज है।"});
  const captured=await payment(payId);
  if(captured.order_id!==orderId||captured.status!=="captured"||captured.currency!==order.currency||captured.amount!==Number(order.amount_paise))return json(409,{success:false,error:"भुगतान captured नहीं है या राशि/ऑर्डर मेल नहीं खाते।"});
  const result=await rpc("srk_reconcile_razorpay_snapshot_payment",{
   p_provider_order_id:orderId,p_provider_payment_id:payId,
   p_amount_paise:Number(captured.amount),p_currency:captured.currency,p_source:"checkout"
  });
  const reconciled=Array.isArray(result)?result[0]:result;
  if(!reconciled?.success)return json(409,{success:false,error:"भुगतान ledger में दर्ज नहीं हो सका।"});
  return json(200,{success:true,replayed:!!reconciled.replayed,message:"भुगतान सफल और सत्यापित है।"});
 }catch(e){
  if(e.httpStatus===401||e.httpStatus===403)return json(e.httpStatus,{success:false,error:e.httpStatus===401?"भुगतान सत्यापन के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित ग्राहक खाते से जुड़ी नहीं है।"});
  console.error("verify-snapshot-payment error:",e?.status||e?.name||"Unknown");
  return json(502,{success:false,error:"भुगतान सत्यापित नहीं हो सका। कृपया कुछ देर बाद कोशिश करें।"});
 }
};

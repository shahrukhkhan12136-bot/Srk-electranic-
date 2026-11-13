const SUPABASE_URL=process.env.SUPABASE_URL, SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY, RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
const uuid=v=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v||"");
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error("Database request failed");e.status=r.status;throw e}return d}
async function rp(path,options={}){const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");const r=await fetch("https://api.razorpay.com/v1/"+path,{...options,headers:{Authorization:"Basic "+auth,"Content-Type":"application/json",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error(d?.error?.description||"Razorpay request failed");e.status=r.status;throw e}return d}
async function verifyCustomerSession(authorization,booking){
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization||"");
 if(!match||match[1].length>8192){const e=new Error("Customer login required");e.httpStatus=401;throw e}
 const response=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
 if(!response.ok){const e=new Error("Customer session invalid");e.httpStatus=401;throw e}
 const user=await response.json(),digits=v=>String(v||"").replace(/\D/g,""),normalize=v=>digits(v).length===10?"91"+digits(v):digits(v);
 if(!user.id||!user.phone_confirmed_at||user.id!==booking.customer_user_id||normalize(user.phone)!==normalize(booking.phone)){const e=new Error("Booking does not belong to this verified customer");e.httpStatus=403;throw e}
 return user.id;
}
async function resolvePayableAmountPaise(booking){
 if(booking.selected_category){
  if(booking.completion_approval_status!=="approved")throw new Error("Final labour bill is not customer-approved");
  const bill=await db("rpc/srk_service_get_labour_bill_for_payment",{method:"POST",body:JSON.stringify({p_booking_id:booking.id})});
  const amount=Number(bill?.labour_amount_paise);
  if(!Number.isSafeInteger(amount)||amount<100)throw new Error("Verified final labour bill is missing or invalid");
  return amount;
 }
 if(booking.quote_status!=="approved")throw new Error("Legacy booking quote is not approved");
 const total=Number(booking.service_charge)+Number(booking.materials_amount),quoted=Number(booking.quoted_amount);
 const amount=Math.round(total*100);
 if(!Number.isFinite(total)||total<1||!Number.isFinite(quoted)||amount!==Math.round(quoted*100)||!Number.isSafeInteger(amount)||amount<100)throw new Error("Legacy approved amount does not reconcile");
 return amount;
}
async function findReusableOrder(booking,amountPaise){
 if(!booking.razorpay_order_id||booking.payment_status!=="pending")return null;
 try{const old=await rp("orders/"+encodeURIComponent(booking.razorpay_order_id));if(old.status==="created"&&old.amount===amountPaise&&old.currency==="INR")return old}catch(_){}
 return null;
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 let bookingId=null,lockToken=null;
 try{
  const body=JSON.parse(event.body||"{}");bookingId=body.booking_id;
  if(!uuid(bookingId))return json(400,{success:false,error:"बुकिंग ID सही नहीं है।"});
  const query="service_bookings?select=id,phone,customer_user_id,selected_category,completion_approval_status,quoted_amount,service_charge,materials_amount,quote_status,payment_status,payment_method,razorpay_order_id,status&id=eq."+encodeURIComponent(bookingId)+"&limit=1";
  let rows=await db(query),booking=rows?.[0];
  if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
  await verifyCustomerSession(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(String(booking.payment_method||"").trim().toLowerCase()!=="razorpay ऑनलाइन भुगतान")return json(409,{success:false,error:"यह बुकिंग नकद भुगतान के लिए है।"});
  if(booking.payment_status==="paid")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही हो चुका है।"});
  if(booking.status!=="completed")return json(409,{success:false,error:"भुगतान केवल ग्राहक द्वारा काम पूरा स्वीकार करने के बाद होगा।"});
  let amount=await resolvePayableAmountPaise(booking),order=await findReusableOrder(booking,amount);
  if(!order){
   const claim=await db("rpc/srk_claim_payment_order_lock",{method:"POST",body:JSON.stringify({p_booking_id:bookingId})});
   lockToken=typeof claim==="string"?claim:(Array.isArray(claim)?claim[0]:null);
   if(!lockToken)return json(409,{success:false,error:"इस बुकिंग का पेमेंट ऑर्डर बन रहा है। 10 सेकंड बाद दोबारा कोशिश करें।"});
   rows=await db(query);booking=rows?.[0];
   if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
   await verifyCustomerSession(event.headers?.authorization||event.headers?.Authorization||"",booking);
   if(String(booking.payment_method||"").trim().toLowerCase()!=="razorpay ऑनलाइन भुगतान")return json(409,{success:false,error:"यह बुकिंग नकद भुगतान के लिए है।"});
   if(booking.payment_status==="paid")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही हो चुका है।"});
   if(booking.status!=="completed")return json(409,{success:false,error:"काम पूरा होने की ग्राहक-मंजूरी जरूरी है।"});
   amount=await resolvePayableAmountPaise(booking);
   order=await findReusableOrder(booking,amount);
   if(!order)order=await rp("orders",{method:"POST",body:JSON.stringify({amount,currency:"INR",receipt:bookingId.slice(0,40),notes:{booking_id:bookingId,service:"SRK ELECTRONIC",billing:"labour_only"}})});
   await db("rpc/srk_link_payment_order",{method:"POST",body:JSON.stringify({p_booking_id:bookingId,p_lock_token:lockToken,p_razorpay_order_id:order.id,p_amount_paise:amount})});
  }
  return json(200,{success:true,key_id:RAZORPAY_KEY_ID,order_id:order.id,amount:order.amount,currency:order.currency});
 }catch(e){
  if(e.httpStatus===401||e.httpStatus===403)return json(e.httpStatus,{success:false,error:e.httpStatus===401?"भुगतान के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित मोबाइल खाते से जुड़ी नहीं है।"});
  console.error("create-order error:",e?.status||e?.name||"Unknown");
  return json(502,{success:false,error:"पेमेंट ऑर्डर नहीं बन पाया। कृपया कुछ देर बाद कोशिश करें।"});
 }finally{
  if(lockToken&&bookingId){try{await db("rpc/srk_release_payment_order_lock",{method:"POST",body:JSON.stringify({p_booking_id:bookingId,p_lock_token:lockToken})})}catch(_){console.error("payment order lock release failed")}}
 }
};

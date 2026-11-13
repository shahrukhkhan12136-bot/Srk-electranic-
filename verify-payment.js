const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL,SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY,RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error("Database request failed");e.status=r.status;throw e}return d}
async function verifyCustomerSession(authorization,booking){
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization||"");
 if(!match||match[1].length>8192){const e=new Error("Customer login required");e.httpStatus=401;throw e}
 const response=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
 if(!response.ok){const e=new Error("Customer session invalid");e.httpStatus=401;throw e}
 const user=await response.json(),digits=v=>String(v||"").replace(/\D/g,""),normalize=v=>digits(v).length===10?"91"+digits(v):digits(v);
 if(!user.id||!user.phone_confirmed_at||user.id!==booking.customer_user_id||normalize(user.phone)!==normalize(booking.phone)){const e=new Error("Booking does not belong to this verified customer");e.httpStatus=403;throw e}
}
async function payment(id){const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");const r=await fetch("https://api.razorpay.com/v1/payments/"+encodeURIComponent(id),{headers:{Authorization:"Basic "+auth}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok)throw new Error("Payment lookup failed");return d}
async function resolvePayableAmountPaise(booking){
 if(booking.selected_category){
  if(booking.completion_approval_status!=="approved")throw new Error("Final labour bill is not customer-approved");
  const bill=await db("rpc/srk_service_get_labour_bill_for_payment",{method:"POST",body:JSON.stringify({p_booking_id:booking.id})});
  const amount=Number(bill?.labour_amount_paise);
  if(!Number.isSafeInteger(amount)||amount<100)throw new Error("Verified final labour bill is missing or invalid");
  return amount;
 }
 if(booking.quote_status!=="approved")throw new Error("Legacy booking quote is not approved");
 const total=Number(booking.service_charge)+Number(booking.materials_amount),quoted=Number(booking.quoted_amount),amount=Math.round(total*100);
 if(!Number.isFinite(total)||total<1||!Number.isFinite(quoted)||amount!==Math.round(quoted*100)||!Number.isSafeInteger(amount)||amount<100)throw new Error("Legacy approved amount does not reconcile");
 return amount;
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 try{
  const b=JSON.parse(event.body||"{}"),payId=typeof b.razorpay_payment_id==="string"?b.razorpay_payment_id:"",orderId=typeof b.razorpay_order_id==="string"?b.razorpay_order_id:"",sig=typeof b.razorpay_signature==="string"?b.razorpay_signature:"";
  if(!/^pay_[A-Za-z0-9]+$/.test(payId)||!/^order_[A-Za-z0-9]+$/.test(orderId)||!/^[a-f0-9]{64}$/i.test(sig))return json(400,{success:false,error:"भुगतान विवरण सही नहीं हैं।"});
  const expected=crypto.createHmac("sha256",RAZORPAY_KEY_SECRET).update(orderId+"|"+payId).digest("hex"),a=Buffer.from(expected,"hex"),received=Buffer.from(sig,"hex");
  if(a.length!==received.length||!crypto.timingSafeEqual(a,received))return json(400,{success:false,error:"भुगतान signature सत्यापित नहीं हुआ।"});
  const query="service_bookings?select=id,phone,customer_user_id,selected_category,completion_approval_status,quoted_amount,service_charge,materials_amount,quote_status,payment_status,payment_method,razorpay_order_id,razorpay_payment_id,status&razorpay_order_id=eq."+encodeURIComponent(orderId)+"&limit=1";
  const rows=await db(query),booking=rows?.[0];
  if(!booking)return json(404,{success:false,error:"इस पेमेंट ऑर्डर की बुकिंग नहीं मिली।"});
  await verifyCustomerSession(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(String(booking.payment_method||"").trim().toLowerCase()!=="razorpay ऑनलाइन भुगतान")return json(409,{success:false,error:"यह बुकिंग नकद भुगतान के लिए है।"});
  if(booking.status!=="completed")return json(409,{success:false,error:"भुगतान केवल ग्राहक द्वारा काम पूरा स्वीकार करने के बाद होगा।"});
  if(booking.payment_status==="paid"){
   if(booking.razorpay_payment_id===payId)return json(200,{success:true,message:"यह भुगतान पहले ही सत्यापित हो चुका है।"});
   return json(409,{success:false,error:"इस ऑर्डर पर दूसरा भुगतान ID पहले से दर्ज है। Admin से जाँच कराएँ。"});
  }
  const expectedAmount=await resolvePayableAmountPaise(booking),p=await payment(payId);
  if(p.order_id!==orderId||p.status!=="captured"||p.currency!=="INR"||p.amount!==expectedAmount)return json(409,{success:false,error:"भुगतान अभी captured नहीं है या अंतिम Labour Bill की राशि से मेल नहीं खाता।"});
  const updated=await db("service_bookings?id=eq."+encodeURIComponent(booking.id)+"&razorpay_order_id=eq."+encodeURIComponent(orderId)+"&payment_status=neq.paid",{method:"PATCH",body:JSON.stringify({payment_status:"paid",amount_paid:Number((p.amount/100).toFixed(2)),razorpay_payment_id:payId,payment_verified_at:new Date().toISOString()})});
  if(!Array.isArray(updated)||updated.length===0){
   const latestRows=await db("service_bookings?select=payment_status,razorpay_payment_id&id=eq."+encodeURIComponent(booking.id)+"&limit=1"),latest=latestRows?.[0];
   if(latest?.payment_status==="paid"&&latest.razorpay_payment_id===payId)return json(200,{success:true,message:"यह भुगतान पहले ही सत्यापित हो चुका है।"});
   if(latest?.payment_status==="paid")return json(409,{success:false,error:"इस ऑर्डर पर दूसरा भुगतान ID पहले से दर्ज है।"});
   return json(409,{success:false,error:"भुगतान स्थिति अपडेट नहीं हो सकी। Admin से संपर्क करें।"});
  }
  return json(200,{success:true,message:"भुगतान सफल और सत्यापित है।"});
 }catch(e){
  if(e.httpStatus===401||e.httpStatus===403)return json(e.httpStatus,{success:false,error:e.httpStatus===401?"भुगतान सत्यापन के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित मोबाइल खाते से जुड़ी नहीं है।"});
  console.error("verify-payment error:",e?.status||e?.name||"Unknown");
  return json(502,{success:false,error:"भुगतान सत्यापित नहीं हो सका। कृपया Admin से संपर्क करें。"});
 }
};

const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL;
const SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY;
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function db(path,options={}){
 const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error("Database request failed");e.status=r.status;e.details=data;throw e;}return data;
}
async function rpc(name,args){return db("rpc/"+name,{method:"POST",body:JSON.stringify(args)});}
async function verifyCustomerSession(authorization,booking){
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization||"");
 if(!match||match[1].length>8192){const e=new Error("Customer login required");e.httpStatus=401;throw e;}
 const r=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
 if(!r.ok){const e=new Error("Customer session invalid");e.httpStatus=401;throw e;}
 const user=await r.json(),digits=v=>String(v||"").replace(/\D/g,""),normalize=v=>digits(v).length===10?"91"+digits(v):digits(v);
 if(!user.id||!user.phone_confirmed_at||user.id!==booking.customer_user_id||normalize(user.phone)!==normalize(booking.phone)){
  const e=new Error("Booking does not belong to this verified customer");e.httpStatus=403;throw e;
 }
}
async function razorpayPayment(paymentId){
 const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");
 const r=await fetch("https://api.razorpay.com/v1/payments/"+encodeURIComponent(paymentId),{headers:{Authorization:"Basic "+auth}});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error("Razorpay payment lookup failed");e.status=r.status;throw e;}return data;
}
function one(value){return Array.isArray(value)?value[0]:value;}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 try{
  const body=JSON.parse(event.body||"{}");
  const paymentId=typeof body.razorpay_payment_id==="string"?body.razorpay_payment_id:"";
  const orderId=typeof body.razorpay_order_id==="string"?body.razorpay_order_id:"";
  const signature=typeof body.razorpay_signature==="string"?body.razorpay_signature:"";
  if(!/^pay_[A-Za-z0-9]+$/.test(paymentId)||!/^order_[A-Za-z0-9]+$/.test(orderId)||!/^[a-f0-9]{64}$/i.test(signature)){
   return json(400,{success:false,error:"भुगतान विवरण सही नहीं हैं।"});
  }
  const expected=crypto.createHmac("sha256",RAZORPAY_KEY_SECRET).update(orderId+"|"+paymentId).digest("hex");
  const expectedBuffer=Buffer.from(expected,"hex"),receivedBuffer=Buffer.from(signature,"hex");
  if(expectedBuffer.length!==receivedBuffer.length||!crypto.timingSafeEqual(expectedBuffer,receivedBuffer)){
   return json(400,{success:false,error:"भुगतान signature सत्यापित नहीं हुआ।"});
  }
  const attempts=await db("srk_razorpay_payment_orders?select=id,booking_id,customer_user_id,amount_paise,currency,razorpay_order_id,status&razorpay_order_id=eq."+encodeURIComponent(orderId)+"&limit=1");
  const attempt=attempts?.[0];
  if(!attempt)return json(404,{success:false,error:"इस Razorpay Order का सुरक्षित रिकॉर्ड नहीं मिला।"});
  const bookings=await db("service_bookings?select=id,phone,customer_user_id,status,payment_status,payment_method,razorpay_order_id,razorpay_payment_id&id=eq."+encodeURIComponent(attempt.booking_id)+"&limit=1");
  const booking=bookings?.[0];
  if(!booking)return json(404,{success:false,error:"इस पेमेंट ऑर्डर की बुकिंग नहीं मिली।"});
  await verifyCustomerSession(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(booking.customer_user_id!==attempt.customer_user_id)return json(409,{success:false,error:"पेमेंट ऑर्डर और ग्राहक रिकॉर्ड मेल नहीं खाते।"});
  const payment=await razorpayPayment(paymentId);
  if(payment.id!==paymentId||payment.order_id!==orderId||payment.status!=="captured"||payment.currency!=="INR"||payment.amount!==attempt.amount_paise){
   return json(409,{success:false,error:"भुगतान captured नहीं है या सुरक्षित Final Bill राशि से मेल नहीं खाता।"});
  }
  const result=one(await rpc("srk_service_finalize_razorpay_payment",{
   p_razorpay_order_id:orderId,p_razorpay_payment_id:paymentId,
   p_amount_paise:payment.amount,p_currency:payment.currency
  }));
  if(!result?.success)return json(409,{success:false,error:"भुगतान का Database सत्यापन पूरा नहीं हुआ। Admin से जाँच कराएँ।"});
  return json(200,{success:true,already_processed:!!result.already_processed,message:result.already_processed?"यह भुगतान पहले ही सत्यापित हो चुका है।":"भुगतान सफल और सत्यापित है।"});
 }catch(error){
  if(error.httpStatus===401||error.httpStatus===403)return json(error.httpStatus,{success:false,error:error.httpStatus===401?"भुगतान सत्यापन के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित मोबाइल खाते से जुड़ी नहीं है।"});
  if(error.status===400||error.status===409||error.status===422)return json(409,{success:false,error:"भुगतान बुकिंग की वर्तमान स्थिति या Final Bill राशि से मेल नहीं खाता। Admin से जाँच कराएँ।"});
  console.error("verify-payment error:",error?.status||error?.name||"Unknown");
  return json(502,{success:false,error:"भुगतान सत्यापित नहीं हो सका। कृपया Admin से संपर्क करें।"});
 }
};

const SUPABASE_URL=process.env.SUPABASE_URL;
const SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY;
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
const uuid=v=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v||"");
async function db(path,options={}){
 const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error("Database request failed");e.status=r.status;e.details=data;throw e;}return data;
}
async function rpc(name,args){return db("rpc/"+name,{method:"POST",body:JSON.stringify(args)});}
async function rp(path,options={}){
 const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");
 const r=await fetch("https://api.razorpay.com/v1/"+path,{...options,headers:{Authorization:"Basic "+auth,"Content-Type":"application/json",...(options.headers||{})}});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error(data?.error?.description||"Razorpay request failed");e.status=r.status;e.provider=data;throw e;}return data;
}
async function verifyCustomerSession(authorization,booking){
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization||"");
 if(!match||match[1].length>8192){const e=new Error("Customer login required");e.httpStatus=401;throw e;}
 const r=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
 if(!r.ok){const e=new Error("Customer session invalid");e.httpStatus=401;throw e;}
 const user=await r.json(),digits=v=>String(v||"").replace(/\D/g,""),normalize=v=>digits(v).length===10?"91"+digits(v):digits(v);
 if(!user.id||!user.phone_confirmed_at||user.id!==booking.customer_user_id||normalize(user.phone)!==normalize(booking.phone)){
  const e=new Error("Booking does not belong to this verified customer");e.httpStatus=403;throw e;
 }
 return user.id;
}
function one(value){return Array.isArray(value)?value[0]:value;}
function isOnlineMethod(value){return ["online","upi","card"].includes(String(value||"").trim().toLowerCase());}
async function latestFinalBill(bookingId){
 const rows=await db("srk_booking_final_bills?select=id,total_amount,revision_no,status&booking_id=eq."+encodeURIComponent(bookingId)+"&status=in.(issued,approved)&order=revision_no.desc,created_at.desc&limit=1");
 const bill=rows?.[0],amount=Number(bill?.total_amount),amountPaise=Math.round(amount*100);
 if(!bill||!Number.isFinite(amount)||amount<=0||!Number.isSafeInteger(amountPaise)||amountPaise<100||amountPaise>1000000000){
  const e=new Error("Issued final bill is missing or invalid");e.httpStatus=409;throw e;
 }
 return {...bill,amountPaise};
}
async function reusableAttempt(bookingId,bill){
 const rows=await db("srk_razorpay_payment_orders?select=id,booking_id,customer_user_id,final_bill_id,final_bill_revision,amount_paise,razorpay_order_id,status,receipt&booking_id=eq."+encodeURIComponent(bookingId)+"&status=in.(creating,created,reconciliation_required)&order=created_at.desc&limit=1");
 const attempt=rows?.[0];if(!attempt)return null;
 if(attempt.status!=="created"||!attempt.razorpay_order_id){
  const e=new Error("An earlier payment-order attempt needs reconciliation");e.httpStatus=409;throw e;
 }
 if(attempt.amount_paise!==bill.amountPaise||attempt.final_bill_id!==bill.id||attempt.final_bill_revision!==bill.revision_no){
  const e=new Error("Existing payment order belongs to a different final bill revision");e.httpStatus=409;throw e;
 }
 const order=await rp("orders/"+encodeURIComponent(attempt.razorpay_order_id));
 if(order.status!=="created"||order.amount!==bill.amountPaise||order.currency!=="INR"){
  const e=new Error("Existing Razorpay order is not reusable; reconciliation required");e.httpStatus=409;throw e;
 }
 return order;
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 let bookingId=null,lockToken=null;
 try{
  const body=JSON.parse(event.body||"{}");bookingId=body.booking_id;
  if(!uuid(bookingId))return json(400,{success:false,error:"बुकिंग ID सही नहीं है।"});
  let rows=await db("service_bookings?select=id,phone,customer_user_id,payment_method,payment_status,status& id=eq.".replace(" ","")+encodeURIComponent(bookingId)+"&limit=1");
  let booking=rows?.[0];
  if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
  const customerId=await verifyCustomerSession(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(!isOnlineMethod(booking.payment_method))return json(409,{success:false,error:"इस बुकिंग में Online/UPI/Card भुगतान नहीं चुना गया है।"});
  if(booking.status!=="completed"||["paid","completed","refunded"].includes(String(booking.payment_status||"").toLowerCase()))return json(409,{success:false,error:"यह बुकिंग अभी भुगतान के लिए उपलब्ध नहीं है।"});
  let bill=await latestFinalBill(bookingId);
  const reused=await reusableAttempt(bookingId,bill);
  if(reused)return json(200,{success:true,key_id:RAZORPAY_KEY_ID,order_id:reused.id,amount:reused.amount,currency:reused.currency});
  const claim=one(await rpc("srk_claim_payment_order_lock",{p_booking_id:bookingId}));
  lockToken=typeof claim==="string"?claim:(claim?.srk_claim_payment_order_lock||claim?.value||null);
  if(!lockToken)return json(409,{success:false,error:"इस बुकिंग का पेमेंट ऑर्डर बन रहा है। कृपया कुछ देर बाद प्रयास करें।"});
  rows=await db("service_bookings?select=id,phone,customer_user_id,payment_method,payment_status,status&id=eq."+encodeURIComponent(bookingId)+"&limit=1");
  booking=rows?.[0];
  if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
  await verifyCustomerSession(event.headers?.authorization||event.headers?.Authorization||"",booking);
  if(!isOnlineMethod(booking.payment_method)||booking.status!=="completed"||["paid","completed","refunded"].includes(String(booking.payment_status||"").toLowerCase())){
   return json(409,{success:false,error:"बुकिंग की भुगतान स्थिति बदल गई है।"});
  }
  bill=await latestFinalBill(bookingId);
  const idempotencyKey="srk-order-"+crypto.randomUUID();
  const attempt=one(await rpc("srk_service_start_razorpay_payment_order",{
   p_booking_id:bookingId,p_customer_user_id:customerId,p_idempotency_key:idempotencyKey,p_lock_token:lockToken
  }));
  if(!attempt?.id||attempt.amount_paise!==bill.amountPaise||attempt.final_bill_id!==bill.id){
   throw new Error("Server did not create a matching final-bill payment attempt");
  }
  let order;
  try{
   order=await rp("orders",{method:"POST",body:JSON.stringify({
    amount:attempt.amount_paise,currency:"INR",receipt:attempt.receipt,
    notes:{booking_id:bookingId,final_bill_id:bill.id,service:"SRK ELECTRONIC",billing_basis:"final_bill_total"}
   })});
  }catch(error){
   try{await rpc("srk_service_mark_razorpay_order_failure",{
    p_attempt_id:attempt.id,p_failure_code:String(error.status||"network_error"),
    p_failure_description:"Razorpay order creation outcome: "+(error.status?"provider rejected request":"network outcome uncertain"),
    p_uncertain:!error.status
   });}catch(_){}
   throw error;
  }
  try{
   await rpc("srk_service_attach_razorpay_order",{
    p_attempt_id:attempt.id,p_razorpay_order_id:order.id,p_lock_token:lockToken
   });
  }catch(error){
   try{await rpc("srk_service_mark_razorpay_order_failure",{
    p_attempt_id:attempt.id,p_failure_code:"order_attach_failed",
    p_failure_description:"Razorpay order created but database linking failed; reconcile provider order",
    p_uncertain:true
   });}catch(_){}
   const e=new Error("Razorpay order created but could not be safely linked");e.httpStatus=409;throw e;
  }
  return json(200,{success:true,key_id:RAZORPAY_KEY_ID,order_id:order.id,amount:order.amount,currency:order.currency});
 }catch(error){
  if(error.httpStatus===401||error.httpStatus===403)return json(error.httpStatus,{success:false,error:error.httpStatus===401?"भुगतान के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित मोबाइल खाते से जुड़ी नहीं है।"});
  if(error.httpStatus===409)return json(409,{success:false,error:"बुकिंग/Final Bill की स्थिति या पुराने पेमेंट ऑर्डर की जाँच जरूरी है। Admin से संपर्क करें।"});
  console.error("create-order error:",error?.status||error?.name||"Unknown");
  return json(502,{success:false,error:"पेमेंट ऑर्डर नहीं बन पाया। कृपया कुछ देर बाद प्रयास करें।"});
 }finally{
  if(lockToken&&bookingId){try{await rpc("srk_release_payment_order_lock",{p_booking_id:bookingId,p_lock_token:lockToken});}catch(_){console.error("payment order lock release failed");}}
 }
};

const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL, SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY, RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error("Database request failed");e.status=r.status;throw e}return d}

async function verifyCustomerSession(authorization, booking) {
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization || "");
  if (!match || match[1].length > 8192) { const error = new Error("Customer login required"); error.httpStatus = 401; throw error; }
  const response = await fetch(SUPABASE_URL + "/auth/v1/user", { headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + match[1] } });
  if (!response.ok) { const error = new Error("Customer session invalid"); error.httpStatus = 401; throw error; }
  const user = await response.json();
  const digits = value => String(value || "").replace(/\D/g, "");
  const normalize = value => digits(value).length === 10 ? "91" + digits(value) : digits(value);
  if (!user.id || !user.phone_confirmed_at || user.id !== booking.customer_user_id || normalize(user.phone) !== normalize(booking.phone)) {
    const error = new Error("Booking does not belong to this verified customer"); error.httpStatus = 403; throw error;
  }
  return user.id;
}

async function payment(id){const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");const r=await fetch("https://api.razorpay.com/v1/payments/"+encodeURIComponent(id),{headers:{Authorization:"Basic "+auth}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok)throw new Error("Payment lookup failed");return d}
exports.handler=async event=>{
if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
try{const b=JSON.parse(event.body||"{}"),payId=typeof b.razorpay_payment_id==="string"?b.razorpay_payment_id:"",orderId=typeof b.razorpay_order_id==="string"?b.razorpay_order_id:"",sig=typeof b.razorpay_signature==="string"?b.razorpay_signature:"";
if(!/^pay_[A-Za-z0-9]+$/.test(payId)||!/^order_[A-Za-z0-9]+$/.test(orderId)||!/^[a-f0-9]{64}$/i.test(sig))return json(400,{success:false,error:"भुगतान विवरण सही नहीं हैं।"});
const expected=crypto.createHmac("sha256",RAZORPAY_KEY_SECRET).update(orderId+"|"+payId).digest("hex"),a=Buffer.from(expected,"hex"),c=Buffer.from(sig,"hex");if(a.length!==c.length||!crypto.timingSafeEqual(a,c))return json(400,{success:false,error:"भुगतान signature सत्यापित नहीं हुआ।"});
const rows=await db("service_bookings?select=id,phone,customer_user_id,payment_method,quoted_amount,service_charge,materials_amount,payment_status,razorpay_order_id,razorpay_payment_id,status,quote_status,selected_category&razorpay_order_id=eq."+encodeURIComponent(orderId)+"&limit=1"),booking=rows?.[0];if(!booking)return json(404,{success:false,error:"इस पेमेंट ऑर्डर की बुकिंग नहीं मिली।"});await verifyCustomerSession(event.headers?.authorization || event.headers?.Authorization || "",booking);
if(!["razorpay","online"].some(token=>String(booking.payment_method||"").trim().toLowerCase().includes(token)))return json(409,{success:false,error:"इस बुकिंग के लिए Razorpay ऑनलाइन भुगतान नहीं चुना गया है।"});
if(booking.payment_status==="refunded")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही रिफंड हो चुका है। Admin से संपर्क करें।"});
if(booking.selected_category){
 if(booking.status!=="completed")return json(409,{success:false,error:"भुगतान केवल काम पूरा होने के बाद स्वीकार होगा।"});
 if(booking.payment_status==="paid"){
  if(booking.razorpay_payment_id===payId)return json(200,{success:true,message:"यह भुगतान पहले ही सत्यापित हो चुका है।"});
  return json(409,{success:false,error:"इस बुकिंग पर दूसरा भुगतान पहले से दर्ज है। Admin से जाँच कराएँ।"});
 }
 const breakdown=await db("rpc/srk_service_role_get_booking_payment_breakdown",{method:"POST",body:JSON.stringify({p_booking_id:booking.id})});
 const expectedAmount=Number(breakdown?.total_amount_paise);
 if(!Number.isSafeInteger(expectedAmount)||expectedAmount<100)return json(409,{success:false,error:"अंतिम Labour Bill और cancellation fee का हिसाब उपलब्ध नहीं है।"});
 const p=await payment(payId);
 if(p.order_id!==orderId||p.status!=="captured"||p.currency!=="INR"||p.amount!==expectedAmount)return json(409,{success:false,error:"भुगतान captured नहीं है या labour/cancellation fee सहित कुल राशि मेल नहीं खाती।"});
 const settled=await db("rpc/srk_service_role_record_online_booking_payment",{method:"POST",body:JSON.stringify({
  p_booking_id:booking.id,p_order_id:orderId,p_payment_id:payId,p_amount_paise:p.amount
 })});
 if(!settled?.success)return json(409,{success:false,error:"भुगतान सत्यापित हुआ, लेकिन ledger settlement पूरा नहीं हुआ। Admin reconciliation आवश्यक है।"});
 return json(200,{success:true,message:"भुगतान और cancellation-fee ledger सफलतापूर्वक सत्यापित हुए।",cancellation_fee_amount_paise:settled.cancellation_fee_amount_paise});
}
if(booking.status!=="completed"||booking.quote_status!=="approved")return json(409,{success:false,error:"भुगतान केवल मंजूर कोटेशन का काम पूरा होने के बाद स्वीकार होगा।"});
if(booking.payment_status==="paid"){if(booking.razorpay_payment_id===payId)return json(200,{success:true,message:"यह भुगतान पहले ही सत्यापित हो चुका है।"});return json(409,{success:false,error:"इस ऑर्डर पर दूसरा भुगतान ID पहले से दर्ज है। Admin से जाँच कराएँ।"});}
const approvedTotal=Number(booking.service_charge)+Number(booking.materials_amount);if(!Number.isFinite(approvedTotal)||approvedTotal<1||Math.round(approvedTotal*100)!==Math.round(Number(booking.quoted_amount)*100))return json(409,{success:false,error:"मंजूर कोटेशन की कुल राशि और सेवा/सामान का हिसाब मेल नहीं खाता। Admin से जाँच कराएँ।"});const p=await payment(payId),expectedAmount=Math.round(approvedTotal*100);if(p.order_id!==orderId||p.status!=="captured"||p.currency!=="INR"||p.amount!==expectedAmount)return json(409,{success:false,error:"भुगतान अभी captured नहीं है या राशि/ऑर्डर मेल नहीं खाते।"});
const updated=await db("service_bookings?id=eq."+encodeURIComponent(booking.id)+"&razorpay_order_id=eq."+encodeURIComponent(orderId)+"&payment_status=neq.paid",{method:"PATCH",body:JSON.stringify({payment_status:"paid",amount_paid:Number((p.amount/100).toFixed(2)),razorpay_payment_id:payId,payment_verified_at:new Date().toISOString()})});
if(!Array.isArray(updated)||updated.length===0){const latestRows=await db("service_bookings?select=payment_status,razorpay_payment_id&id=eq."+encodeURIComponent(booking.id)+"&limit=1");const latest=latestRows?.[0];if(latest?.payment_status==="paid"&&latest.razorpay_payment_id===payId)return json(200,{success:true,message:"यह भुगतान पहले ही सत्यापित हो चुका है।"});if(latest?.payment_status==="paid"&&latest.razorpay_payment_id!==payId)return json(409,{success:false,error:"इस ऑर्डर पर दूसरा भुगतान ID पहले से दर्ज है। Admin से जाँच कराएँ।"});return json(409,{success:false,error:"भुगतान स्थिति अपडेट नहीं हो सकी। Admin से संपर्क करें।"});}return json(200,{success:true,message:"भुगतान सफल और सत्यापित है।"});
}catch(e){if(e.httpStatus===401||e.httpStatus===403)return json(e.httpStatus,{success:false,error:e.httpStatus===401?"भुगतान सत्यापन के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित मोबाइल खाते से जुड़ी नहीं है।"});console.error("verify-payment error:",e?.status||e?.name||"Unknown");return json(502,{success:false,error:"भुगतान सत्यापित नहीं हो सका। कृपया Admin से संपर्क करें।"})}};
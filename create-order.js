const SUPABASE_URL=process.env.SUPABASE_URL, SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY, RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
const uuid=v=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v||"");
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error("Database request failed");e.status=r.status;throw e}return d}
async function rp(path,options={}){const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");const r=await fetch("https://api.razorpay.com/v1/"+path,{...options,headers:{Authorization:"Basic "+auth,"Content-Type":"application/json",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok){const e=new Error(d?.error?.description||"Razorpay request failed");e.status=r.status;throw e}return d}

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

async function findReusableOrder(booking){
  if(!booking.razorpay_order_id||booking.payment_status!=="pending")return null;
  try{const old=await rp("orders/"+encodeURIComponent(booking.razorpay_order_id));if(old.status==="created"&&old.amount===Math.round(Number(booking.quoted_amount)*100)&&old.currency==="INR")return old}catch(_){}
  return null;
}
exports.handler=async event=>{
  if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
  if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"पेमेंट सर्वर कॉन्फ़िगरेशन अधूरा है।"});
  let bookingId=null,lockToken=null;
  try{
    const b=JSON.parse(event.body||"{}");bookingId=b.booking_id;
    if(!uuid(bookingId))return json(400,{success:false,error:"बुकिंग ID सही नहीं है।"});
    let rows=await db("service_bookings?select=id,phone,customer_user_id,quoted_amount,service_charge,materials_amount,payment_status,payment_method,razorpay_order_id,status,quote_status&id=eq."+encodeURIComponent(bookingId)+"&limit=1");
    let booking=rows?.[0];if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
    await verifyCustomerSession(event.headers?.authorization || event.headers?.Authorization || "", booking);
    if(String(booking.payment_method||"").toLowerCase()!=="online")return json(409,{success:false,error:"यह बुकिंग नकद भुगतान के लिए चुनी गई है।"});
    if(booking.payment_status==="paid")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही हो चुका है।"});
    if(booking.status!=="completed"||booking.quote_status!=="approved")return json(409,{success:false,error:"भुगतान केवल ग्राहक द्वारा मंजूर कोटेशन का काम पूरा होने के बाद किया जा सकता है।"});
    const approvedTotal=Number(booking.service_charge)+Number(booking.materials_amount);
    if(!Number.isFinite(approvedTotal)||approvedTotal<1||Math.round(approvedTotal*100)!==Math.round(Number(booking.quoted_amount)*100))return json(409,{success:false,error:"मंजूर कोटेशन की कुल राशि और सेवा/सामान का हिसाब मेल नहीं खाता। Admin से जाँच कराएँ।"});
    let amount=Math.round(approvedTotal*100);
    if(!Number.isSafeInteger(amount)||amount<100)return json(400,{success:false,error:"बुकिंग में कम से कम ₹1 की सही राशि दर्ज होनी चाहिए।"});

    let order=await findReusableOrder(booking);
    if(!order){
      const claim=await db("rpc/srk_claim_payment_order_lock",{method:"POST",body:JSON.stringify({p_booking_id:bookingId})});
      lockToken=typeof claim==="string"?claim:(Array.isArray(claim)?claim[0]:null);
      if(!lockToken)return json(409,{success:false,error:"इस बुकिंग का पेमेंट ऑर्डर बन रहा है। 10 सेकंड बाद दोबारा कोशिश करें।"});
      // Re-read after acquiring the per-booking lock in case a prior request completed.
      rows=await db("service_bookings?select=id,phone,customer_user_id,quoted_amount,service_charge,materials_amount,payment_status,payment_method,razorpay_order_id,status,quote_status&id=eq."+encodeURIComponent(bookingId)+"&limit=1");
      booking=rows?.[0];
      if(!booking)return json(404,{success:false,error:"बुकिंग नहीं मिली।"});
      await verifyCustomerSession(event.headers?.authorization || event.headers?.Authorization || "", booking);
      if(String(booking.payment_method||"").toLowerCase()!=="online")return json(409,{success:false,error:"यह बुकिंग नकद भुगतान के लिए चुनी गई है।"});
      if(booking.payment_status==="paid")return json(409,{success:false,error:"इस बुकिंग का भुगतान पहले ही हो चुका है।"});
      if(booking.status!=="completed"||booking.quote_status!=="approved")return json(409,{success:false,error:"भुगतान केवल ग्राहक द्वारा मंजूर कोटेशन का काम पूरा होने के बाद किया जा सकता है।"});
      // Recalculate after acquiring the lock so an Admin price change cannot create a stale-amount order.
      const latestTotal=Number(booking.service_charge)+Number(booking.materials_amount);
      if(!Number.isFinite(latestTotal)||latestTotal<1||Math.round(latestTotal*100)!==Math.round(Number(booking.quoted_amount)*100))return json(409,{success:false,error:"मंजूर कोटेशन की कुल राशि और सेवा/सामान का हिसाब मेल नहीं खाता। Admin से जाँच कराएँ।"});
      amount=Math.round(latestTotal*100);
      if(!Number.isSafeInteger(amount)||amount<100)return json(400,{success:false,error:"बुकिंग में कम से कम ₹1 की सही राशि दर्ज होनी चाहिए।"});
      order=await findReusableOrder(booking);
      if(!order)order=await rp("orders",{method:"POST",body:JSON.stringify({amount,currency:"INR",receipt:bookingId.slice(0,40),notes:{booking_id:bookingId,service:"SRK ELECTRONIC"}})});
      await db("service_bookings?id=eq."+encodeURIComponent(bookingId),{method:"PATCH",body:JSON.stringify({razorpay_order_id:order.id,payment_status:"pending"})});
    }
    return json(200,{success:true,key_id:RAZORPAY_KEY_ID,order_id:order.id,amount:order.amount,currency:order.currency});
  }catch(e){
    if(e.httpStatus===401||e.httpStatus===403)return json(e.httpStatus,{success:false,error:e.httpStatus===401?"भुगतान के लिए ग्राहक OTP लॉगिन करें।":"यह बुकिंग आपके सत्यापित मोबाइल खाते से जुड़ी नहीं है।"});
    console.error("create-order error:",e?.status||e?.name||"Unknown");
    return json(502,{success:false,error:"पेमेंट ऑर्डर नहीं बन पाया। कृपया कुछ देर बाद कोशिश करें।"});
  }finally{
    if(lockToken&&bookingId){
      try{await db("rpc/srk_release_payment_order_lock",{method:"POST",body:JSON.stringify({p_booking_id:bookingId,p_lock_token:lockToken})});}
      catch(_){console.error("payment order lock release failed");}
    }
  }
};
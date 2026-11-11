const SUPABASE_URL=process.env.SUPABASE_URL;
const SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY;
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function request(url,options={}){const r=await fetch(url,options);const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}return {ok:r.ok,status:r.status,data};}
async function supabase(path,token,body){return request(SUPABASE_URL+"/rest/v1/"+path,{method:"POST",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation"},body:JSON.stringify(body)});}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"Refund सर्वर कॉन्फ़िगरेशन अधूरा है।"});
 const auth=event.headers?.authorization||event.headers?.Authorization||"";
 const match=/^Bearer ([A-Za-z0-9._~-]{20,8192})$/.exec(auth);
 if(!match)return json(401,{success:false,error:"Admin लॉगिन आवश्यक है।"});
 try{
  const user=await request(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+match[1]}});
  if(!user.ok||!user.data?.id)return json(401,{success:false,error:"Admin session मान्य नहीं है।"});
  const admin=await supabase("rpc/is_srk_admin",match[1],{});
  if(!admin.ok||admin.data!==true)return json(403,{success:false,error:"केवल अधिकृत Admin Refund जारी कर सकता है।"});
  let body;try{body=JSON.parse(event.body||"{}")}catch{return json(400,{success:false,error:"अनुरोध सही JSON नहीं है।"});}
  const requestId=body.request_id;
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId||""))return json(400,{success:false,error:"Refund request ID सही नहीं है।"});
  const requestRows=await supabase("rpc/srk_admin_list_booking_refund_requests",match[1],{p_limit:300});
  if(!requestRows.ok)return json(502,{success:false,error:"Refund अनुरोध Main Database से सत्यापित नहीं हो सका।"});
  const refundRequest=(Array.isArray(requestRows.data)?requestRows.data:[]).find(item=>item.id===requestId);
  if(!refundRequest)return json(404,{success:false,error:"Refund अनुरोध नहीं मिला।"});
  if(!["approved","processing","unknown"].includes(refundRequest.status))return json(409,{success:false,error:"पहले Refund अनुरोध को Admin से मंजूर कराएँ।"});
  if(!refundRequest.razorpay_payment_id)return json(409,{success:false,error:"इस बुकिंग का Razorpay भुगतान ID उपलब्ध नहीं है।"});
  const authHeader="Basic "+Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");
  const paymentCheck=await request("https://api.razorpay.com/v1/payments/"+encodeURIComponent(refundRequest.razorpay_payment_id),{headers:{Authorization:authHeader}});
  if(!paymentCheck.ok)return json(502,{success:false,error:"Razorpay भुगतान की वर्तमान स्थिति सत्यापित नहीं हुई।"});
  if(paymentCheck.data?.status!=="captured"||Number(paymentCheck.data.amount_refunded||0)!==0||
     Number(paymentCheck.data.amount)!==Math.round(Number(refundRequest.amount)*100)){
    return json(409,{success:false,error:"Razorpay भुगतान पर पहले से Refund हुआ है, या captured राशि अनुरोध से मेल नहीं खाती। पहले Dashboard में मिलान करें।"});
  }
  const prepared=await supabase("rpc/srk_admin_prepare_booking_refund",match[1],{p_request_id:requestId});
  if(!prepared.ok){const msg=prepared.data?.message||prepared.data?.hint||"Refund की अनुमति नहीं मिली।";return json(prepared.status>=500?502:409,{success:false,error:msg});}
  const row=Array.isArray(prepared.data)?prepared.data[0]:prepared.data;
  if(!row?.refund_record_id||!row.payment_id||!Number.isSafeInteger(Number(row.amount_paise))||Number(row.amount_paise)<100||!row.idempotency_key)return json(409,{success:false,error:"Refund रिकॉर्ड अधूरा है; भुगतान न भेजें।"});
  if(row.status==="processed")return json(200,{success:true,status:"processed",message:"यह Refund पहले ही पूरा दर्ज है।",refund_id:null});
  const rp=await request("https://api.razorpay.com/v1/payments/"+encodeURIComponent(row.payment_id)+"/refund",{method:"POST",headers:{Authorization:authHeader,"Content-Type":"application/json","X-Refund-Idempotency":row.idempotency_key},body:JSON.stringify({amount:Number(row.amount_paise),receipt:"SRK-"+row.refund_record_id.replace(/-/g,"").slice(0,28),notes:{booking_id:row.booking_id,refund_record_id:row.refund_record_id,request_id:requestId}})});
  if(!rp.ok){
   console.error("Razorpay refund request rejected:",rp.status,rp.data?.error?.code||"provider_error");
   return json(rp.status===409?202:502,{success:false,pending:true,error:"Razorpay ने अभी Refund की अंतिम पुष्टि नहीं दी। उसी सुरक्षित idempotency key से Admin दोबारा स्थिति जाँच सकता है।"});
  }
  const refund=rp.data;
  if(refund?.payment_id!==row.payment_id||Number(refund.amount)!==Number(row.amount_paise)||!/^rfnd_[A-Za-z0-9]+$/.test(refund.id||"")||!["pending","processed"].includes(refund.status)){
   console.error("Razorpay refund response did not match the requested payment and amount.");
   return json(502,{success:false,pending:true,error:"Provider response का भुगतान/राशि मिलान नहीं हुआ। कृपया Dashboard में जाँच करें।"});
  }
  const reconciled=await supabase("rpc/srk_service_reconcile_booking_refund",SUPABASE_KEY,{p_refund_record_id:row.refund_record_id,p_provider_refund_id:refund.id,p_provider_status:refund.status,p_error:null});
  if(!reconciled.ok){console.error("Refund ledger reconciliation failed:",reconciled.status);return json(202,{success:false,pending:true,refund_id:refund.id,error:"Razorpay Refund बन गया है, लेकिन Main Database reconciliation बाकी है। इसे दोबारा जाँचें; नया Refund न बनाएं।"});}
  return json(200,{success:true,status:refund.status,refund_id:refund.id,amount:Number(refund.amount)/100,message:refund.status==="processed"?"Refund पूरा हो गया।":"Refund Razorpay में processing में है।"});
 }catch(error){console.error("process-refund error:",error?.name||"UnknownError");return json(502,{success:false,error:"Refund प्रक्रिया अभी पूरी नहीं हुई। कृपया Refund इतिहास जाँचें।"});}
};
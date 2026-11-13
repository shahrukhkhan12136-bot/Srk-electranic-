const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL;
const SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY;
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const WEBHOOK_SECRET=process.env.RAZORPAY_WEBHOOK_SECRET;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function rest(path,options={},token=SERVICE_KEY){
 const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SERVICE_KEY,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error("Supabase request failed");e.status=r.status;throw e;}return data;
}
async function rpc(name,args,token=SERVICE_KEY){return rest("rpc/"+name,{method:"POST",body:JSON.stringify(args)},token);}
async function razorpay(path,method="GET",body=null,headers={}){
 const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");
 const r=await fetch("https://api.razorpay.com/v1/"+path,{method,headers:{Authorization:"Basic "+auth,"Content-Type":"application/json",...headers},...(body?{body:JSON.stringify(body)}:{})});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error(data?.error?.description||"Razorpay request failed");e.status=r.status;e.provider=data;throw e;}return data;
}
async function reconcile(refundRecordId,providerRefund){
 const result=await rpc("srk_service_record_razorpay_refund_result",{
  p_refund_record_id:refundRecordId,p_provider_refund_id:providerRefund?.id||null,
  p_provider_status:providerRefund?.status||null,p_error:null
 });
 if(providerRefund?.status!=="processed")return {success:true,provider_status:providerRefund?.status||"unknown",internal_status:"processing"};
 try{
  const final=await rpc("srk_service_finalize_razorpay_refund",{p_refund_record_id:refundRecordId});
  return {success:true,provider_status:"processed",internal_status:final?.status||"processed"};
 }catch(error){
  console.error("Refund provider succeeded; internal reconciliation pending:",error?.status||error?.name);
  return {success:true,provider_status:"processed",internal_status:"reconciliation_pending"};
 }
}
async function execute(event){
 const auth=event.headers?.authorization||event.headers?.Authorization||"";
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(auth);
 if(!match||match[1].length>8192)return json(401,{success:false,error:"Admin login required."});
 const userResponse=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SERVICE_KEY,Authorization:"Bearer "+match[1]}});
 if(!userResponse.ok)return json(401,{success:false,error:"Admin session invalid."});
 const body=JSON.parse(event.body||"{}"),requestId=body.request_id;
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId||""))return json(400,{success:false,error:"Invalid refund request."});
 const claim=await rpc("srk_admin_claim_razorpay_refund",{p_request_id:requestId},match[1]);
 if(!claim?.success)return json(409,{success:false,error:"Approved prepared refund required."});
 const {refund_record_id,payment_id,amount_paise,idempotency_key,refund_id}=claim;
 let providerRefund;
 try{
  const payment=await razorpay("payments/"+encodeURIComponent(payment_id));
  if(payment.id!==payment_id||payment.status!=="captured"||payment.currency!=="INR"||!Number.isSafeInteger(payment.amount)||payment.amount!==amount_paise||Number(payment.amount_refunded||0)!==0)
    return json(409,{success:false,error:"Captured payment or refundable balance does not match approved labour amount."});
  if(refund_id){
   providerRefund=await razorpay("refunds/"+encodeURIComponent(refund_id));
  }else{
   providerRefund=await razorpay("payments/"+encodeURIComponent(payment_id)+"/refund","POST",{amount:amount_paise,receipt:idempotency_key,notes:{booking_id:claim.booking_id,refund_record_id,reason:"SRK ELECTRONIC approved labour-only refund"}},{"X-Refund-Idempotency":idempotency_key});
  }
  if(providerRefund.payment_id!==payment_id||providerRefund.amount!==amount_paise||providerRefund.currency!=="INR"||!/^rfnd_[A-Za-z0-9]+$/.test(providerRefund.id||""))
    return json(502,{success:false,error:"Provider response did not match the prepared refund; manual reconciliation required."});
  const state=await reconcile(refund_record_id,providerRefund);
  return json(state.internal_status==="processed"?200:202,{success:true,refund_id:providerRefund.id,amount_paise,provider_status:state.provider_status,internal_status:state.internal_status});
 }catch(error){
  try{await rpc("srk_service_record_razorpay_refund_result",{p_refund_record_id:refund_record_id,p_provider_refund_id:null,p_provider_status:null,p_error:"Provider request outcome uncertain; retry with same idempotency key or reconcile in Dashboard."});}catch(_){}
  console.error("Razorpay refund executor error:",error?.status||error?.name||"Unknown");
  return json(202,{success:false,requires_reconciliation:true,error:"Provider response uncertain. Refund intent and idempotency key محفوظ हैं; दोबारा प्रयास उसी key से होगा।"});
 }
}
async function webhook(event){
 if(!WEBHOOK_SECRET)return json(500,{success:false,error:"Webhook configuration incomplete."});
 const signature=event.headers?.["x-razorpay-signature"]||event.headers?.["X-Razorpay-Signature"]||"";
 const raw=event.isBase64Encoded?Buffer.from(event.body||"","base64"):Buffer.from(event.body||"","utf8");
 if(!/^[a-f0-9]{64}$/i.test(signature))return json(400,{success:false,error:"Invalid signature."});
 const expected=crypto.createHmac("sha256",WEBHOOK_SECRET).update(raw).digest(),received=Buffer.from(signature,"hex");
 if(received.length!==expected.length||!crypto.timingSafeEqual(expected,received))return json(400,{success:false,error:"Signature verification failed."});
 const payload=JSON.parse(raw.toString("utf8")),eventName=payload.event;
 if(!["refund.created","refund.processed","refund.failed"].includes(eventName))return json(200,{success:true,ignored:true});
 const refund=payload.payload?.refund?.entity;
 if(!refund||!/^rfnd_[A-Za-z0-9]+$/.test(refund.id||"")||!/^pay_[A-Za-z0-9]+$/.test(refund.payment_id||""))return json(400,{success:false,error:"Refund event payload invalid."});
 const eventId=event.headers?.["x-razorpay-event-id"]||event.headers?.["X-Razorpay-Event-Id"];
 if(!eventId)return json(400,{success:false,error:"Provider event ID missing; cannot safely deduplicate."});
 await rpc("srk_service_capture_razorpay_refund_event",{p_event_id:eventId,p_event_name:eventName,p_refund_id:refund.id,p_payment_id:refund.payment_id,p_payload:payload});
 const rows=await rest("srk_razorpay_refunds?select=id,amount_paise,payment_id&refund_id=eq."+encodeURIComponent(refund.id)+"&limit=1");
 const row=rows?.[0];
 if(!row||row.payment_id!==refund.payment_id||Number(refund.amount)!==Number(row.amount_paise)||refund.currency!=="INR")return json(409,{success:false,error:"Refund event does not match a prepared refund."});
 const state=await reconcile(row.id,refund);
 if(eventName==="refund.failed")return json(200,{success:true,provider_status:"failed",internal_status:"failed"});
 return json(state.internal_status==="processed"?200:202,{success:true,provider_status:refund.status,internal_status:state.internal_status});
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"POST only."});
 if(!SUPABASE_URL||!SERVICE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"Refund executor configuration incomplete."});
 try{
  if(event.path?.includes("razorpay-refund-webhook"))return await webhook(event);
  return await execute(event);
 }catch(error){console.error("Refund endpoint error:",error?.status||error?.name||"Unknown");return json(500,{success:false,error:"Refund request could not be safely completed."});}
};

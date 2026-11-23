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
 if(!r.ok){const e=new Error(data?.error?.description||"Razorpay request failed");e.status=r.status;throw e;}return data;
}
function one(value){return Array.isArray(value)?value[0]:value;}
async function reconcile(refundRecordId,providerRefund){
 const status=providerRefund?.status;
 if(!["pending","processed","failed"].includes(status))throw new Error("Unknown provider refund state");
 const result=one(await rpc("srk_service_reconcile_booking_refund",{
  p_refund_record_id:refundRecordId,p_provider_refund_id:providerRefund.id,
  p_provider_status:status,p_error:status==="failed"?"Razorpay marked the refund failed":null
 }));
 if(!result?.success)throw new Error("Refund reconciliation was not confirmed");
 return result;
}
async function execute(event){
 const auth=event.headers?.authorization||event.headers?.Authorization||"";
 const match=/^Bearer ([A-Za-z0-9._~-]+)$/.exec(auth);
 if(!match||match[1].length>8192)return json(401,{success:false,error:"Admin login required."});
 const userResponse=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SERVICE_KEY,Authorization:"Bearer "+match[1]}});
 if(!userResponse.ok)return json(401,{success:false,error:"Admin session invalid."});
 const body=JSON.parse(event.body||"{}"),requestId=body.request_id;
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId||""))
  return json(400,{success:false,error:"Invalid refund request."});

 // This Admin RPC creates or returns the one durable full-refund record for the Booking.
 const prepared=one(await rpc("srk_admin_prepare_booking_refund",{p_request_id:requestId},match[1]));
 if(!prepared?.refund_record_id)return json(409,{success:false,error:"Approved full refund request and paid Final Bill snapshot are required."});
 if(prepared.status==="processed")return json(200,{success:true,already_processed:true,refund_record_id:prepared.refund_record_id});

 const records=await rest("srk_razorpay_refunds?select=id,booking_id,payment_id,refund_id,amount_paise,idempotency_key,status,provider_status& id=eq.".replace(" ","")+encodeURIComponent(prepared.refund_record_id)+"&limit=1");
 const record=records?.[0];
 if(!record||record.payment_id!==prepared.payment_id||record.amount_paise!==prepared.amount_paise)
  return json(409,{success:false,error:"Refund record does not match the approved payment."});

 try{
  const payment=await razorpay("payments/"+encodeURIComponent(record.payment_id));
  if(payment.id!==record.payment_id||payment.status!=="captured"||payment.currency!=="INR"
    ||!Number.isSafeInteger(payment.amount)||payment.amount!==record.amount_paise)
   return json(409,{success:false,error:"Captured payment does not match the approved full Final Bill refund."});

  let providerRefund=null;
  if(record.refund_id){
   providerRefund=await razorpay("refunds/"+encodeURIComponent(record.refund_id));
  }else if(Number(payment.amount_refunded||0)>0){
   const prior=await razorpay("payments/"+encodeURIComponent(record.payment_id)+"/refunds");
   const items=Array.isArray(prior?.items)?prior.items:[];
   providerRefund=items.find(x=>x.receipt===record.idempotency_key&&x.amount===record.amount_paise)||null;
   if(!providerRefund)return json(409,{success:false,error:"An earlier refund exists but cannot be matched to this saved idempotency key; Admin reconciliation required."});
  }else{
   providerRefund=await razorpay("payments/"+encodeURIComponent(record.payment_id)+"/refund","POST",{
    amount:record.amount_paise,receipt:record.idempotency_key,
    notes:{booking_id:record.booking_id,refund_record_id:record.id,reason:"SRK ELECTRONIC approved full Final Bill refund"}
   },{"X-Refund-Idempotency":record.idempotency_key});
  }
  if(providerRefund.payment_id!==record.payment_id||providerRefund.amount!==record.amount_paise
    ||providerRefund.currency!=="INR"||!/^rfnd_[A-Za-z0-9]+$/.test(providerRefund.id||""))
   return json(502,{success:false,requires_reconciliation:true,error:"Provider refund does not match the approved refund record."});
  const state=await reconcile(record.id,providerRefund);
  return json(state.status==="processed"?200:state.status==="failed"?200:202,{
   success:true,refund_id:providerRefund.id,amount_paise:record.amount_paise,
   provider_status:providerRefund.status,internal_status:state.status
  });
 }catch(error){
  console.error("Razorpay refund provider/reconciliation error:",error?.status||error?.name||"Unknown");
  return json(202,{success:false,requires_reconciliation:true,
   error:"Refund provider outcome is not yet confirmed. Saved refund record and idempotency key retained; Admin reconciliation is required."});
 }
}
async function webhook(event){
 if(!WEBHOOK_SECRET)return json(500,{success:false,error:"Webhook configuration incomplete."});
 const signature=event.headers?.["x-razorpay-signature"]||event.headers?.["X-Razorpay-Signature"]||"";
 const eventId=event.headers?.["x-razorpay-event-id"]||event.headers?.["X-Razorpay-Event-Id"]||"";
 const raw=event.isBase64Encoded?Buffer.from(event.body||"","base64"):Buffer.from(event.body||"","utf8");
 if(raw.length>1024*1024)return json(413,{success:false,error:"Webhook payload too large."});
 if(!/^[a-f0-9]{64}$/i.test(signature)||!eventId||eventId.length>255)
  return json(400,{success:false,error:"Valid signature and provider event ID are required."});
 const expected=crypto.createHmac("sha256",WEBHOOK_SECRET).update(raw).digest(),received=Buffer.from(signature,"hex");
 if(received.length!==expected.length||!crypto.timingSafeEqual(expected,received))
  return json(400,{success:false,error:"Signature verification failed."});
 try{
  const payload=JSON.parse(raw.toString("utf8")),eventName=payload.event;
  if(!["refund.created","refund.processed","refund.failed"].includes(eventName))
   return json(200,{success:true,ignored:true});
  const refund=payload.payload?.refund?.entity;
  const expectedStatus={"refund.created":"pending","refund.processed":"processed","refund.failed":"failed"}[eventName];
  if(!refund||!/^rfnd_[A-Za-z0-9]+$/.test(refund.id||"")
    ||!/^pay_[A-Za-z0-9]+$/.test(refund.payment_id||"")
    ||!Number.isSafeInteger(refund.amount)||refund.amount<1||refund.currency!=="INR"
    ||refund.status!==expectedStatus)
   return json(400,{success:false,error:"Refund event payload invalid or inconsistent with its event type."});

  const safePayload={event:eventName,refund:{id:refund.id,payment_id:refund.payment_id,
   status:refund.status,amount:refund.amount,currency:refund.currency}};
  await rest("srk_razorpay_webhook_events?on_conflict=event_id",{
   method:"POST",headers:{Prefer:"resolution=ignore-duplicates,return=representation"},
   body:JSON.stringify({event_id:eventId,event_type:eventName,
    razorpay_payment_id:refund.payment_id,razorpay_refund_id:refund.id,
    processing_status:"received",event_payload:safePayload})
  });
  const inbox=one(await rest("srk_razorpay_webhook_events?select=event_id,processing_status&event_id=eq."+encodeURIComponent(eventId)+"&limit=1"));
  if(inbox?.processing_status==="reconciled"||inbox?.processing_status==="ignored")
   return json(200,{success:true,duplicate:true,reconciled:inbox.processing_status==="reconciled"});

  const rows=await rest("srk_razorpay_refunds?select=id,amount_paise,payment_id&refund_id=eq."+encodeURIComponent(refund.id)+"&limit=1");
  const record=rows?.[0];
  if(!record||record.payment_id!==refund.payment_id||record.amount_paise!==refund.amount)
   return json(500,{success:false,reconciliation_required:true,error:"Prepared refund record not yet linked; provider webhook retry required."});
  const state=await reconcile(record.id,refund);
  await rest("srk_razorpay_webhook_events?event_id=eq."+encodeURIComponent(eventId),{
   method:"PATCH",body:JSON.stringify({processing_status:"reconciled",
    processed_at:new Date().toISOString(),updated_at:new Date().toISOString(),reconciliation_reason:null})
  });
  return json(200,{success:true,reconciled:true,provider_status:refund.status,internal_status:state.status});
 }catch(error){
  try{
   if(eventId)await rest("srk_razorpay_webhook_events?event_id=eq."+encodeURIComponent(eventId),{
    method:"PATCH",body:JSON.stringify({processing_status:"exception",
     reconciliation_reason:"Refund webhook reconciliation failed; retry or Admin review required",
     updated_at:new Date().toISOString()})
   });
  }catch(_){}
  console.error("Razorpay refund webhook error:",error?.status||error?.name||"Unknown");
  return json(500,{success:false,reconciliation_required:true,error:"Refund webhook reconciliation failed."});
 }
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"POST only."});
 if(!SUPABASE_URL||!SERVICE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)
  return json(500,{success:false,error:"Refund executor configuration incomplete."});
 try{
  if(event.path?.includes("razorpay-refund-webhook"))return await webhook(event);
  return await execute(event);
 }catch(error){
  console.error("Refund endpoint error:",error?.status||error?.name||"Unknown");
  return json(500,{success:false,error:"Refund request could not be safely completed."});
 }
};

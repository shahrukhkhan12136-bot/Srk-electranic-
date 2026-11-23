const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL;
const SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK_SECRET=process.env.RAZORPAY_WEBHOOK_SECRET;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function db(path,options={}){
 const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});
 const raw=await r.text();let data;try{data=raw?JSON.parse(raw):null}catch{data=null}
 if(!r.ok){const e=new Error("Database request failed");e.status=r.status;e.details=data;throw e;}return data;
}
async function rpc(name,args){return db("rpc/"+name,{method:"POST",body:JSON.stringify(args)});}
function one(value){return Array.isArray(value)?value[0]:value;}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"POST only."});
 if(!SUPABASE_URL||!SUPABASE_KEY||!WEBHOOK_SECRET){console.error("Razorpay webhook server configuration is incomplete.");return json(500,{success:false,error:"Webhook server configuration incomplete."});}
 const signature=event.headers?.["x-razorpay-signature"]||event.headers?.["X-Razorpay-Signature"]||"";
 const eventId=event.headers?.["x-razorpay-event-id"]||event.headers?.["X-Razorpay-Event-Id"]||"";
 const raw=event.isBase64Encoded?Buffer.from(event.body||"","base64"):Buffer.from(event.body||"","utf8");
 if(raw.length>1024*1024)return json(413,{success:false,error:"Webhook payload too large."});
 if(!/^[a-f0-9]{64}$/i.test(signature))return json(400,{success:false,error:"Invalid signature."});
 if(!eventId||eventId.length>255)return json(400,{success:false,error:"Provider event ID missing; safe deduplication is required."});
 const expected=crypto.createHmac("sha256",WEBHOOK_SECRET).update(raw).digest();
 const received=Buffer.from(signature,"hex");
 if(received.length!==expected.length||!crypto.timingSafeEqual(expected,received))return json(400,{success:false,error:"Signature verification failed."});
 try{
  const payload=JSON.parse(raw.toString("utf8"));
  const eventName=payload.event;
  const supported=["payment.captured","order.paid"].includes(eventName);
  const payment=payload.payload?.payment?.entity;
  const validPayment=supported&&payment&&payment.status==="captured"
    &&/^pay_[A-Za-z0-9]+$/.test(payment.id||"")
    &&/^order_[A-Za-z0-9]+$/.test(payment.order_id||"")
    &&Number.isSafeInteger(payment.amount)&&payment.amount>=100
    &&payment.currency==="INR";
  const safePayload={
   event:eventName||"unknown",
   payment:payment?{id:payment.id,order_id:payment.order_id,status:payment.status,amount:payment.amount,currency:payment.currency}:null
  };
  await db("srk_razorpay_webhook_events?on_conflict=event_id",{
   method:"POST",
   headers:{Prefer:"resolution=ignore-duplicates,return=representation"},
   body:JSON.stringify({
    event_id:eventId,event_type:String(eventName||"unknown"),
    razorpay_order_id:payment?.order_id||null,razorpay_payment_id:payment?.id||null,
    payment_amount_paise:Number.isSafeInteger(payment?.amount)?payment.amount:null,
    payment_currency:payment?.currency||null,
    processing_status:supported?"received":"ignored",
    event_payload:safePayload
   })
  });
  const existing=one(await db("srk_razorpay_webhook_events?select=event_id,processing_status&event_id=eq."+encodeURIComponent(eventId)+"&limit=1"));
  if(existing?.processing_status==="reconciled"||existing?.processing_status==="ignored"){
   return json(200,{success:true,reconciled:existing.processing_status==="reconciled",duplicate:true});
  }
  if(!supported){
   await db("srk_razorpay_webhook_events?event_id=eq."+encodeURIComponent(eventId),{
    method:"PATCH",body:JSON.stringify({processing_status:"ignored",processed_at:new Date().toISOString(),updated_at:new Date().toISOString()})
   });
   return json(200,{success:true,ignored:true});
  }
  if(!validPayment){
   await db("srk_razorpay_webhook_events?event_id=eq."+encodeURIComponent(eventId),{
    method:"PATCH",body:JSON.stringify({processing_status:"exception",reconciliation_reason:"Captured INR payment payload is incomplete or invalid",updated_at:new Date().toISOString()})
   });
   return json(500,{success:false,reconciled:false,reason:"invalid_captured_payment"});
  }
  const result=one(await rpc("srk_service_finalize_razorpay_payment",{
   p_razorpay_order_id:payment.order_id,p_razorpay_payment_id:payment.id,
   p_amount_paise:payment.amount,p_currency:payment.currency
  }));
  if(!result?.success)throw new Error("Payment finalizer did not confirm success");
  await db("srk_razorpay_webhook_events?event_id=eq."+encodeURIComponent(eventId),{
   method:"PATCH",body:JSON.stringify({processing_status:"reconciled",processed_at:new Date().toISOString(),reconciliation_reason:null,updated_at:new Date().toISOString()})
  });
  return json(200,{success:true,reconciled:true,already_processed:!!result.already_processed});
 }catch(error){
  try{
   if(eventId)await db("srk_razorpay_webhook_events?event_id=eq."+encodeURIComponent(eventId),{
    method:"PATCH",body:JSON.stringify({processing_status:"exception",reconciliation_reason:"Payment finalization or event persistence failed; retry/reconcile required",updated_at:new Date().toISOString()})
   });
  }catch(_){}
  console.error("Razorpay webhook processing failed:",error?.status||error?.name||"Unknown");
  return json(500,{success:false,reconciled:false,error:"Webhook processing failed; reconciliation required."});
 }
};

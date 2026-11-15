const {createHash,randomUUID}=require("node:crypto");
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PAYMENT=/^pay_[A-Za-z0-9]+$/;
const REFUND=/^rfnd_[A-Za-z0-9]+$/;
function json(statusCode,body){return{statusCode,headers:{"Content-Type":"application/json","Cache-Control":"no-store"},body:JSON.stringify(body)};}
async function readJson(response){const raw=await response.text();let value=null;try{value=raw?JSON.parse(raw):null;}catch(_){throw new Error("INVALID_UPSTREAM_JSON");}if(!response.ok){const error=new Error(value?.message||"UPSTREAM_REQUEST_FAILED");error.status=response.status;throw error;}return value;}
function env(){return{url:process.env.SUPABASE_URL,key:process.env.SUPABASE_SERVICE_ROLE_KEY,rzpId:process.env.RAZORPAY_KEY_ID,rzpSecret:process.env.RAZORPAY_KEY_SECRET};}
async function adminUser(token,cfg){
 const auth=await fetch(cfg.url+"/auth/v1/user",{headers:{apikey:cfg.key,Authorization:"Bearer "+token},signal:AbortSignal.timeout(10000)});
 if(!auth.ok)return null;const user=await readJson(auth);if(!user?.id||!UUID.test(user.id))return null;
 const check=await fetch(cfg.url+"/rest/v1/rpc/is_srk_admin",{method:"POST",headers:{apikey:cfg.key,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:"{}",signal:AbortSignal.timeout(10000)});
 if(!check.ok||await readJson(check)!==true)return null;return user;
}
async function dbGet(path,cfg){return readJson(await fetch(cfg.url+path,{method:"GET",headers:{apikey:cfg.key,Authorization:"Bearer "+cfg.key,Accept:"application/json"},signal:AbortSignal.timeout(10000)}));}
async function rpc(name,args,cfg){
 return readJson(await fetch(cfg.url+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:cfg.key,Authorization:"Bearer "+cfg.key,"Content-Type":"application/json",Accept:"application/json"},body:JSON.stringify(args),signal:AbortSignal.timeout(15000)}));
}
async function providerGet(path,cfg){
 const auth=Buffer.from(cfg.rzpId+":"+cfg.rzpSecret).toString("base64");
 return readJson(await fetch("https://api.razorpay.com/v1"+path,{method:"GET",headers:{Authorization:"Basic "+auth,Accept:"application/json"},signal:AbortSignal.timeout(15000)}));
}
function exactMatch(item,record){
 if(!item||item.payment_id!==record.payment_id||Number(item.amount)!==Number(record.amount_paise)||item.currency!=="INR")return false;
 const notes=item.notes&&typeof item.notes==="object"?item.notes:{};
 return notes.srk_refund_record_id===record.id||item.receipt===record.idempotency_key;
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 const cfg=env();if(!cfg.url||!cfg.key||!cfg.rzpId||!cfg.rzpSecret)return json(500,{success:false,error:"Refund recovery server configuration is incomplete."});
 const auth=event.headers?.authorization||event.headers?.Authorization||"";const match=/^Bearer ([A-Za-z0-9._~-]{20,8192})$/.exec(auth);
 if(!match)return json(401,{success:false,error:"Main Admin login required."});
 let input;try{input=JSON.parse(event.body||"{}");}catch(_){return json(400,{success:false,error:"Invalid JSON request."});}
 const bookingId=input?.booking_id,note=typeof input?.admin_note==="string"?input.admin_note.trim():"";
 if(!UUID.test(bookingId||""))return json(400,{success:false,error:"Valid booking ID required."});
 if(note.length<10||note.length>2000)return json(400,{success:false,error:"Recovery audit note must contain 10–2000 characters."});
 try{
  const user=await adminUser(match[1],cfg);if(!user)return json(403,{success:false,error:"Only Main Admin can run refund recovery."});
  const rows=await dbGet("/rest/v1/srk_razorpay_refunds?booking_id=eq."+encodeURIComponent(bookingId)+"&select=id,booking_id,payment_id,refund_id,amount_paise,currency,idempotency_key,status&limit=2",cfg);
  if(!Array.isArray(rows)||rows.length!==1)return json(409,{success:false,error:"Exactly one internal refund record is required.",safe_to_retry:false});
  const record=rows[0];
  if(!UUID.test(record.id||"")||!PAYMENT.test(record.payment_id||"")||!Number.isSafeInteger(Number(record.amount_paise))||Number(record.amount_paise)<=0||record.currency!=="INR"||!record.idempotency_key)
   return json(409,{success:false,error:"Internal refund identity/amount is invalid.",safe_to_retry:false});
  const bookings=await dbGet("/rest/v1/service_bookings?id=eq."+encodeURIComponent(bookingId)+"&select=id,razorpay_payment_id&limit=2",cfg);
  if(!Array.isArray(bookings)||bookings.length!==1||bookings[0].razorpay_payment_id!==record.payment_id)
   return json(409,{success:false,error:"Booking and refund Payment ID do not match.",safe_to_retry:false});
  let providerRefund,lookupMode="refund_id";
  if(record.refund_id){
   if(!REFUND.test(record.refund_id))return json(409,{success:false,error:"Stored provider Refund ID is invalid.",safe_to_retry:false});
   providerRefund=await providerGet("/refunds/"+encodeURIComponent(record.refund_id),cfg);
  }else{
   lookupMode="payment_refund_list";
   const collection=await providerGet("/payments/"+encodeURIComponent(record.payment_id)+"/refunds?count=100",cfg);
   const matches=(Array.isArray(collection?.items)?collection.items:[]).filter(item=>exactMatch(item,record));
   if(matches.length!==1)return json(202,{success:false,evidence_saved:false,status:matches.length?"multiple_provider_matches":"provider_record_not_found_in_first_page",safe_to_retry:false,message:"Provider record का exact match नहीं मिला। Pagination/late visibility की जाँच करें; नया refund न बनाएँ।"});
   providerRefund=matches[0];
  }
  if(!providerRefund||!REFUND.test(providerRefund.id||"")||providerRefund.id!==(record.refund_id||providerRefund.id)||!exactMatch(providerRefund,record)||!["pending","processed","failed"].includes(providerRefund.status))
   return json(409,{success:false,error:"Razorpay response did not exactly match the internal refund record.",safe_to_retry:false});
  const providerCreatedAt=Number.isFinite(Number(providerRefund.created_at))?new Date(Number(providerRefund.created_at)*1000).toISOString():null;
  const acquirer=providerRefund.acquirer_data||{};
  const acquirerReference=acquirer.arn||acquirer.rrn||acquirer.utr||null;
  const payloadHash=createHash("sha256").update(JSON.stringify(providerRefund)).digest("hex");
  const evidenceId=await rpc("srk_service_record_razorpay_refund_recovery_evidence",{
   p_refund_record_id:record.id,p_provider_refund_id:providerRefund.id,p_payment_id:providerRefund.payment_id,
   p_amount_paise:Number(providerRefund.amount),p_currency:providerRefund.currency,p_provider_status:providerRefund.status,
   p_provider_created_at:providerCreatedAt,p_acquirer_reference:acquirerReference,p_provider_payload_sha256:payloadHash,
   p_observation_id:randomUUID(),p_provider_evidence:providerRefund,p_admin_user_id:user.id,p_admin_note:note
  },cfg);
  if(typeof evidenceId!=="string"||!UUID.test(evidenceId))return json(502,{success:false,evidence_saved:false,error:"Recovery evidence RPC did not return a valid audit ID.",safe_to_retry:false});
  if(providerRefund.status!=="processed")return json(202,{success:true,evidence_saved:true,accounting_finalized:false,recovery_audit_id:evidenceId,provider_status:providerRefund.status,safe_to_retry:false,message:"Provider प्रमाण अलग transaction में सुरक्षित हुआ। केवल processed status ही accounting finalization के योग्य है; कोई payout release या नया refund नहीं किया गया।"});
  try{
   // This is intentionally a second HTTP/PostgREST request and therefore a separate DB transaction.
   const finalized=await rpc("srk_service_finalize_razorpay_refund_from_recovery_evidence",{p_recovery_audit_id:evidenceId},cfg);
   return json(200,{success:true,evidence_saved:true,accounting_finalized:true,recovery_audit_id:evidenceId,finalization:finalized,safe_to_retry:false,message:"Razorpay processed प्रमाण सुरक्षित हुआ और अलग transaction में accounting finalization सफल हुई।"});
  }catch(error){
   console.error("Refund recovery accounting finalization failed:",error?.status||error?.name||"Unknown");
   return json(202,{success:false,evidence_saved:true,accounting_finalized:false,recovery_audit_id:evidenceId,safe_to_retry:false,error:"Provider प्रमाण सुरक्षित है, लेकिन accounting finalization अभी सफल नहीं हुई। उसी audit ID से Admin जाँच आवश्यक है; नया refund न बनाएँ और payout release न करें."});
  }
 }catch(error){
  console.error("Razorpay refund recovery failed:",error?.status||error?.name||"Unknown");
  return json(502,{success:false,evidence_saved:false,safe_to_retry:false,error:"Refund recovery अभी पूरी नहीं हो सकी। Provider या database स्थिति verify नहीं हुई; कोई नया refund/retry न करें."});
 }
};

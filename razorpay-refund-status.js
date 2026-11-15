const SUPABASE_URL=(process.env.SUPABASE_URL||"").replace(/\/$/,"");
const SUPABASE_SERVICE_ROLE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||"";
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY||"";
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY||"";
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PAYMENT=/^pay_[A-Za-z0-9]+$/;
const REFUND=/^rfnd_[A-Za-z0-9]+$/;

async function readJson(response){
 const raw=await response.text();let data=null;
 try{data=raw?JSON.parse(raw):null;}catch(_){data=null;}
 if(!response.ok){const error=new Error("Request failed");error.status=response.status;throw error;}
 return data;
}
async function providerGet(path){
 const auth=Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64");
 const response=await fetch("https://api.razorpay.com/v1"+path,{method:"GET",headers:{Authorization:"Basic "+auth,Accept:"application/json"},signal:AbortSignal.timeout(15000)});
 return readJson(response);
}
async function dbGet(path){
 const response=await fetch(SUPABASE_URL+path,{method:"GET",headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:"Bearer "+SUPABASE_SERVICE_ROLE_KEY,Accept:"application/json"},signal:AbortSignal.timeout(10000)});
 return readJson(response);
}
async function verifyAdmin(token){
 const auth=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:"Bearer "+token},signal:AbortSignal.timeout(10000)});
 if(!auth.ok)return false;
 const user=await readJson(auth);
 if(!user?.id)return false;
 const response=await fetch(SUPABASE_URL+"/rest/v1/rpc/is_srk_admin",{method:"POST",headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:"{}",signal:AbortSignal.timeout(10000)});
 if(!response.ok)return false;
 return (await readJson(response))===true;
}
function providerIdentityMatches(item,record){
 if(!item||item.payment_id!==record.payment_id||Number(item.amount)!==Number(record.amount_paise)||item.currency!=="INR")return false;
 const notes=item.notes&&typeof item.notes==="object"?item.notes:{};
 const noteRecord=notes.srk_refund_record_id;
 const receipt=item.receipt;
 return noteRecord===record.id||receipt===record.idempotency_key;
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_SERVICE_ROLE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"Refund status server configuration is incomplete."});
 const authorization=event.headers?.authorization||event.headers?.Authorization||"";
 const tokenMatch=/^Bearer ([A-Za-z0-9._~-]{20,8192})$/.exec(authorization);
 if(!tokenMatch)return json(401,{success:false,error:"Main Admin login required."});
 let input;try{input=JSON.parse(event.body||"{}");}catch(_){return json(400,{success:false,error:"Invalid JSON request."});}
 const bookingId=input?.booking_id;
 if(!UUID.test(bookingId||""))return json(400,{success:false,error:"Valid booking ID required."});
 try{
  if(!await verifyAdmin(tokenMatch[1]))return json(403,{success:false,error:"Only Main Admin can inspect provider refund status."});
  const query="?booking_id=eq."+encodeURIComponent(bookingId)+"&select=id,booking_id,payment_id,refund_id,amount_paise,idempotency_key,status,provider_status,last_error&limit=2";
  const records=await dbGet("/rest/v1/srk_razorpay_refunds"+query);
  if(!Array.isArray(records)||records.length!==1)return json(409,{success:false,verified:false,status:"record_missing_or_ambiguous",safe_to_retry:false,error:"एक booking के लिए ठीक एक Refund Record नहीं मिला। कोई retry न करें।"});
  const record=records[0];
  if(!PAYMENT.test(record.payment_id||"")||!Number.isSafeInteger(Number(record.amount_paise))||Number(record.amount_paise)<100||!record.idempotency_key)
   return json(409,{success:false,verified:false,status:"internal_record_invalid",safe_to_retry:false,error:"Internal Refund Record का payment/amount/idempotency data valid नहीं है।"});
  const bookings=await dbGet("/rest/v1/service_bookings?id=eq."+encodeURIComponent(bookingId)+"&select=id,razorpay_payment_id&limit=2");
  if(!Array.isArray(bookings)||bookings.length!==1||bookings[0].razorpay_payment_id!==record.payment_id)
   return json(409,{success:false,verified:false,status:"booking_payment_mismatch",safe_to_retry:false,error:"Booking और Refund Payment ID का मिलान नहीं हुआ।"});
  let providerRefund=null,lookupMode="refund_id";
  if(record.refund_id){
   if(!REFUND.test(record.refund_id))return json(409,{success:false,verified:false,status:"internal_refund_id_invalid",safe_to_retry:false,error:"Stored Provider Refund ID valid नहीं है।"});
   providerRefund=await providerGet("/refunds/"+encodeURIComponent(record.refund_id));
  }else{
   lookupMode="payment_refund_list";
   const collection=await providerGet("/payments/"+encodeURIComponent(record.payment_id)+"/refunds?count=100");
   const items=Array.isArray(collection?.items)?collection.items:[];
   const matches=items.filter(item=>providerIdentityMatches(item,record));
   if(matches.length!==1)return json(202,{success:true,verified:false,status:matches.length?"multiple_provider_matches":"provider_record_not_found_in_first_page",safe_to_retry:false,lookup_mode:lookupMode,message:matches.length?"एक से अधिक provider refunds इस internal record से match हुए। Manual investigation आवश्यक है।":"पहले 100 provider records में matching refund नहीं मिला। यह प्रमाण नहीं है कि refund नहीं बना; pagination/late visibility की जाँच करें।"});
   providerRefund=matches[0];
  }
  if(!providerRefund||!REFUND.test(providerRefund.id||"")||providerRefund.id!==(record.refund_id||providerRefund.id)||!providerIdentityMatches(providerRefund,record)||!["pending","processed","failed"].includes(providerRefund.status))
   return json(409,{success:false,verified:false,status:"provider_record_mismatch",safe_to_retry:false,error:"Razorpay response internal Refund Record से exact match नहीं हुआ। कोई retry या payout release न करें।"});
  return json(200,{success:true,verified:true,read_only:true,safe_to_retry:false,lookup_mode:lookupMode,booking_id:bookingId,refund_record_id:record.id,provider:{refund_id:providerRefund.id,payment_id:providerRefund.payment_id,amount_paise:providerRefund.amount,currency:providerRefund.currency,status:providerRefund.status,created_at:providerRefund.created_at,acquirer_reference:providerRefund.acquirer_data?.arn||providerRefund.acquirer_data?.rrn||providerRefund.acquirer_data?.utr||null},internal:{record_status:record.status,provider_status:record.provider_status,last_error:record.last_error},message:"Provider status read-only तरीके से verify हुआ। यह endpoint Database, Refund, Wallet या Payout में कोई बदलाव नहीं करता।"});
 }catch(error){
  const status=error?.status===401?502:502;
  console.error("Razorpay read-only refund lookup failed:",error?.status||error?.name||"Unknown");
  return json(status,{success:false,verified:false,status:"provider_lookup_unavailable",safe_to_retry:false,error:"Provider स्थिति अभी verify नहीं हो सकी। कोई retry या payout release न करें; कुछ देर बाद दोबारा जाँचें।"});
 }
};

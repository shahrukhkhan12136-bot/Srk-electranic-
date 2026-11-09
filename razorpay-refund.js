const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL;
const SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID||process.env.APIKEY;
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET||process.env.SECRETAPIKEY;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function patchRefund(id,fields){
 const url=new URL("/rest/v1/srk_razorpay_refunds",SUPABASE_URL);url.searchParams.set("id","eq."+id);
 const r=await fetch(url,{method:"PATCH",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({...fields,updated_at:new Date().toISOString()})});
 if(!r.ok)throw new Error("Refund reconciliation update failed");
}
async function restorePendingPayout(bookingId){
 const url=new URL("/rest/v1/srk_electrician_payouts",SUPABASE_URL);
 url.searchParams.set("booking_id","eq."+bookingId);url.searchParams.set("payout_status","eq.blocked");
 url.searchParams.set("payout_note","eq.Razorpay refund pending");
 await fetch(url,{method:"PATCH",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({payout_status:"pending",payout_note:null,updated_at:new Date().toISOString()})});
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"केवल POST अनुरोध स्वीकार है।"});
 if(!SUPABASE_URL||!SUPABASE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)return json(500,{success:false,error:"Refund server configuration incomplete."});
 try{
  const body=JSON.parse(event.body||"{}"),bookingId=typeof body.booking_id==="string"?body.booking_id:"",reason=typeof body.reason==="string"?body.reason.trim():"";
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookingId)||reason.length<20||reason.length>250)return json(400,{success:false,error:"बुकिंग ID या Refund कारण सही नहीं है।"});
  const auth=event.headers?.authorization||event.headers?.Authorization||"";
  const tokenMatch=/^Bearer ([A-Za-z0-9._~-]{20,8192})$/.exec(auth);
  if(!tokenMatch)return json(401,{success:false,error:"Admin login आवश्यक है।"});
  const userResponse=await fetch(SUPABASE_URL+"/auth/v1/user",{headers:{apikey:SUPABASE_KEY,Authorization:auth}});
  if(!userResponse.ok)return json(401,{success:false,error:"Admin session मान्य नहीं है।"});
  const user=await userResponse.json();if(!user.id)return json(401,{success:false,error:"Admin session मान्य नहीं है।"});
  const prepared=await fetch(SUPABASE_URL+"/rest/v1/rpc/srk_admin_prepare_razorpay_refund",{
   method:"POST",headers:{apikey:SUPABASE_KEY,Authorization:auth,"Content-Type":"application/json"},
   body:JSON.stringify({p_booking_id:bookingId,p_reason:reason})
  });
  const preparedText=await prepared.text();let rows;try{rows=JSON.parse(preparedText)}catch{rows=null}
  if(!prepared.ok||!Array.isArray(rows)||!rows[0])return json(prepared.status===401||prepared.status===403?403:409,{success:false,error:"Refund की अनुमति या Booking validation पूरी नहीं हुई।"});
  const row=rows[0];
  if(row.status==="processed")return json(200,{success:true,status:"processed",message:"यह Refund पहले ही reconcile हो चुका है।"});
  if(row.status==="failed")return json(409,{success:false,status:"failed",error:"पिछला Refund failed है; पहले Razorpay Dashboard में reconcile करें।"});
  const keyId=RAZORPAY_KEY_ID,secret=RAZORPAY_KEY_SECRET;
  const basic=Buffer.from(keyId+":"+secret).toString("base64");
  const provider=await fetch("https://api.razorpay.com/v1/payments/"+encodeURIComponent(row.payment_id)+"/refund",{
   method:"POST",headers:{Authorization:"Basic "+basic,"Content-Type":"application/json","X-Refund-Idempotency":row.idempotency_key},
   body:JSON.stringify({amount:Number(row.amount_paise),notes:{booking_id:row.booking_id,refund_record_id:row.refund_record_id||row.refund_record_id||""}})
  });
  const raw=await provider.text();let result;try{result=raw?JSON.parse(raw):{}}catch{result={}}
  if(!provider.ok){
   const uncertain=provider.status===409||provider.status>=500;
   await patchRefund(row.refund_record_id,{status:uncertain?"unknown":"failed",provider_status:result.status||null,last_error:"Razorpay API HTTP "+provider.status});
   if(!uncertain)await restorePendingPayout(row.booking_id);
   return json(uncertain?202:409,{success:false,status:uncertain?"unknown":"failed",error:uncertain?"Refund request का अंतिम परिणाम स्पष्ट नहीं है। वही idempotency key सुरक्षित रखी गई है; Dashboard/webhook से मिलान करें।":"Razorpay ने Refund अनुरोध अस्वीकार किया। Dashboard में कारण जाँचें।"});
  }
  if(!/^rfnd_[A-Za-z0-9]+$/.test(result.id||"")||result.payment_id!==row.payment_id||result.amount!==Number(row.amount_paise)){
   await patchRefund(row.refund_record_id,{status:"unknown",last_error:"Provider response requires reconciliation"});
   return json(202,{success:false,status:"unknown",error:"Razorpay response मिला, लेकिन विवरण का मिलान नहीं हुआ। Admin reconciliation जरूरी है।"});
  }
  await patchRefund(row.refund_record_id,{refund_id:result.id,status:"processing",provider_status:result.status||"pending",last_error:null});
  return json(202,{success:true,status:"processing",refund_id:result.id,message:"Refund अनुरोध Razorpay को भेजा गया। अंतिम स्थिति verified webhook के बाद अपडेट होगी।"});
 }catch(error){console.error("Razorpay refund request failed:",error?.name||"UnknownError");return json(500,{success:false,error:"Refund request पूरी नहीं हुई; पहले Dashboard और Admin Refund status जाँचें, फिर उसी अनुरोध को retry करें।"});}
};

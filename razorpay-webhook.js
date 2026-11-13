const crypto=require("crypto");
const SUPABASE_URL=process.env.SUPABASE_URL,SUPABASE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY,WEBHOOK_SECRET=process.env.RAZORPAY_WEBHOOK_SECRET;
const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
async function db(path,options={}){const r=await fetch(SUPABASE_URL+"/rest/v1/"+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation",...(options.headers||{})}});const raw=await r.text();let d;try{d=raw?JSON.parse(raw):null}catch{d=null}if(!r.ok)throw new Error("Database request failed");return d}
async function expectedAmountPaise(booking){
 if(booking.selected_category){
  if(booking.completion_approval_status!=="approved")return null;
  const bill=await db("rpc/srk_service_get_labour_bill_for_payment",{method:"POST",body:JSON.stringify({p_booking_id:booking.id})});
  const amount=Number(bill?.labour_amount_paise);
  return Number.isSafeInteger(amount)&&amount>=100?amount:null;
 }
 if(booking.quote_status!=="approved")return null;
 const total=Number(booking.service_charge)+Number(booking.materials_amount),quoted=Number(booking.quoted_amount),amount=Math.round(total*100);
 return Number.isFinite(total)&&total>=1&&Number.isFinite(quoted)&&amount===Math.round(quoted*100)&&Number.isSafeInteger(amount)&&amount>=100?amount:null;
}
async function updateBooking(orderId,payment){
 const url=new URL("/rest/v1/service_bookings",SUPABASE_URL);
 url.searchParams.set("razorpay_order_id","eq."+orderId);
 url.searchParams.set("select","id,selected_category,completion_approval_status,quoted_amount,service_charge,materials_amount,quote_status,status,payment_status,payment_method,razorpay_payment_id");
 const response=await fetch(url,{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY}});
 if(!response.ok)throw new Error("Booking lookup failed");
 const rows=await response.json(),booking=Array.isArray(rows)?rows[0]:null;
 if(!booking)return "not_found";
 if(String(booking.payment_method||"").trim().toLowerCase()!=="razorpay ऑनलाइन भुगतान")return "cash_booking";
 if(booking.payment_status==="paid")return booking.razorpay_payment_id===payment.id?"already_processed":"payment_conflict";
 if(booking.status!=="completed")return "booking_not_payable";
 const expectedAmount=await expectedAmountPaise(booking);
 if(!expectedAmount||payment.amount!==expectedAmount||payment.currency!=="INR")return "amount_mismatch";
 const finalized=await db("rpc/srk_service_finalize_captured_payment",{method:"POST",body:JSON.stringify({
  p_booking_id:booking.id,p_razorpay_order_id:orderId,p_razorpay_payment_id:payment.id,
  p_amount_paise:payment.amount,p_currency:payment.currency
 })});
 return finalized?.already_processed?"already_processed":"updated";
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"POST only."});
 if(!SUPABASE_URL||!SUPABASE_KEY||!WEBHOOK_SECRET){console.error("Razorpay webhook server configuration is incomplete.");return json(500,{success:false,error:"Webhook server configuration incomplete."});}
 const signature=event.headers?.["x-razorpay-signature"]||event.headers?.["X-Razorpay-Signature"]||"";
 const rawBody=event.isBase64Encoded?Buffer.from(event.body||"","base64"):Buffer.from(event.body||"","utf8");
 if(!/^[a-f0-9]{64}$/i.test(signature))return json(400,{success:false,error:"Invalid signature."});
 const expected=crypto.createHmac("sha256",WEBHOOK_SECRET).update(rawBody).digest(),received=Buffer.from(signature,"hex");
 if(received.length!==expected.length||!crypto.timingSafeEqual(expected,received))return json(400,{success:false,error:"Signature verification failed."});
 try{
  const payload=JSON.parse(rawBody.toString("utf8")),eventName=payload.event;
  if(eventName!=="payment.captured"&&eventName!=="order.paid")return json(200,{success:true,ignored:true});
  const payment=payload.payload?.payment?.entity;
  if(!payment||payment.status!=="captured"||!/^pay_[A-Za-z0-9]+$/.test(payment.id||"")||!/^order_[A-Za-z0-9]+$/.test(payment.order_id||""))return json(400,{success:false,error:"Captured payment details missing."});
  const result=await updateBooking(payment.order_id,payment);
  if(result==="update_not_applied"){console.error("Razorpay webhook update was not applied; retry requested.");return json(500,{success:false,reconciled:false,reason:result});}
  if(["not_found","amount_mismatch","payment_conflict","booking_not_payable","cash_booking"].includes(result)){console.error("Razorpay webhook needs payment reconciliation; retry requested:",result);return json(500,{success:false,reconciled:false,reason:result});}
  return json(200,{success:true,reconciled:true,result});
 }catch(error){console.error("Razorpay webhook processing failed:",error?.name||"UnknownError");return json(500,{success:false,error:"Webhook processing failed."});}
};

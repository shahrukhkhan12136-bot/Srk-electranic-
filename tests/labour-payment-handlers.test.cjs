const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');

process.env.SUPABASE_URL='https://supabase.test';
process.env.SUPABASE_SERVICE_ROLE_KEY='service-role-test';
process.env.RAZORPAY_KEY_ID='rzp_test_key';
process.env.RAZORPAY_KEY_SECRET='rzp_test_secret';
process.env.RAZORPAY_WEBHOOK_SECRET='webhook-test-secret';

const createOrder=require('../create-order').handler;
const verifyPayment=require('../verify-payment').handler;
const webhook=require('../razorpay-webhook').handler;
const BOOKING_ID='123e4567-e89b-42d3-a456-426614174000';
const USER_ID='123e4567-e89b-42d3-a456-426614174001';
const ORDER_ID='order_test123456';
const PAYMENT_ID='pay_test123456';
const AUTH='Bearer customer-session-token';
const baseBooking=()=>({
 id:BOOKING_ID,phone:'9876543210',customer_user_id:USER_ID,
 selected_category:'home_wiring',completion_approval_status:'approved',
 quoted_amount:1,service_charge:2,materials_amount:999,
 quote_status:'not_submitted',payment_status:'unpaid',
 payment_method:'Razorpay ऑनलाइन भुगतान',razorpay_order_id:null,
 razorpay_payment_id:null,status:'completed'
});
function response(status,value){const raw=typeof value==='string'?value:JSON.stringify(value);return {ok:status>=200&&status<300,status,text:async()=>raw,json:async()=>JSON.parse(raw)}}
function event(body,headers={}){return {httpMethod:'POST',headers,body:typeof body==='string'?body:JSON.stringify(body)}}
function setupFetch({booking=baseBooking(),bill={booking_id:BOOKING_ID,labour_amount_paise:119900,labour_amount:1199,billable_minutes:480},capturedAmount=119900,lock=true}={}){
 const calls=[];
 global.fetch=async(input,options={})=>{
  const url=String(input),method=options.method||'GET';calls.push({url,method,body:options.body});
  if(url.includes('/auth/v1/user'))return response(200,{id:USER_ID,phone:'+919876543210',phone_confirmed_at:'2026-01-01T00:00:00Z'});
  if(url.includes('/rpc/srk_service_get_labour_bill_for_payment'))return response(200,bill);
  if(url.includes('/rpc/srk_claim_payment_order_lock'))return response(200,lock?'lock-token':null);
  if(url.includes('/rpc/srk_release_payment_order_lock'))return response(200,true);
  if(url.includes('api.razorpay.com/v1/orders')&&method==='POST')return response(200,{id:ORDER_ID,status:'created',amount:capturedAmount,currency:'INR'});
  if(url.includes('api.razorpay.com/v1/payments/'))return response(200,{id:PAYMENT_ID,order_id:ORDER_ID,status:'captured',currency:'INR',amount:capturedAmount});
  if(url.includes('/rest/v1/service_bookings')&&method==='GET')return response(200,[booking]);
  if(url.includes('/rest/v1/service_bookings')&&method==='PATCH'){
   const patch=JSON.parse(options.body);Object.assign(booking,patch);return response(200,[booking]);
  }
  return response(404,{message:'unexpected request '+url});
 };
 return {calls,booking};
}

test('create-order uses final labour bill snapshot, not quote or legacy material amount',async()=>{
 const {calls}=setupFetch();
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,200);
 const body=JSON.parse(result.body);
 assert.equal(body.amount,119900);
 const orderCall=calls.find(x=>x.url.includes('api.razorpay.com/v1/orders')&&x.method==='POST');
 assert.ok(orderCall);
 assert.equal(JSON.parse(orderCall.body).amount,119900);
 assert.ok(calls.some(x=>x.url.includes('/rpc/srk_service_get_labour_bill_for_payment')));
});

test('create-order fails closed when final labour bill snapshot is absent',async()=>{
 setupFetch({bill:null});
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,502);
});

test('create-order rejects a booking owned by another customer',async()=>{
 const {booking}=setupFetch();booking.customer_user_id='123e4567-e89b-42d3-a456-426614174099';
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,403);
});

test('verify-payment accepts captured amount only when it matches final labour snapshot',async()=>{
 const {calls}=setupFetch();
 const signature=crypto.createHmac('sha256',process.env.RAZORPAY_KEY_SECRET).update(ORDER_ID+'|'+PAYMENT_ID).digest('hex');
 const result=await verifyPayment(event({razorpay_payment_id:PAYMENT_ID,razorpay_order_id:ORDER_ID,razorpay_signature:signature},{authorization:AUTH}));
 assert.equal(result.statusCode,200);
 assert.ok(calls.some(x=>x.url.includes('/rpc/srk_service_get_labour_bill_for_payment')));
 const patch=calls.find(x=>x.method==='PATCH');
 assert.equal(JSON.parse(patch.body).amount_paid,1199);
});

test('verify-payment rejects captured payment whose amount differs from final bill',async()=>{
 setupFetch({capturedAmount:119800});
 const signature=crypto.createHmac('sha256',process.env.RAZORPAY_KEY_SECRET).update(ORDER_ID+'|'+PAYMENT_ID).digest('hex');
 const result=await verifyPayment(event({razorpay_payment_id:PAYMENT_ID,razorpay_order_id:ORDER_ID,razorpay_signature:signature},{authorization:AUTH}));
 assert.equal(result.statusCode,409);
});

test('webhook reconciles payment using final labour bill snapshot',async()=>{
 const {calls}=setupFetch();
 const payload={event:'payment.captured',payload:{payment:{entity:{id:PAYMENT_ID,order_id:ORDER_ID,status:'captured',currency:'INR',amount:119900}}}};
 const raw=JSON.stringify(payload);
 const signature=crypto.createHmac('sha256',process.env.RAZORPAY_WEBHOOK_SECRET).update(raw).digest('hex');
 const result=await webhook(event(raw,{'x-razorpay-signature':signature}));
 assert.equal(result.statusCode,200);
 assert.equal(JSON.parse(result.body).reconciled,true);
 assert.ok(calls.some(x=>x.url.includes('/rpc/srk_service_get_labour_bill_for_payment')));
});

test('webhook refuses amount mismatch with final labour bill',async()=>{
 setupFetch({capturedAmount:119800});
 const payload={event:'payment.captured',payload:{payment:{entity:{id:PAYMENT_ID,order_id:ORDER_ID,status:'captured',currency:'INR',amount:119800}}}};
 const raw=JSON.stringify(payload);
 const signature=crypto.createHmac('sha256',process.env.RAZORPAY_WEBHOOK_SECRET).update(raw).digest('hex');
 const result=await webhook(event(raw,{'x-razorpay-signature':signature}));
 assert.equal(result.statusCode,200);
 assert.equal(JSON.parse(result.body).reconciled,false);
});

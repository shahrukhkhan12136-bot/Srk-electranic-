const test=require("node:test");
const assert=require("node:assert/strict");
process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="test-key";
process.env.RAZORPAY_KEY_ID="test-id";
process.env.RAZORPAY_KEY_SECRET="test-secret";
const {handler}=require("../razorpay-refund.js");
test("refund endpoint rejects missing login",async()=>{
 const result=await handler({httpMethod:"POST",headers:{},body:"{}"});
 assert.equal(result.statusCode,401);
});

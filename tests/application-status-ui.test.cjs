const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
test('electrician application status panel requires OTP and calls the authenticated status endpoint',()=>{
 const html=fs.readFileSync('apply-electrician.html','utf8');
 for(const marker of ['id="applicationStatusCard"','id="statusPhone"','id="statusSendOtp"','id="statusOtp"','id="statusVerifyOtp"','id="statusLogout"','signInWithOtp({phone})','verifyOtp({phone,token,type:\'sms\'})','/api/electrician-application-status',"Authorization:'Bearer '+data.session.access_token"])assert.ok(html.includes(marker),'missing status flow marker: '+marker);
 assert.ok(html.includes('document.createElement(\'article\')'),'status data must be rendered as DOM text, not interpolated HTML');
 assert.ok(!html.includes('statusResults.innerHTML'));
});
test('application status route is wired to the Netlify function',()=>{
 const config=fs.readFileSync('netlify.toml','utf8');
 assert.ok(config.includes('from = "/api/electrician-application-status"'));
 assert.ok(config.includes('to = "/.netlify/functions/application-status"'));
});

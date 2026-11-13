const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
test('electrician Home exposes explicit per-device push controls with truthful setup state',()=>{
 const html=fs.readFileSync('electrician.html','utf8');
 for(const marker of ['id="partnerPushCard"','id="partnerPushStatus"','id="partnerPushEnable"','id="partnerPushDisable"','function enablePartnerPush()','function disablePartnerPush()','srk_save_push_subscription','srk_push_subscriptions','cfg.VAPID_PUBLIC_KEY','navigator.serviceWorker.register(\'/sw.js\',{scope:\'/\'})'])assert.ok(html.includes(marker),'missing push control marker: '+marker);
 assert.ok(html.includes('TEST project की key यहाँ उपयोग नहीं की जाएगी'),'must not reuse TEST VAPID key');
 assert.ok(html.includes('Browser में Notifications block हैं'),'must explain denied browser permission');
});
test('service worker handles push and restricts notification navigation to same origin',()=>{
 const sw=fs.readFileSync('sw.js','utf8');
 assert.ok(sw.includes("self.addEventListener('push'"));
 assert.ok(sw.includes("self.addEventListener('notificationclick'"));
 assert.ok(sw.includes('parsed.origin===self.location.origin'));
 assert.ok(sw.includes("'/electrician.html'"));
});
test('existing cache strategy remains and push handlers are additive',()=>{
 const sw=fs.readFileSync('sw.js','utf8');
 assert.ok(sw.includes("const CACHE='srk-electronic-v5'"));
 assert.ok(sw.includes("self.addEventListener('fetch'"));
});

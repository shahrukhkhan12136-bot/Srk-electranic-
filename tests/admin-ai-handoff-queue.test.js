"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const vm=require("node:vm");
const html=fs.readFileSync(require("node:path").join(__dirname,"..","admin.html"),"utf8");
const start=html.indexOf("let adminAiHandoffQueueBusy=false;");
const end=html.indexOf("async function loadAdminStaff()",start);
assert.ok(start>=0&&end>start,"Admin AI handoff loader must exist");
const source=html.slice(start,end);
function harness({mode="main_admin",rows=[],error=null}={}){
 const elements={
  adminAiHandoffQueue:{innerHTML:"",textContent:""},
  adminAiHandoffQueueStatus:{textContent:""}
 };
 const calls=[];
 const context={
  adminPortalMode:mode,user:{id:"admin"},sb:{rpc:async(...args)=>{calls.push(args);return {data:rows,error};}},
  document:{getElementById:id=>elements[id]||null},
  esc:value=>String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])),
  Date
 };
 vm.createContext(context);
 vm.runInContext(source,context);
 return {context,elements,calls};
}
test("AI handoff queue is Main Admin only and uses the read-only RPC",async()=>{
 const staff=harness({mode:"staff"});
 await staff.context.loadAdminAiHandoffQueue();
 assert.equal(staff.calls.length,0);
 const admin=harness();
 await admin.context.loadAdminAiHandoffQueue();
 assert.equal(admin.calls.length,1);
 assert.equal(admin.calls[0][0],"srk_admin_list_ai_handoff_queue");
 assert.equal(admin.calls[0][1].p_limit,50);
 assert.match(admin.elements.adminAiHandoffQueue.textContent,/कोई Queued या Assigned/);
});
test("AI handoff queue safely escapes every displayed database field",async()=>{
 const ui=harness({rows:[{
  status:"queued<script>",urgency:"high<&",module_key:"customer_support",
  reason_code:"other",summary:"<img src=x onerror=alert(1)>",
  conversation_id:"123e4567-e89b-42d3-a456-426614174000",created_at:"not-a-date"
 }]});
 await ui.context.loadAdminAiHandoffQueue();
 const output=ui.elements.adminAiHandoffQueue.innerHTML;
 assert.match(output,/&lt;script&gt;/);
 assert.match(output,/&lt;img src=x onerror=alert\(1\)&gt;/);
 assert.doesNotMatch(output,/<script>|<img/);
 assert.match(output,/—/);
 assert.match(output,/केवल read-only/);
});
test("AI handoff queue displays a safe fallback when the RPC fails",async()=>{
 const ui=harness({error:new Error("database details")});
 await ui.context.loadAdminAiHandoffQueue();
 assert.match(ui.elements.adminAiHandoffQueue.textContent,/Main Admin अनुमति/);
 assert.doesNotMatch(ui.elements.adminAiHandoffQueue.textContent,/database details/);
});

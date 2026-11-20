"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const vm=require("node:vm");
const path=require("node:path");
const html=fs.readFileSync(path.join(__dirname,"..","admin.html"),"utf8");
const start=html.indexOf("let adminAiHandoffQueueBusy=false,adminAiAssignableStaff=[];");
const end=html.indexOf("async function loadAdminStaff()",start);
assert.ok(start>=0&&end>start,"Admin AI handoff controls must exist");
const source=html.slice(start,end);
function harness({mode="main_admin",rows=[],staff=[],error=null}={}){
 const elements={adminAiHandoffQueue:{innerHTML:"",textContent:""},adminAiHandoffQueueStatus:{textContent:""}};
 const calls=[];
 const context={
  adminPortalMode:mode,user:{id:"admin"},sb:{rpc:async(...args)=>{calls.push(args);return args[0]==="srk_admin_list_ai_handoff_queue"?{data:rows,error}:{data:staff,error};}},
  loadAdminAiAssignableStaff:async()=>{},adminAiAssignableStaff:staff,
  document:{getElementById:id=>elements[id]||null},
  esc:value=>String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])),
  Date, prompt:()=>null, alert:()=>{}
 };
 vm.createContext(context);vm.runInContext(source,context);
 return {context,elements,calls};
}
test("AI handoff queue is Main Admin only and reads the queue before offering assignment",async()=>{
 const staffUi=harness({mode:"staff"});await staffUi.context.loadAdminAiHandoffQueue();assert.equal(staffUi.calls.length,0);
 const admin=harness();await admin.context.loadAdminAiHandoffQueue();
 assert.equal(admin.calls.length,2);assert.equal(admin.calls[0][0],"srk_admin_list_ai_handoff_queue");assert.equal(admin.calls[0][1].p_limit,50);assert.equal(admin.calls[1][0],"srk_admin_list_staff");
 assert.match(admin.elements.adminAiHandoffQueue.textContent,/कोई Queued या Assigned/);
});
test("AI handoff queue safely escapes displayed database fields and offers only active Staff",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=harness({rows:[{handoff_id:id,status:"queued<script>",urgency:"high<&",module_key:"customer_support",reason_code:"other",summary:"<img src=x onerror=alert(1)>",conversation_id:id,created_at:"not-a-date"}],
  staff:[{user_id:id,display_name:"<Admin>",status:"active"},{user_id:"123e4567-e89b-42d3-a456-426614174001",display_name:"Inactive",status:"disabled"}]});
 await ui.context.loadAdminAiHandoffQueue();const output=ui.elements.adminAiHandoffQueue.innerHTML;
 assert.match(output,/&lt;script&gt;/);assert.match(output,/&lt;img src=x onerror=alert\(1\)&gt;/);assert.match(output,/&lt;Admin&gt;/);
 assert.doesNotMatch(output,/<script>|<img/);assert.doesNotMatch(output,/Inactive/);assert.match(output,/Assign करें/);
 assert.match(ui.elements.adminAiHandoffQueueStatus.textContent,/assignment उपलब्ध/);
});
test("AI handoff queue displays a safe fallback when the RPC fails",async()=>{
 const ui=harness({error:new Error("database details")});await ui.context.loadAdminAiHandoffQueue();
 assert.match(ui.elements.adminAiHandoffQueue.textContent,/Main Admin अनुमति/);assert.doesNotMatch(ui.elements.adminAiHandoffQueue.textContent,/database details/);
});
test("Admin HTML inline JavaScript parses and Staff AI handoff controls are present",()=>{
 const scriptStart=html.lastIndexOf("<script>"),scriptEnd=html.lastIndexOf("</script>");
 assert.ok(scriptStart>=0&&scriptEnd>scriptStart,"inline admin script must exist");
 assert.doesNotThrow(()=>new vm.Script(html.slice(scriptStart+8,scriptEnd)));
 assert.match(html,/id="staffAiHandoffCard"/);
 assert.match(html,/function openStaffAiHandoff/);
 assert.match(html,/function replyStaffAiHandoff/);
 assert.match(html,/function resolveStaffAiHandoff/);
 assert.match(html,/function assignAdminAiHandoff/);
});

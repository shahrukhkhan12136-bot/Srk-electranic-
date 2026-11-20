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

function staffHarness({mode="staff",rows=[],messages=[]}={}){
 const elements={
  staffAiHandoffList:{innerHTML:"",textContent:""},
  staffAiHandoffStatus:{textContent:""},
  staffAiHandoffThreadPanel:{classList:{remove(){},add(){}}},
  staffAiHandoffMessages:{innerHTML:"",textContent:""},
  staffAiHandoffThreadTitle:{textContent:""},
  staffAiHandoffThreadStatus:{textContent:""},
  staffAiHandoffReply:{value:""}
 };
 const calls=[];
 const context={
  adminPortalMode:mode,user:{id:"staff"},sb:{auth:{getSession:async()=>({data:{session:{access_token:"staff-jwt"}},error:null})}},
  fetch:async(url,options)=>{const body=JSON.parse(options.body);calls.push({url,options,body});
   const data=body.action==="list"?rows:body.action==="messages"?messages:{state:body.action==="reply"?"replied":"resolved"};
   return {ok:true,json:async()=>({success:true,data})};
  },
  document:{getElementById:id=>elements[id]||null},
  esc:value=>String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])),
  Date,confirm:()=>true
 };
 vm.createContext(context);vm.runInContext(source,context);
 return {context,elements,calls};
}
test("Staff AI handoff list and transcript escape untrusted content and use the logged-in JWT",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=staffHarness({
  rows:[{handoff_id:id,module_key:"customer_support",urgency:"normal",reason_code:"other",summary:"<img src=x onerror=alert(1)>",created_at:"now"}],
  messages:[{sender_kind:"customer<script>",created_at:"now",body:"<svg onload=alert(1)>"}]
 });
 await ui.context.loadStaffAiHandoffs();
 assert.match(ui.elements.staffAiHandoffList.innerHTML,/&lt;img src=x onerror=alert\(1\)&gt;/);
 assert.doesNotMatch(ui.elements.staffAiHandoffList.innerHTML,/<img/);
 assert.equal(ui.calls[0].url,"/api/v1/ai/staff-handoffs");
 assert.equal(ui.calls[0].options.headers.Authorization,"Bearer staff-jwt");
 assert.equal(ui.calls[0].body.action,"list");
 await ui.context.openStaffAiHandoff(id);
 assert.match(ui.elements.staffAiHandoffMessages.innerHTML,/&lt;svg onload=alert\(1\)&gt;/);
 assert.match(ui.elements.staffAiHandoffMessages.innerHTML,/customer&lt;script&gt;/);
 assert.doesNotMatch(ui.elements.staffAiHandoffMessages.innerHTML,/<svg|<script>/);
 assert.equal(ui.calls[1].body.action,"messages");
 assert.equal(ui.calls[1].body.handoff_id,id);
});
test("Staff AI handoff controls do not load a queue for non-Staff roles",async()=>{
 const ui=staffHarness({mode:"main_admin"});
 await ui.context.loadStaffAiHandoffs();
 assert.equal(ui.calls.length,0);
 assert.equal(ui.elements.staffAiHandoffList.innerHTML,"");
});

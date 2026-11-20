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

function staffHarness({mode="staff",rows=[],messages=[],confirmResult=true,fetchFailure=null}={}){
 const elements={
  staffAiHandoffList:{innerHTML:"",textContent:""},
  staffAiHandoffStatus:{textContent:""},
  staffAiHandoffThreadPanel:{classList:{hidden:true,remove(){this.hidden=false;},add(){this.hidden=true;}}},
  staffAiHandoffMessages:{innerHTML:"",textContent:""},
  staffAiHandoffThreadTitle:{textContent:""},
  staffAiHandoffThreadStatus:{textContent:""},
  staffAiHandoffReply:{value:""}
 };
 const calls=[];
 const context={
  adminPortalMode:mode,user:{id:"staff"},sb:{auth:{getSession:async()=>({data:{session:{access_token:"staff-jwt"}},error:null})}},
  fetch:async(url,options)=>{const body=JSON.parse(options.body);calls.push({url,options,body});if(fetchFailure)throw fetchFailure;
   const data=body.action==="list"?rows:body.action==="messages"?messages:{state:body.action==="reply"?"replied":"resolved"};
   return {ok:true,json:async()=>({success:true,data})};
  },
  document:{getElementById:id=>elements[id]||null},
  esc:value=>String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])),
  Date,confirm:()=>confirmResult
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

test("Staff can reply to and resolve an assigned AI handoff through authenticated actions",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=staffHarness({messages:[{sender_kind:"staff",body:"We are reviewing your request.",created_at:"now"}]});
 await ui.context.openStaffAiHandoff(id);
 ui.elements.staffAiHandoffReply.value="I have reviewed your request.";
 await ui.context.replyStaffAiHandoff();
 assert.equal(ui.calls[0].body.action,"messages");
 assert.equal(ui.calls[1].body.action,"reply");
 assert.equal(ui.calls[1].body.handoff_id,id);
 assert.equal(ui.calls[1].body.body,"I have reviewed your request.");
 assert.equal(ui.calls[1].options.headers.Authorization,"Bearer staff-jwt");
 assert.equal(ui.elements.staffAiHandoffReply.value,"");
 assert.equal(ui.calls[2].body.action,"messages","successful reply refreshes the transcript");
 await ui.context.resolveStaffAiHandoff();
 assert.equal(ui.calls[3].body.action,"resolve");
 assert.equal(ui.calls[3].body.handoff_id,id);
 assert.equal(ui.calls[3].options.headers.Authorization,"Bearer staff-jwt");
 assert.equal(ui.calls[4].body.action,"list","successful resolve refreshes the assigned queue");
});

test("Staff reply rejects blank or oversized text without making an API request",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=staffHarness();
 await ui.context.openStaffAiHandoff(id);
 const initialCalls=ui.calls.length;
 ui.elements.staffAiHandoffReply.value="   ";
 await ui.context.replyStaffAiHandoff();
 assert.equal(ui.calls.length,initialCalls);
 assert.match(ui.elements.staffAiHandoffThreadStatus.textContent,/1 से 4000 अक्षरों/);
 ui.elements.staffAiHandoffReply.value="x".repeat(4001);
 await ui.context.replyStaffAiHandoff();
 assert.equal(ui.calls.length,initialCalls);
 assert.equal(ui.elements.staffAiHandoffReply.value,"x".repeat(4001));
});
test("Staff reply API failure preserves the draft and reports a safe error",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=staffHarness({fetchFailure:new Error("network unavailable")});
 await ui.context.openStaffAiHandoff(id);
 ui.elements.staffAiHandoffReply.value="Please review this case.";
 await ui.context.replyStaffAiHandoff();
 assert.equal(ui.elements.staffAiHandoffReply.value,"Please review this case.");
 assert.match(ui.elements.staffAiHandoffThreadStatus.textContent,/network unavailable/);
 assert.equal(ui.calls.at(-1).body.action,"reply");
});
test("Staff resolve cancellation does not call the API or change the selected thread",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=staffHarness({confirmResult:false});
 await ui.context.openStaffAiHandoff(id);
 const initialCalls=ui.calls.length;
 await ui.context.resolveStaffAiHandoff();
 assert.equal(ui.calls.length,initialCalls);
 assert.equal(vm.runInContext("staffAiHandoffSelectedId",ui.context),id);
 assert.equal(ui.elements.staffAiHandoffThreadPanel.classList.hidden,false);
});
test("Staff resolve API failure keeps the selected handoff open and reports the error",async()=>{
 const id="123e4567-e89b-42d3-a456-426614174000";
 const ui=staffHarness({fetchFailure:new Error("resolve request failed")});
 await ui.context.openStaffAiHandoff(id);
 await ui.context.resolveStaffAiHandoff();
 assert.equal(vm.runInContext("staffAiHandoffSelectedId",ui.context),id);
 assert.match(ui.elements.staffAiHandoffThreadStatus.textContent,/resolve request failed/);
 assert.equal(ui.calls.at(-1).body.action,"resolve");
});

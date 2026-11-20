"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const file=path.join(__dirname,"..","supabase","migrations","20261118270000_ai_handoff_staff_workflow.sql");
const sql=fs.readFileSync(file,"utf8");

test("Main Admin assignment requires an active Staff member with read and reply permissions",()=>{
  assert.ok(sql.includes("v_actor IS NULL OR NOT public.is_srk_admin()"));
  assert.match(sql,/s\.status='active'/i);
  assert.match(sql,/ai\.handoff\.read/);
  assert.match(sql,/ai\.handoff\.reply/);
  assert.match(sql,/length\(btrim\(coalesce\(p_reason,''\)\)\) NOT BETWEEN 5 AND 500/i);
  assert.match(sql,/FOR UPDATE/i);
  assert.match(sql,/staff\.ai_handoff\.assigned/);
});

test("Staff queue and transcript reads are restricted to the signed-in assigned Staff member",()=>{
  assert.match(sql,/public\.srk_has_admin_permission\('ai\.handoff\.read'\)/);
  assert.match(sql,/q\.assigned_to=auth\.uid\(\) AND q\.status='assigned'/);
  assert.match(sql,/p_limit NOT BETWEEN 1 AND 200/);
  assert.match(sql,/AI_HANDOFF_NOT_ASSIGNED_TO_STAFF/);
});

test("Staff replies append human_agent messages and metadata-only audit events",()=>{
  assert.match(sql,/public\.srk_has_admin_permission\('ai\.handoff\.reply'\)/);
  assert.match(sql,/q\.assigned_to=v_actor AND q\.status='assigned'/);
  assert.match(sql,/sender_kind,sender_user_id,body\)[\s\S]*'human_agent',v_actor,p_body/i);
  assert.match(sql,/'message_recorded','completed'/);
  assert.match(sql,/length\(btrim\(p_body\)\) NOT BETWEEN 1 AND 4000/);
});

test("Staff resolution requires assigned ownership and closes queue and conversation with audit",()=>{
  assert.match(sql,/public\.srk_has_admin_permission\('ai\.handoff\.resolve'\)/);
  assert.match(sql,/SET status='resolved',resolved_at=clock_timestamp\(\)/);
  assert.match(sql,/SET status='closed',closed_at=clock_timestamp\(\)/);
  assert.match(sql,/'handoff_resolved','completed'/);
});

test("all workflow RPCs are SECURITY DEFINER with empty search_path and authenticated-only execution",()=>{
  const signatures=["srk_admin_assign_ai_handoff","srk_staff_list_assigned_ai_handoffs","srk_staff_list_assigned_ai_handoff_messages","srk_staff_reply_ai_handoff","srk_staff_resolve_ai_handoff"];
  for(const signature of signatures){
    assert.ok(sql.includes("CREATE OR REPLACE FUNCTION public."+signature+"("));
  }
  assert.equal((sql.match(/SECURITY DEFINER/g)||[]).length,5);
  assert.equal((sql.match(/SET search_path=''/g)||[]).length,5);
  assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.srk_staff_reply_ai_handoff\(uuid,text\)\s+TO authenticated/i);
  assert.match(sql,/REVOKE ALL ON FUNCTION public\.srk_staff_resolve_ai_handoff\(uuid\)\s+FROM PUBLIC,anon/i);
});

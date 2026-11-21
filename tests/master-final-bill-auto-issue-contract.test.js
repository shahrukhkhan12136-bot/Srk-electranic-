const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const sql=fs.readFileSync(path.resolve(__dirname,'../supabase/migrations/20261121220000_master_final_bill_auto_issue.sql'),'utf8');

test('Master final bill is retried automatically after customer-confirmed completion',()=>{
 assert.match(sql,/srk_master_final_bill_after_customer_completion/);
 assert.match(sql,/completion_approval_status<>'approved'/);
 assert.match(sql,/customer_completed_at IS NULL/);
});

test('Master final bill waits for every workday, labour ledger and customer material decision',()=>{
 assert.match(sql,/ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED/);
 assert.match(sql,/TECHNICIAN_LABOUR_LEDGER_REQUIRED/);
 assert.match(sql,/CUSTOMER_MATERIAL_DECISION_PENDING/);
});

test('Master final bill is retried when material decision or final daily labour ledger arrives',()=>{
 assert.match(sql,/srk_master_final_bill_after_material_decision/);
 assert.match(sql,/srk_master_final_bill_after_labour_ledger/);
 assert.match(sql,/srk_try_build_master_final_bill_from_trigger/);
});

test('trigger path cannot expose the service-role bill builder as an authenticated RPC',()=>{
 assert.match(sql,/pg_trigger_depth\(\)=0/);
 assert.match(sql,/REVOKE ALL ON FUNCTION public\.srk_try_build_master_final_bill_from_trigger\(\) FROM PUBLIC,anon,authenticated/);
});

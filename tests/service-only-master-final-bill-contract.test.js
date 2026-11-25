const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const migration=fs.readFileSync('supabase/migrations/20261125163000_service_only_master_final_bill.sql','utf8');
test('New Master final bill total is derived only from service ledger',()=>{
 assert.match(migration,/sum\(total_labour_paise\)/);
 assert.match(migration,/v_commission:=round\(v_labour\*v_rate\/100\)::bigint/);
 assert.match(migration,/'service_amount_paise'/);
 assert.match(migration,/'technician_net_earning_paise'/);
});
test('Obsolete request entry points are disabled and new payables are service-only',()=>{
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_technician_submit_booking_materials/);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_customer_decide_booking_materials/);
 assert.match(migration,/NEW\.materials_reimbursement_paise:=0/);
 assert.match(migration,/NEW\.total_payable_paise:=NEW\.labour_payable_paise/);
});

test('Automatic final-bill trigger can invoke the service-only builder safely',()=>{
 assert.match(migration,/auth\.role\(\).*pg_trigger_depth\(\)=0/);
 assert.match(migration,/v_bill\.materials_amount_paise<>0/);
 assert.match(migration,/v_bill\.technician_material_reimbursement_paise<>0/);
});
test('Service-only payable guard also protects later updates',()=>{
 assert.match(migration,/BEFORE INSERT OR UPDATE ON public\.srk_master_technician_payables/);
});

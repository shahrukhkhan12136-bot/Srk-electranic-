const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261121260000_master_cash_commission_due_and_online_offset.sql'), 'utf8');

test('Technician cash collection records 15 percent company commission as a separate due', () => {
  assert.match(migration, /v_method='cash'/);
  assert.match(migration, /cash_commission_due/);
  assert.match(migration, /commission_due_paise/);
  assert.match(migration, /payout_status='cash_collected'/);
  assert.match(migration, /NEW\.company_commission_paise/);
});

test('Future company-collected online/manual UPI or bank earnings recover older cash commission first', () => {
  assert.match(migration, /online_commission_recovered/);
  assert.match(migration, /ORDER BY created_at,id\s+FOR UPDATE/);
  assert.match(migration, /v_take:=least\(v_left,v_due\)/);
  assert.match(migration, /commission_recovery_paise=commission_recovery_paise\+v_take/);
});

test('Cash commission and recovery have an append-only audit trail', () => {
  assert.match(migration, /srk_master_technician_commission_events/);
  assert.match(migration, /srk_master_technician_commission_events_append_only/);
  assert.match(migration, /MASTER_COMMISSION_EVENTS_ARE_APPEND_ONLY/);
});

test('Wallet separates cash collected, outstanding commission, recovered commission and payout balance', () => {
  assert.match(migration, /'cash_collected_paise'/);
  assert.match(migration, /'commission_due_paise'/);
  assert.match(migration, /'commission_recovered_paise'/);
  assert.match(migration, /'offset_paise'/);
  assert.match(migration, /'commission_dues'/);
});

test('Only net payable balance is available for manual Admin payout', () => {
  assert.match(migration, /total_payable_paise = labour_payable_paise \+ materials_reimbursement_paise - commission_recovery_paise/);
  assert.match(migration, /payout_status IN \('pending','requested','paid','blocked','refunded','cash_collected','offset'\)/);
});

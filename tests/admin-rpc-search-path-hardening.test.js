const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (name) => fs.readFileSync(path.join(root, 'supabase/migrations', name), 'utf8');

test('Staff permission helper is volatile and locks the live registry and session', () => {
  const sql = read('20261116100000_fix_staff_permission_helper_volatility.sql');
  assert.match(sql, /create or replace function public\.srk_has_admin_permission\(p_permission_key text\)[\s\S]*?\bvolatile\b[\s\S]*?security definer[\s\S]*?set search_path = ''/i);
  assert.match(sql, /public\.srk_admin_staff[\s\S]*?for share/i);
  assert.match(sql, /public\.srk_admin_staff_sessions[\s\S]*?for share/i);
  assert.match(sql, /auth\.sessions auth_s[\s\S]*?auth_s\.id = v_session_id/i);
  assert.match(sql, /revoke all on function public\.srk_has_admin_permission\(text\) from public, anon/i);
});

test('Legacy financial, wallet, receipt, call-contact and application-review RPCs pin empty search_path', () => {
  const migrations = [
    ['20261116110000_pin_legacy_financial_read_rpc_search_paths.sql', [
      'srk_admin_commission_report', 'srk_get_my_wallet_summary', 'srk_admin_wallet_overview'
    ]],
    ['20261116120000_pin_customer_call_contact_rpc_search_paths.sql', [
      'srk_get_customer_call_contacts_impl', 'srk_get_customer_call_contacts'
    ]],
    ['20261116130000_pin_wallet_and_receipt_rpc_search_paths.sql', [
      'srk_get_my_wallet_summary', 'srk_admin_wallet_overview', 'srk_get_my_earnings', 'srk_customer_get_payment_receipt'
    ]],
    ['20261116140000_pin_electrician_offer_details_search_path.sql', [
      'srk_get_my_offer_details'
    ]],
    ['20261116150000_pin_admin_application_review_search_path.sql', [
      'srk_admin_review_application'
    ]]
  ];
  for (const [file, functions] of migrations) {
    const sql = read(file);
    for (const fn of functions) {
      assert.match(sql, new RegExp('alter function (?:private|public)\\.' + fn + '\\('));
    }
    assert.equal((sql.match(/set search_path = '';/g) || []).length, functions.length, file);
  }
});

test('Retired quotation RPC hardening remains safe on fresh migration replay', () => {
  const sql = read('20261116160000_pin_quote_and_work_status_rpc_search_paths.sql');
  for (const fn of [
    'srk_submit_booking_quote',
    'srk_customer_respond_booking_quote',
    'srk_update_booking_work_status'
  ]) {
    assert.match(sql, new RegExp('alter function if exists public\\.' + fn + '\\('));
  }
  assert.equal((sql.match(/set search_path = '';/g) || []).length, 3);
  assert.match(sql, /IF EXISTS keeps fresh replay safe/i);
});

'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const migration = fs.readFileSync('supabase/migrations/20261125102033_add_worker_share_only_rate_card_and_admin_pricing_controls.sql', 'utf8');
const technician = fs.readFileSync('apps/electrician_app/lib/main.dart', 'utf8');
const card = fs.readFileSync('apps/electrician_app/lib/worker_rate_card.dart', 'utf8');
const admin = fs.readFileSync('admin.html', 'utf8');

test('Worker rate-card RPC returns all six categories and only the logged-in role share', () => {
  assert.match(migration, /srk_worker_get_my_rate_card/);
  assert.match(migration, /where wp\.user_id=auth\.uid\(\)/);
  for (const category of ['electrician','plumber','painter','ac_fridge_technician','motor_pump_technician','cooler_technician']) assert.ok(migration.includes("'" + category + "'"));
  assert.match(migration, /round\(t\.fixed_price\*v_worker_share\/100,2\)/);
  assert.match(migration, /round\(r\.technician_rate\*v_worker_share\/100,2\)/);
  assert.match(migration, /case when v_worker_type='helper' then r\.helper_rate else r\.technician_rate end/);
  assert.doesNotMatch(migration.slice(migration.indexOf('create or replace function public.srk_worker_get_my_rate_card'), migration.indexOf('create or replace function public.srk_admin_list_service_pricing_rules')), /'company_rate'|'commission_amount'|'commission_rate'/);
});

test('Technician app loads and renders the six-category worker-only rate card', () => {
  assert.match(technician, /srk_worker_get_my_rate_card/);
  assert.match(technician, /WorkerRateCard\(categories: rateCardCategories\)/);
  assert.match(card, /मेरी रेट सूची/);
  assert.match(card, /worker_rate/);
  assert.doesNotMatch(card, /commission|कमीशन|कंपनी/i);
});

test('Admin panel can edit service rates and the company/worker split with reasoned confirmation', () => {
  assert.match(admin, /adminPricingControlCard/);
  assert.match(admin, /srk_admin_get_revenue_split/);
  assert.match(admin, /srk_admin_update_revenue_split/);
  assert.match(admin, /srk_admin_list_service_rates/);
  assert.match(admin, /srk_admin_list_service_pricing_rules/);
  assert.match(admin, /srk_admin_update_service_rate/);
  assert.match(admin, /srk_admin_update_service_pricing_rate/);
  assert.match(admin, /reason\.length<10/);
});

test('Admin revenue split requires exactly 100 percent and changes apply to new bookings', () => {
  assert.match(migration, /round\(p_company_rate\+p_worker_rate,2\)<>100/);
  assert.match(migration, /effective_for/);
  assert.match(migration, /new bookings only/);
});

test('Revenue split changes are Main Admin-only and audit both percentages', () => {
  const controls = fs.readFileSync('supabase/migrations/20261125102524_require_main_admin_for_revenue_split_and_audit_worker_share.sql', 'utf8');
  assert.match(controls, /not public\.is_srk_admin\(\)/);
  assert.match(controls, /'worker_share_rate'/);
  assert.match(controls, /'previous_worker_rate'/);
  assert.match(controls, /'current_worker_rate'/);
});

test('Admin rate editor uses a labour-only RPC without exposing non-labour fields', () => {
  const wrapper = fs.readFileSync('supabase/migrations/20261125102825_add_clean_admin_service_pricing_update_rpc.sql', 'utf8');
  assert.match(admin, /srk_admin_update_service_pricing_rate/);
  assert.doesNotMatch(admin, /materials|winding/i);
  assert.match(wrapper, /false,false,p_pricing_note/);
});

test('Revenue split updates both audited system settings without duplicate manual audit inserts', () => {
  const audit = fs.readFileSync('supabase/migrations/20261125103048_record_worker_share_setting_with_commission_audit_triggers.sql', 'utf8');
  assert.match(audit, /not public\.is_srk_admin\(\)/);
  assert.match(audit, /values\('worker_share_rate',to_jsonb\(v_new_worker\)/);
  assert.doesNotMatch(audit, /insert into public\.srk_admin_audit_events/i);
});

test('Worker rate-card function uses a stable time reference for active rates', () => {
  const stable = fs.readFileSync('supabase/migrations/20261125103551_use_stable_time_reference_for_worker_rate_card.sql', 'utf8');
  assert.match(stable, /language plpgsql\s+stable/);
  assert.match(stable, /r\.effective_from<=now\(\)/);
  assert.doesNotMatch(stable, /clock_timestamp\(\)/);
});

test('Worker financial details are booking-scoped to the authenticated assigned worker', () => {
  const finance = fs.readFileSync('supabase/migrations/20261125110500_worker_bill_details_and_payout_request_rpcs.sql', 'utf8');
  assert.match(finance, /srk_worker_get_my_booking_financial_details/);
  assert.match(finance, /where wp\.user_id=auth\.uid\(\)/);
  assert.match(finance, /e\.booking_id=p_booking_id and e\.worker_id=v_worker/);
  assert.match(finance, /company_commission_total/);
  assert.match(finance, /customer_paid_amount/);
  assert.match(finance, /my_wallet_credit/);
  assert.match(finance, /cash_commission_outstanding/);
  assert.match(finance, /lower\(i\.item_type\)<>'material'/);
  assert.match(finance, /revoke all on function public\.srk_worker_get_my_booking_financial_details/);
});

test('Technician app displays full bill split and lets worker request the available wallet payout', () => {
  assert.match(technician, /srk_worker_get_my_booking_financial_details/);
  assert.match(technician, /पूरा बिल और कमाई/);
  assert.match(technician, /कंपनी प्रतिशत/);
  assert.match(technician, /ग्राहक ने वास्तव में दिया/);
  assert.match(technician, /srk_worker_request_payout/);
  assert.match(technician, /srk_worker_get_my_payout_requests/);
  assert.match(technician, /UTR:/);
});

test('Payout history RPC is limited to the authenticated worker and Admin payout workflow requires transfer evidence and reference', () => {
  const finance = fs.readFileSync('supabase/migrations/20261125110500_worker_bill_details_and_payout_request_rpcs.sql', 'utf8');
  assert.match(finance, /srk_worker_get_my_payout_requests/);
  assert.match(finance, /where p\.worker_id=v_worker/);
  assert.match(admin, /srk_admin_mark_worker_payout_paid/);
  assert.match(admin, /UTR|payment_reference/i);
  assert.match(admin, /srk_worker_payout_evidence/);
});

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
  assert.match(migration, /'electrician','plumber','painter','ac_fridge_technician','motor_pump_technician','cooler_technician'/);
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
  assert.match(admin, /srk_admin_version_service_pricing_rule/);
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

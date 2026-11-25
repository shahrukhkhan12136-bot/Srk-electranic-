'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const files = {
  customer: fs.readFileSync('apps/customer_app/lib/main.dart', 'utf8'),
  technician: fs.readFileSync('apps/electrician_app/lib/main.dart', 'utf8'),
  catalogue: fs.readFileSync('packages/srk_mobile_core/lib/srk_service_catalog.dart', 'utf8'),
  customerBill: fs.readFileSync('apps/customer_app/lib/customer_confirmation/srk_customer_confirmation_preview.dart', 'utf8'),
  sharedBill: fs.readFileSync('packages/srk_mobile_core/lib/srk_work_confirmation_contract.dart', 'utf8'),
  admin: fs.readFileSync('admin.html', 'utf8'),
  migration: fs.readFileSync('supabase/migrations/20261125112828_labour_only_customer_billing.sql', 'utf8'),
};

test('Customer, Technician, catalogue and Admin screens expose labour-only billing', () => {
  for (const [name, source] of Object.entries(files).filter(([name]) => name !== 'migration')) {
    assert.doesNotMatch(
      source,
      /materials_amount|approved_materials_amount|p_materials_amount|materialsController|सामान\s*\/\s*पार्ट्स|पार्ट्स अलग|सामग्री|Materials|materials_gross_paise/i,
      name + ' must not expose non-labour billing fields',
    );
  }
});

test('Technician quote flow uses the labour-only server RPC', () => {
  assert.match(files.technician, /srk_submit_labour_quote/);
  assert.doesNotMatch(files.technician, /srk_submit_booking_quote|p_materials_amount/);
});

test('Customer and shared final bill contracts accept only a labour-equal total', () => {
  assert.match(files.customerBill, /labourAmountPaise == totalAmountPaise/);
  assert.match(files.sharedBill, /labourAmountPaise == totalAmountPaise/);
  assert.doesNotMatch(files.customerBill + files.sharedBill, /approved_materials_amount_paise|other_charges_amount_paise/);
});

test('Database migration creates labour-only quotes and final bill totals', () => {
  assert.match(files.migration, /create or replace function public\.srk_submit_labour_quote/);
  assert.match(files.migration, /new\.total_amount:=round\(new\.service_amount\+coalesce\(new\.cancellation_fee_amount,0\)/);
  assert.match(files.migration, /grant execute on function public\.srk_submit_labour_quote/);
});

test('Technician app uses the shared Worker profile, assignment, contact and wallet APIs', () => {
  assert.match(files.technician, /from\('srk_worker_profiles'\)/);
  assert.match(files.technician, /srk_worker_get_my_assignments/);
  assert.match(files.technician, /srk_worker_respond_assignment/);
  assert.match(files.technician, /srk_worker_get_my_booking_customer_contacts/);
  assert.match(files.technician, /srk_worker_get_my_earnings/);
  assert.match(files.technician, /srk_worker_get_my_wallet_summary/);
  assert.doesNotMatch(files.technician, /from\('electrician_profiles'\)|from\('job_offers'\)|srk_respond_to_offer|srk_get_my_assigned_booking_quote_details/);
});

test('Labour quote authorization is bound to an approved shared Worker assignment', () => {
  assert.match(files.migration, /from public\.srk_worker_profiles/);
  assert.match(files.migration, /from public\.srk_booking_workers/);
  assert.match(files.migration, /assignment_status in \('accepted','assigned','working','paused'\)/);
  assert.doesNotMatch(files.migration, /from public\.electrician_profiles|assigned_electrician_id/);
});

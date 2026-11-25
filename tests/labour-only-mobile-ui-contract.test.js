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
  migration: fs.readFileSync('supabase/migrations/20261125130000_labour_only_customer_billing.sql', 'utf8'),
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
  assert.match(files.migration, /new\.total_amount:=round\(new\.service_amount,2\)/);
  assert.match(files.migration, /grant execute on function public\.srk_submit_labour_quote/);
});

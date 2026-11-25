'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const customer = fs.readFileSync('apps/customer_app/lib/main.dart', 'utf8');
const worker = fs.readFileSync('apps/electrician_app/lib/main.dart', 'utf8');
const admin = fs.readFileSync('admin.html', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261125120555_allow_worker_applicants_to_request_account_deletion.sql', 'utf8');

test('Customer and Worker apps submit account deletion requests without deleting the account directly', () => {
  assert.match(customer, /srk_request_account_deletion/);
  assert.match(customer, /Account अभी delete नहीं हुआ है/);
  assert.match(worker, /srk_request_account_deletion/);
  assert.match(worker, /Account अभी delete नहीं हुआ है/);
});

test('Main Admin can review account deletion requests with reason and retention explanation', () => {
  assert.match(admin, /adminAccountDeletionCard/);
  assert.match(admin, /srk_admin_list_account_deletion_requests/);
  assert.match(admin, /srk_admin_review_account_deletion/);
  assert.match(admin, /retention/);
  assert.match(admin, /Account अपने-आप delete नहीं होगा/);
});

test('Worker applicants can request account deletion before Admin approval', () => {
  assert.match(migration, /from public\.srk_worker_applications/);
  assert.match(migration, /account_role,request_reason/);
});

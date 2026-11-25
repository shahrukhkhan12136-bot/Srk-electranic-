'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');
const payout = source.slice(source.indexOf('async function loadWorkerPayoutRequests'), source.indexOf('async function loadMasterPayouts'));

test('Admin web payout queue uses the live shared Worker payout contract', () => {
  assert.ok(payout.includes("from('srk_worker_payout_requests')"));
  assert.ok(payout.includes("srk_admin_get_worker_full_profile"));
  assert.ok(payout.includes("srk_admin_review_worker_payout"));
  assert.ok(payout.includes("srk_admin_review_worker_payout_details"));
  assert.ok(payout.includes("srk_admin_attach_worker_payout_evidence"));
  assert.ok(payout.includes("srk_admin_mark_worker_payout_paid"));
  assert.ok(payout.includes("srk-worker-payout-evidence"));
  assert.ok(payout.includes("p_payment_reference:ref"));
  assert.ok(!payout.includes("srk_admin_list_master_payout_requests"));
  assert.ok(!payout.includes("srk_admin_review_master_payout_request"));
});

test('Admin payout UI fails closed without verified UPI and transfer evidence', () => {
  assert.ok(payout.includes("w.payout_details_change_status==='approved'&&w.upi_id"));
  assert.ok(payout.includes("!['upi','phonepe'].includes(method)"));
  assert.ok(payout.includes("file.size>10*1024*1024"));
  assert.ok(payout.includes("srk_admin_attach_worker_payout_evidence"));
  assert.ok(payout.includes("srk_admin_mark_worker_payout_paid"));
});

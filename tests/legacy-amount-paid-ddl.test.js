const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migrationPath = path.join(root, 'supabase/migrations/20261116200000_restore_service_bookings_amount_paid.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');

test('legacy payment amount DDL is restored idempotently for service bookings', () => {
  assert.match(migration, /ALTER TABLE public\.service_bookings\s+ADD COLUMN IF NOT EXISTS amount_paid numeric\(12,2\)/i);
});

test('legacy payment amount rejects negative new or updated values without blocking legacy-row validation', () => {
  assert.match(migration, /amount_paid IS NULL OR amount_paid >= 0/i);
  assert.match(migration, /ADD CONSTRAINT service_bookings_amount_paid_nonnegative_check[\s\S]*?NOT VALID/i);
});

test('migration guards the named check constraint against duplicate application', () => {
  assert.match(migration, /IF NOT EXISTS\s*\([\s\S]*?conname = 'service_bookings_amount_paid_nonnegative_check'[\s\S]*?\)/i);
});

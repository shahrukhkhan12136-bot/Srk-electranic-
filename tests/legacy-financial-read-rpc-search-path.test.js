const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115210001_harden_legacy_financial_read_rpc_search_paths.sql'), 'utf8');
const contract = fs.readFileSync(path.join(root, 'supabase/tests/database/legacy_financial_read_rpc_search_path.test.sql'), 'utf8');

test('legacy financial SECURITY DEFINER read RPCs pin trusted search_path', () => {
  for (const fn of [
    'srk_admin_commission_report',
    'srk_get_my_wallet_summary',
    'srk_admin_wallet_overview'
  ]) {
    assert.match(migration, new RegExp('ALTER FUNCTION public\\.' + fn + '\\(\\)'));
    assert.ok(migration.includes('SET search_path = pg_catalog, public, auth, pg_temp;'));
  }
  assert.equal((migration.match(/SET search_path = pg_catalog, public, auth, pg_temp;/g) || []).length, 3);
});

test('pgTAP contract checks SECURITY DEFINER configuration and anon denial', () => {
  assert.ok(contract.includes('select plan(6)'));
  assert.ok(contract.includes('SECURITY DEFINER'));
  assert.ok(contract.includes('trusted search_path'));
  assert.ok(contract.includes("not has_function_privilege('anon'"));
});

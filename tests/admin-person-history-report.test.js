const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261125150000_admin_person_history_and_category_skill_counts.sql'), 'utf8');

test('Admin exposes six-category skill counts and loads them after login', () => {
  assert.match(admin, /adminCategorySkillCountsCard/);
  assert.match(admin, /srk_admin_get_category_skill_counts/);
  assert.match(admin, /async function loadAll\(\)\{await loadAdminCategorySkillCounts\(\);/);
  for (const status of ['pending_skill_holders', 'approved_skill_holders', 'active_skill_holders', 'currently_working']) {
    assert.match(migration, new RegExp(status));
  }
});

test('Admin person history supports all four permanent ID types and date windows', () => {
  assert.match(admin, /adminUniversalPersonHistoryCard/);
  assert.match(admin, /adminPersonHistoryId/);
  assert.match(admin, /setAdminHistoryDays\(1\)/);
  assert.match(admin, /setAdminHistoryDays\(2\)/);
  assert.match(admin, /setAdminHistoryDays\(10\)/);
  assert.match(admin, /adminPersonHistoryPdfButton/);
  assert.match(admin, /srk_admin_get_person_history/);
  assert.match(migration, /worker_code/);
  assert.match(migration, /customer_code/);
  assert.match(migration, /employee_code/);
  assert.match(migration, /'helper'/);
  assert.match(migration, /'technician'/);
});

test('Sensitive history access is Main-Admin checked and audited in a private schema', () => {
  assert.match(migration, /srk_private\.get_admin_person_history/);
  assert.match(migration, /auth\.uid\(\) is null or not public\.is_srk_admin\(\)/);
  assert.match(migration, /admin_person_history_access_log/);
  assert.match(migration, /alter table srk_private\.admin_person_history_access_log enable row level security/i);
  assert.match(migration, /security invoker/i);
  assert.match(migration, /revoke all on function public\.srk_admin_get_person_history/i);
});

test('Admin inline JavaScript parses without executing browser actions', () => {
  const inlineScripts = [...admin.matchAll(/<script>([\s\S]*?)<\/script>/gi)];
  assert.ok(inlineScripts.length > 0, 'expected an inline Admin script');
  assert.doesNotThrow(() => new Function(inlineScripts.at(-1)[1]));
});

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const directory = path.join(__dirname, '..', 'supabase', 'migrations');
const approvedLegacyCollision = new Map([
  ['20261109', [
    '20261109_allow_quote_approval_booking_states.sql',
    '20261109_electrician_inspection_quotes_and_service_only_commission.sql'
  ]]
]);

test('Supabase migration versions are unique except explicitly tracked legacy collisions', () => {
  const files = fs.readdirSync(directory).filter(name => name.endsWith('.sql')).sort();
  const byVersion = new Map();

  for (const file of files) {
    const version = file.split('_', 1)[0];
    assert.match(version, /^\d{8}(?:\d{6})?$/, file + ' has an invalid migration version prefix');
    const current = byVersion.get(version) || [];
    current.push(file);
    byVersion.set(version, current);
  }

  const collisions = new Map([...byVersion].filter(([, names]) => names.length > 1));
  assert.deepEqual(
    Object.fromEntries(collisions),
    Object.fromEntries(approvedLegacyCollision),
    'new duplicate migration versions are blocked; the 20261109 legacy pair remains explicitly flagged for production-history reconciliation'
  );
});

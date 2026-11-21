const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const directory = path.join(__dirname, '..', 'supabase', 'tests', 'database');
const assertionPattern = /\bselect\s+(?:ok|is|isnt|has_table|has_column|has_function|has_trigger|has_index|hasnt_table|hasnt_column)\s*\(/gi;

test('every database pgTAP contract declares a plan matching its assertion count', () => {
  const files = fs.readdirSync(directory).filter(name => name.endsWith('.test.sql')).sort();
  assert.ok(files.length > 0, 'database pgTAP test files exist');

  const mismatches = [];
  for (const file of files) {
    const sql = fs.readFileSync(path.join(directory, file), 'utf8');
    const plans = [...sql.matchAll(/\bselect\s+plan\s*\(\s*(\d+)\s*\)/gi)].map(match => Number(match[1]));
    const assertions = [...sql.matchAll(assertionPattern)].length;
    if (plans.length !== 1 || plans[0] !== assertions) {
      mismatches.push({ file, plans, assertions });
    }
  }

  assert.deepEqual(mismatches, [], 'pgTAP plan counts must match assertion calls');
});

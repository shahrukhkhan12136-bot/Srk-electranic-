const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const migration = fs.readFileSync('supabase/migrations/20261121150000_master_service_rate_catalogue.sql', 'utf8');

test('Motor winding services remain historical but are inactive in the Master catalogue', () => {
  assert.match(migration, /UPDATE public\.srk_service_skills SET is_active=false[\s\S]*?skill_code IN \('motor_winding','cooler_motor_winding'\)/);
  assert.match(migration, /UPDATE public\.srk_service_offerings SET is_active=false[\s\S]*?service_code IN \('motor_winding','cooler_motor_winding'\)/);
});

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('welcome screen routes all roles and includes the founder portrait asset', () => {
  const welcome = fs.readFileSync(path.join(root, 'welcome.html'), 'utf8');
  const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.match(index, /location\.replace\('\/welcome\.html'\)/);
  assert.match(welcome, /<main id="welcome"/);
  assert.match(welcome, /href="\/customer-login\.html"/);
  assert.match(welcome, /href="\/electrician\.html"/);
  assert.match(welcome, /href="\/admin\.html"/);
  assert.match(welcome, /class="founder-photo"/);
  assert.match(welcome, /src="\/assets\/srk-founder\.jpg"/);
  assert.ok(fs.existsSync(path.join(root, 'assets', 'srk-founder.jpg')), 'founder portrait asset must exist');
  assert.match(welcome, /alt="SRK ELECTRONIC के Founder का पोर्ट्रेट"/);
  assert.match(welcome, /prefers-reduced-motion:reduce/);
});

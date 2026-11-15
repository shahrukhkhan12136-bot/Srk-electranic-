const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('welcome screen routes all roles and displays the approved authentic garden Founder portrait', () => {
  const welcome = fs.readFileSync(path.join(root, 'welcome.html'), 'utf8');
  const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.ok(index.includes("location.replace('/welcome.html')"));
  assert.ok(welcome.includes('<main id="welcome"'));
  assert.ok(welcome.includes('href="/customer-login.html"'));
  assert.ok(welcome.includes('href="/electrician.html"'));
  assert.ok(welcome.includes('href="/admin.html"'));
  assert.ok(welcome.includes('class="founder-photo-pending"'));
  assert.ok(welcome.includes('Founder की स्वीकृत वास्तविक फोटो के लिए सुरक्षित स्थान'));
  assert.ok(welcome.includes('FOUNDER &amp; DIRECTOR'));
  assert.ok(welcome.includes('Smart Service... Better Life...'));
  assert.ok(welcome.includes('/assets/srk-founder.jpg'));
  assert.match(welcome, /prefers-reduced-motion:reduce/);
});

test('installed PWA opens the welcome screen and offline cache contains its entry route', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.webmanifest'), 'utf8'));
  const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.equal(manifest.start_url, './welcome.html');
  assert.ok(sw.includes("srk-electronic-v9"));
  assert.ok(sw.includes("'./welcome.html'"));
  assert.ok(sw.includes("'./electrician.html'"));
  assert.ok(sw.includes("'./admin.html'"));
});

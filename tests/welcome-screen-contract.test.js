const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('welcome screen routes all roles and preserves the approved founder-photo slot without a substitute collage', () => {
  const welcome = fs.readFileSync(path.join(root, 'welcome.html'), 'utf8');
  const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.match(index, /location\\.replace\\('\\/welcome\\.html'\\)/);
  assert.match(welcome, /<main id="welcome"/);
  assert.match(welcome, /href="\\/customer-login\\.html"/);
  assert.match(welcome, /href="\\/electrician\\.html"/);
  assert.match(welcome, /href="\\/admin\\.html"/);
  assert.match(welcome, /class="founder-photo-pending"/);
  assert.match(welcome, /Founder की स्वीकृत वास्तविक फोटो के लिए सुरक्षित स्थान/);
  assert.match(welcome, /FOUNDER &amp; DIRECTOR/);
  assert.match(welcome, /Smart Service\\.\\.\\. Better Life\\.\\.\\./);
  assert.doesNotMatch(welcome, /assets\\/srk-founder\\.jpg/);
  assert.match(welcome, /prefers-reduced-motion:reduce/);
});

test('installed PWA opens the welcome screen and offline cache contains its entry route', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.webmanifest'), 'utf8'));
  const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.equal(manifest.start_url, './welcome.html');
  assert.match(sw, /srk-electronic-v9/);
  assert.match(sw, /'\\.\\/welcome\\.html'/);
  assert.match(sw, /'\\.\\/electrician\\.html'/);
  assert.match(sw, /'\\.\\/admin\\.html'/);
});

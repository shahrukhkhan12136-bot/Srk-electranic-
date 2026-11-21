const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('welcome and both apps reserve prominent founder-photo slots until the original is supplied', () => {
  const welcome = fs.readFileSync(path.join(root, 'welcome.html'), 'utf8');
  const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const customerLogin = fs.readFileSync(path.join(root, 'customer-login.html'), 'utf8');
  const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
  const technician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

  assert.ok(index.includes("location.replace('/welcome.html')"));
  assert.ok(welcome.includes('<main id="welcome"'));
  const companyAt = welcome.indexOf('कंपनी के बारे में');
  const welcomeAt = welcome.indexOf('WELCOME TO SRK ELECTRONIC');
  const founderAt = welcome.indexOf('data-founder-photo-slot');
  const loginAt = welcome.indexOf('id="role-login"');
  assert.ok(companyAt >= 0 && companyAt < welcomeAt, 'company introduction appears first');
  assert.ok(welcomeAt < founderAt && founderAt < loginAt, 'welcome copy is followed by founder-photo slot and role logins');
  assert.ok(welcome.includes('SRK ELECTRONIC एक इलेक्ट्रिकल सर्विस प्लेटफॉर्म है'));
  assert.ok(welcome.includes('आपका स्वागत है।'));
  assert.ok(welcome.includes('FOUNDER &amp; DIRECTOR'));
  assert.ok(welcome.includes('Smart Service... Better Life...'));
  assert.ok(welcome.includes('आधिकारिक मूल फोटो मिलने पर यहाँ प्रदर्शित होगी'));

  for (const href of ['/customer-login.html', '/electrician.html', '/admin.html']) {
    assert.equal(welcome.split('href="' + href + '"').length - 1, 1, href + ' appears exactly once');
  }
  for (const [label, page] of [['Customer OTP', customerLogin], ['Customer App', booking], ['Technician App', technician]]) {
    assert.ok(page.includes('data-founder-photo-slot'), label + ' has a prominent founder-photo slot');
    assert.ok(page.includes('FOUNDER &amp; DIRECTOR'), label + ' identifies the founder-photo slot');
    assert.ok(!page.includes('IMG-20261116-WA0000.jpg'), label + ' does not show the superseded portrait');
  }
  assert.ok(!welcome.includes('IMG-20261116-WA0000.jpg'));
  assert.match(welcome, /prefers-reduced-motion:reduce/);
});

test('PWA cache is refreshed and does not cache the superseded founder portrait', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.webmanifest'), 'utf8'));
  const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.equal(manifest.start_url, './welcome.html');
  assert.ok(sw.includes('srk-electronic-v14'));
  assert.ok(sw.includes("'./welcome.html'"));
  assert.ok(!sw.includes('IMG-20261116-WA0000.jpg'));
  assert.ok(sw.includes("'./electrician.html'"));
  assert.ok(sw.includes("'./booking.html'"));
  assert.ok(sw.includes("'./admin.html'"));
});

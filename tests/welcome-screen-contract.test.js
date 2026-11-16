const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('welcome screen presents company intro, welcome copy, official founder photo and all three role logins', () => {
  const welcome = fs.readFileSync(path.join(root, 'welcome.html'), 'utf8');
  const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const customerLogin = fs.readFileSync(path.join(root, 'customer-login.html'), 'utf8');
  const founderAsset = fs.readFileSync(path.join(root, 'assets', 'founder-photo.svg'), 'utf8');

  assert.ok(index.includes("location.replace('/welcome.html')"));
  assert.ok(welcome.includes('<main id="welcome"'));
  const companyAt = welcome.indexOf('कंपनी के बारे में');
  const welcomeAt = welcome.indexOf('WELCOME TO SRK ELECTRONIC');
  const founderAt = welcome.indexOf('src="/assets/founder-photo.svg"');
  const loginAt = welcome.indexOf('id="role-login"');
  assert.ok(companyAt >= 0 && companyAt < welcomeAt, 'company introduction appears first');
  assert.ok(welcomeAt < founderAt && founderAt < loginAt, 'welcome copy is followed by centered founder photo and role logins');
  assert.ok(welcome.includes('SRK ELECTRONIC एक इलेक्ट्रिकल सर्विस प्लेटफॉर्म है'));
  assert.ok(welcome.includes('आपका स्वागत है।'));
  assert.ok(welcome.includes('FOUNDER &amp; DIRECTOR'));
  assert.ok(welcome.includes('Smart Service... Better Life...'));
  assert.ok(!welcome.includes('founder-photo-pending'));
  assert.ok(!welcome.includes('असली Founder Photo शीघ्र'));

  for (const href of ['/customer-login.html', '/electrician.html', '/admin.html']) {
    assert.equal(welcome.split('href="' + href + '"').length - 1, 1, href + ' appears exactly once');
  }
  assert.ok(customerLogin.includes('src="/assets/founder-photo.svg"'));
  assert.ok(!customerLogin.includes('founder-photo-pending'));
  assert.ok(founderAsset.includes('data:image/jpeg;base64,'));
  assert.match(welcome, /prefers-reduced-motion:reduce/);
});

test('installed PWA opens the welcome screen and offline cache contains the founder photo', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.webmanifest'), 'utf8'));
  const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.equal(manifest.start_url, './welcome.html');
  assert.ok(sw.includes("srk-electronic-v12"));
  assert.ok(sw.includes("'./welcome.html'"));
  assert.ok(sw.includes("'./assets/founder-photo.svg'"));
  assert.ok(sw.includes("'./electrician.html'"));
  assert.ok(sw.includes("'./admin.html'"));
});

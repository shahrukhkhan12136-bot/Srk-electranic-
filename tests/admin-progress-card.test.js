const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const admin = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');

test('Admin project progress card matches the current master checklist count', () => {
  assert.match(admin, /66%<\/div><strong>62 \/ 94 आइटम<\/strong>/);
  assert.match(admin, /34%<\/div><strong>32 \/ 94 आइटम<\/strong>/);
  assert.match(admin, /aria-label="66 प्रतिशत चेकलिस्ट पूरी, 34 प्रतिशत बाकी"/);
  assert.match(admin, /● पूरा: 62 आइटम/);
  assert.match(admin, /● बाकी: 32 आइटम/);
  assert.match(admin, /width:66%;background:#087e8b/);
  assert.match(admin, /width:34%;background:#d69e2e/);
});

test('Admin GPT-2 progress remains independently reported at 70 percent', () => {
  assert.match(admin, /GPT-2 का काम पूरा<\/div><div class="stat" style="color:#087e8b">70%/);
  assert.match(admin, /30 \/ 43 आइटम/);
  assert.match(admin, /13 \/ 43 आइटम/);
  assert.match(admin, /93% — 13\/14/);
  assert.match(admin, /75% — 9\/12/);
  assert.match(admin, /47% — 8\/17/);
});

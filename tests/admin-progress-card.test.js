const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const admin = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');

test('Admin project progress card matches the current master checklist count', () => {
  assert.match(admin, /68%<\/div><strong>62 \/ 91 आइटम<\/strong>/);
  assert.match(admin, /32%<\/div><strong>29 \/ 91 आइटम<\/strong>/);
  assert.match(admin, /aria-label="68 प्रतिशत चेकलिस्ट पूरी, 32 प्रतिशत बाकी"/);
  assert.match(admin, /● पूरा: 62 आइटम/);
  assert.match(admin, /● बाकी: 29 आइटम/);
  assert.match(admin, /width:68%;background:#087e8b/);
  assert.match(admin, /width:32%;background:#d69e2e/);
});

test('Admin GPT-2 progress remains independently reported at 71 percent', () => {
  assert.match(admin, /GPT-2 का काम पूरा<\/div><div class="stat" style="color:#087e8b">71%/);
  assert.match(admin, /30 \/ 42 आइटम/);
  assert.match(admin, /12 \/ 42 आइटम/);
  assert.match(admin, /93% — 13\/14/);
  assert.match(admin, /82% — 9\/11/);
  assert.match(admin, /47% — 8\/17/);
});

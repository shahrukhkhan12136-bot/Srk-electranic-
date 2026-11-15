const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const admin = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');

test('Admin project progress card matches the master checklist count', () => {
  assert.match(admin, /65%<\\/div><strong>56 \/ 86 आइटम<\\/strong>/);
  assert.match(admin, /35%<\\/div><strong>30 \/ 86 आइटम<\\/strong>/);
  assert.match(admin, /aria-label="65 प्रतिशत चेकलिस्ट पूरी, 35 प्रतिशत बाकी"/);
  assert.match(admin, /width:65%;background:#087e8b/);
  assert.match(admin, /width:35%;background:#d69e2e/);
});

test('Admin GPT-2 progress remains independently reported at 69 percent', () => {
  assert.match(admin, /GPT-2 का काम पूरा<\\/div><div class="stat" style="color:#087e8b">69%/);
  assert.match(admin, /27 \/ 39 आइटम/);
  assert.match(admin, /12 \/ 39 आइटम/);
});

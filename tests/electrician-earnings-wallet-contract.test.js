'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'electrician.html'), 'utf8');
const earnings = source.slice(source.indexOf('async function loadEarnings'), source.indexOf('async function loadPartnerWallet'));
const wallet = source.slice(source.indexOf('async function loadPartnerWallet'), source.indexOf('const electricianOfferResponseBusy'));
test('Electrician earnings and wallet ignore stale responses after auth changes or overlapping refreshes', () => {
  assert.match(source, /electricianEarningsRequest=0/);
  assert.match(source, /electricianWalletRequest=0/);
  assert.match(source, /onAuthStateChange\\(\\(_e,s\\)=>\\{electricianEarningsRequest\\+\\+;electricianWalletRequest\\+\\+;/);
  assert.match(earnings, /const request=\\+\\+electricianEarningsRequest,requestedUserId=user\\.id,requestedProfileId=profile\\.id;/);
  assert.match(earnings, /request===electricianEarningsRequest&&user\\?\\.id===requestedUserId&&profile\\?\\.id===requestedProfileId/);
  assert.match(earnings, /if\\(!isCurrent\\(\\)\\)return;/);
  assert.match(wallet, /const request=\\+\\+electricianWalletRequest,requestedUserId=user\\.id;/);
  assert.match(wallet, /request===electricianWalletRequest&&user\\?\\.id===requestedUserId/);
  assert.equal((wallet.match(/if\\(!isCurrent\\(\\)\\)return;/g)||[]).length, 2);
});

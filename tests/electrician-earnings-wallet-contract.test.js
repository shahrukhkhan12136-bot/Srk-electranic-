'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'electrician.html'), 'utf8');
const earnings = source.slice(source.indexOf('async function loadEarnings'), source.indexOf('async function loadPartnerWallet'));
const wallet = source.slice(source.indexOf('async function loadPartnerWallet'), source.indexOf('const electricianOfferResponseBusy'));
test('Electrician earnings and wallet ignore stale responses after auth changes or overlapping refreshes', () => {
  assert.ok(source.includes('electricianEarningsRequest=0'));
  assert.ok(source.includes('electricianWalletRequest=0'));
  assert.match(source,/onAuthStateChange\(\(_e,s\)=>\{const nextUser=s\?\.user\|\|null,previousUserId=user\?\.id\|\|null,nextUserId=nextUser\?\.id\|\|null;electricianEarningsRequest\+\+;electricianWalletRequest\+\+;if\(previousUserId!==nextUserId\)/);
  assert.ok(/function clearElectricianAccountView\(\)\{\s*electricianAccountViewGeneration\+\+;[\s\S]*?electricianSupportThreadRequest\+\+;[\s\S]*?profile=null;/.test(source));
  assert.match(source,/if\(previousUserId!==nextUserId\)\{electricianRefreshRequest\+\+;[\s\S]*?clearElectricianAccountView\(\)/);
  assert.ok(source.includes("'jobs','earnings','partnerWallet','electricianSupportTickets'"));
  assert.match(source,/if\(\(user\?\.id\|\|null\)!==\(nextUser\?\.id\|\|null\)\)\{electricianRefreshRequest\+\+;[\s\S]*?clearElectricianAccountView\(\);\}/);
  assert.ok(earnings.includes('const request=++electricianEarningsRequest,requestedUserId=user.id,requestedProfileId=profile.id;'));
  assert.ok(earnings.includes('request===electricianEarningsRequest&&user?.id===requestedUserId&&profile?.id===requestedProfileId'));
  assert.ok(earnings.includes('if(!isCurrent())return;'));
  assert.ok(wallet.includes('const request=++electricianWalletRequest,requestedUserId=user.id;'));
  assert.ok(wallet.includes('request===electricianWalletRequest&&user?.id===requestedUserId'));
  assert.equal((wallet.match(/if\(!isCurrent\(\)\)return;/g)||[]).length, 2);
});


const walletAccessSql = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261118160000_harden_electrician_wallet_profile_access.sql'), 'utf8');

test('Electrician wallet summary requires approved active profile and both Auth identity columns', () => {
  const start = walletAccessSql.indexOf('CREATE OR REPLACE FUNCTION public.srk_get_my_wallet_summary()');
  const end = walletAccessSql.indexOf('$function$;', start);
  const fn = walletAccessSql.slice(start, end);
  assert.ok(start >= 0 && end > start, 'latest wallet summary function exists');
  assert.match(fn, /ep\.user_id\s*=\s*v_uid/);
  assert.match(fn, /ep\.auth_user_id\s*=\s*v_uid/);
  assert.match(fn, /ep\.verification_status\s*=\s*'approved'/);
  assert.match(fn, /ep\.active\s*=\s*true/);
  assert.ok(walletAccessSql.includes('REVOKE ALL ON FUNCTION public.srk_get_my_wallet_summary() FROM PUBLIC, anon'));
  assert.ok(walletAccessSql.includes('GRANT EXECUTE ON FUNCTION public.srk_get_my_wallet_summary() TO authenticated'));
  assert.ok(fn.indexOf('IF EXISTS') < fn.indexOf('SELECT wa.id INTO v_electrician_id'));
});


const payoutRlsMigration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261118170000_harden_electrician_payout_ledger_rls.sql'), 'utf8');

test('payout ledger RLS requires the same approved active electrician identity and preserves Main Admin access', () => {
  assert.match(payoutRlsMigration, /DROP POLICY IF EXISTS srk_read_authorized_electrician_payouts/);
  assert.match(payoutRlsMigration, /CREATE POLICY srk_read_authorized_electrician_payouts[\\s\\S]*?FOR SELECT TO authenticated/);
  assert.match(payoutRlsMigration, /\\(SELECT public\\.is_srk_admin\\(\\)\\)/);
  assert.match(payoutRlsMigration, /ep\\.id\\s*=\\s*srk_electrician_payouts\\.electrician_profile_id/);
  assert.match(payoutRlsMigration, /ep\\.user_id\\s*=\\s*\\(SELECT auth\\.uid\\(\\)\\)/);
  assert.match(payoutRlsMigration, /ep\\.auth_user_id\\s*=\\s*\\(SELECT auth\\.uid\\(\\)\\)/);
  assert.match(payoutRlsMigration, /ep\\.verification_status\\s*=\\s*'approved'/);
  assert.match(payoutRlsMigration, /ep\\.active\\s*=\\s*true/);
  assert.match(payoutRlsMigration, /BEGIN;[\\s\\S]*COMMIT;/);
});

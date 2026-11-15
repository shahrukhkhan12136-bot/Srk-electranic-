const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const staffMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114390000_admin_staff_rbac_foundation.sql'), 'utf8');
const staffFunction = fs.readFileSync(path.join(root, 'supabase/functions/admin-staff-management/index.ts'), 'utf8');
const workMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql'), 'utf8');
const legacyStatusMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115160000_legacy_booking_status_write_guard.sql'), 'utf8');
const manualRefundMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115130000_admin_manual_refund_request_completion.sql'), 'utf8');

test('Admin refund queue does not offer another launch action after a processed refund', () => {
  assert.match(admin, /state==='approved'\s*&&\s*r\.refund_record_status!=='processed'/);
  assert.match(admin, /Provider Refund: <b>/);
});

test('Support Staff portal is isolated from Main Admin modules', () => {
  assert.match(admin, /if\(staffOnly\)el\.classList\.toggle\('hidden',mode!=='staff'\);\s*else if\(adminShared\)el\.classList\.toggle\('hidden',mode!=='staff'&&mode!=='main_admin'\);\s*else el\.classList\.toggle\('hidden',mode!=='main_admin'\);/);
  assert.match(admin, /srk_admin_staff_register_session/);
  assert.match(admin, /srk_has_admin_permission/);
});

test('Support Staff cannot see Main Admin management, refund, accounting, payout or profile-approval panels', () => {
  for (const id of [
    'adminStaffManagementCard',
    'adminCustomerRefundReviewCard',
    'adminRazorpayRefundCard',
    'adminAccountingReconciliationCard',
    'adminPhoneChangeCard',
    'adminAreaChangeCard'
  ]) {
    const panel = admin.match(new RegExp('<div class="([^"]*)" id="' + id + '"'));
    assert.ok(panel, id + ' must exist');
    assert.doesNotMatch(panel[1], /staff-only|admin-shared/, id + ' must remain Main Admin-only');
  }
  assert.match(admin, /class="card staff-only hidden" id="staffSupportCustomerCard"/);
  assert.match(admin, /class="card staff-only hidden" id="staffSupportElectricianCard"/);
  assert.match(admin, /class="card admin-shared hidden" id="sosAlertCard"/);
});

test('Staff invitation is independently authorized as Main Admin and role is fixed to support', () => {
  assert.match(staffFunction, /rpc\("is_srk_admin"\)/);
  assert.match(staffFunction, /body\.action !== "invite_support_staff"/);
  assert.match(staffFunction, /role: "support"/);
  assert.match(staffFunction, /srk_admin_staff_register_invited_user/);
});

test('Staff data access is assignment-scoped and migration has no direct private phone projection', () => {
  assert.match(staffMigration, /assigned_staff_user_id=auth\.uid\(\)/);
  assert.doesNotMatch(staffMigration, /customer_phone|electrician_phone/);
  assert.match(staffMigration, /support\.customer\.read/);
  assert.match(staffMigration, /support\.electrician\.read/);
});


test('new-category booking status changes require protected server workflow', () => {
  assert.match(admin, /status!==booking\.status&&\!\( !booking\.selected_category&&booking\.status==='new'&&status==='confirmed'\)/);
  assert.match(workMigration, /CREATE OR REPLACE FUNCTION public\.srk_guard_new_category_booking_status_transition\(\)/);
  assert.match(workMigration, /work_transition_authorizations a[\s\S]*?a\.target_status=NEW\.status/);
  assert.match(workMigration, /NEW_CATEGORY_STATUS_REQUIRES_PROTECTED_WORKFLOW/);
  assert.match(workMigration, /BOOKING_CATEGORY_IS_IMMUTABLE/);
});


test('Admin cannot manually mark an unfinished booking completed through the generic Save path', () => {
  assert.match(admin, /if\(status==='completed'&&booking\.status!=='completed'\)[\s\S]*?सुरक्षित completion workflow से ही दर्ज होगी/);
  assert.doesNotMatch(admin, /\.update\(\{status,quoted_amount:quoted\}\)/);
  assert.match(admin, /sb\.rpc\('srk_admin_confirm_legacy_booking'/);
});


test('legacy booking status is no longer directly writable by authenticated clients', () => {
  assert.match(legacyStatusMigration, /revoke update on table public\.service_bookings from authenticated/i);
  assert.match(legacyStatusMigration, /grant update \(quoted_amount,amount_paid,payment_status\)/i);
  assert.match(legacyStatusMigration, /create or replace function public\.srk_admin_confirm_legacy_booking/i);
  assert.match(legacyStatusMigration, /v_booking\.selected_category is not null/i);
  assert.match(legacyStatusMigration, /v_booking\.status is distinct from 'new'/i);
  assert.match(legacyStatusMigration, /set status='confirmed'/i);
});

test('Admin generic Save keeps historical quote read-only and uses dedicated legacy confirmation RPC', () => {
  assert.doesNotMatch(admin, /srk_admin_update_legacy_booking_quote/);
  assert.doesNotMatch(admin, /id="amt-/);
  assert.match(admin, /ऐतिहासिक रिकॉर्ड केवल पढ़ने के लिए/);
  assert.doesNotMatch(admin, /\.update\(\{quoted_amount:quoted\}\)/);
  assert.match(admin, /sb\.rpc\('srk_admin_confirm_legacy_booking',\{p_booking_id:id\}\)/);
  assert.match(admin, /status!==booking\.status&&\!\( !booking\.selected_category&&booking\.status==='new'&&status==='confirmed'\)/);
  assert.doesNotMatch(admin, /\.update\(\{status:/);
});


test('new-category manual refunds reconcile against immutable labour bill and settled fee ledger', () => {
  assert.match(manualRefundMigration, /v_booking\.selected_category is not null/);
  assert.match(manualRefundMigration, /NEW_CATEGORY_REFUND_REQUIRES_COMPLETED_BOOKING/);
  assert.match(manualRefundMigration, /customer_user_id=v_booking\.customer_user_id/);
  assert.match(manualRefundMigration, /electrician_profile_id is distinct from v_booking\.assigned_electrician_id/);
  assert.match(manualRefundMigration, /CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED/);
  assert.match(manualRefundMigration, /v_expected_paise:=v_labour_paise\+v_fee_paise/);
  assert.match(manualRefundMigration, /MANUAL_REFUND_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER/);
});

const refundRecoveryMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115240000_harden_refund_recovery_full_amount.sql'), 'utf8');

test('Razorpay recovery finalizer rejects evidence unless refund equals full verified booking collection', () => {
  assert.match(refundRecoveryMigration, /select \* into v_booking from public\.service_bookings where id=v_audit\.booking_id for update/i);
  assert.match(refundRecoveryMigration, /v_audit\.amount_paise is distinct from round\(v_booking\.amount_paid\*100\)::bigint/);
  assert.match(refundRecoveryMigration, /RECOVERY_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION/);
  assert.match(refundRecoveryMigration, /v_refund\.amount_paise is distinct from v_audit\.amount_paise/);
});

const refundReconcileMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115250000_harden_refund_reconcile_full_amount.sql'), 'utf8');

test('provider processed refund reconciliation independently requires the full booking collection', () => {
  assert.match(refundReconcileMigration, /select b\.\* into v_booking[\s\S]*?for update of b/i);
  assert.match(refundReconcileMigration, /p_provider_status='processed'[\s\S]*?v_refund\.amount_paise is distinct from round\(v_booking\.amount_paid\*100\)::bigint/i);
  assert.match(refundReconcileMigration, /PROVIDER_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION/);
  assert.match(refundReconcileMigration, /grant execute on function public\.srk_service_reconcile_booking_refund\(uuid,text,text,text\) to service_role/i);
});



test('Support Staff customer and electrician inbox RPCs enforce active permissions and current case assignment', () => {
  const staffFunctions = [
    ['srk_admin_staff_list_customer_complaints', 'support.customer.read'],
    ['srk_admin_staff_list_customer_messages', 'support.customer.read'],
    ['srk_admin_staff_send_customer_message', 'support.customer.reply'],
    ['srk_admin_staff_update_customer_complaint', 'support.customer.update_status'],
    ['srk_admin_staff_list_electrician_tickets', 'support.electrician.read'],
    ['srk_admin_staff_list_electrician_messages', 'support.electrician.read'],
    ['srk_admin_staff_send_electrician_message', 'support.electrician.reply'],
    ['srk_admin_staff_update_electrician_ticket', 'support.electrician.update_status']
  ];
  for (const [name, permission] of staffFunctions) {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = staffMigration.match(new RegExp('create or replace function public\\.' + escaped + '[\\s\\S]*?\\$function\\$;', 'i'));
    assert.ok(match, name + ' must exist');
    assert.ok(match[0].includes(permission), name + ' must check its explicit permission');
    assert.match(match[0], /assigned_staff_user_id/);
    assert.ok(match[0].includes('auth.uid()') || match[0].includes('v_uid'), name + ' must bind access to current user');
  }
  const assignmentFn = staffMigration.match(/create or replace function public\.srk_admin_assign_support_case[\s\S]*?\$function\$;/i);
  assert.ok(assignmentFn);
  assert.ok(assignmentFn[0].includes('public.is_srk_admin()'));
  assert.ok(assignmentFn[0].includes('MAIN_ADMIN_ONLY'));
});

test('Support Staff authorization and assignment use a consistent lock order and live session check', () => {
  const getStaffRpc = (name) => {
    const start = staffMigration.lastIndexOf('create or replace function public.' + name);
    assert.notEqual(start, -1, name + ' must exist');
    const end = staffMigration.indexOf('$function$;', start);
    assert.notEqual(end, -1, name + ' must have a closed function body');
    return staffMigration.slice(start, end + '$function$;'.length);
  };
  const assignment = getStaffRpc('srk_admin_assign_support_case');
  const registryLock = assignment.indexOf('for share');
  const caseLock = assignment.indexOf('for update');
  const assignmentLock = assignment.indexOf('for update', caseLock + 1);
  assert.ok(registryLock >= 0 && caseLock > registryLock && assignmentLock > caseLock,
    'assignment must lock target Staff, case, then assignment in that order');

  const permissionStart = staffMigration.lastIndexOf('create or replace function public.srk_has_admin_permission');
  const permissionEnd = staffMigration.indexOf('$function$;', permissionStart);
  assert.ok(permissionStart >= 0 && permissionEnd > permissionStart);
  const permission = staffMigration.slice(permissionStart, permissionEnd);
  assert.ok(permission.includes('tracked.auth_session_id = v_session_id'));
  assert.ok(permission.includes('tracked.revoked_at is null') && permission.includes('for share'));
  assert.ok(permission.includes('auth.sessions auth_s') && permission.includes('auth_s.id = v_session_id'));
});

test('Support Staff session lifecycle and private assignment tables deny direct client access', () => {
  const sessionRegisterStart = staffMigration.lastIndexOf('create or replace function public.srk_admin_staff_register_session');
  const sessionRegisterEnd = staffMigration.indexOf('$function$;', sessionRegisterStart);
  assert.ok(sessionRegisterStart >= 0 && sessionRegisterEnd > sessionRegisterStart);
  const register = staffMigration.slice(sessionRegisterStart, sessionRegisterEnd);
  assert.ok(register.includes('auth.sessions a'));
  assert.ok(register.includes('a.id = v_session_id and a.user_id = v_uid'));
  assert.ok(register.includes('revoked_at is null'));

  const statusStart = staffMigration.lastIndexOf('create or replace function public.srk_admin_staff_set_status');
  const statusEnd = staffMigration.indexOf('$function$;', statusStart);
  const setStatus = staffMigration.slice(statusStart, statusEnd);
  assert.ok(setStatus.includes("p_status in ('suspended','disabled')"));
  assert.ok(setStatus.includes('set revoked_at = coalesce(revoked_at, clock_timestamp())'));

  const revokeStart = staffMigration.lastIndexOf('create or replace function public.srk_admin_staff_revoke_session');
  const revokeEnd = staffMigration.indexOf('$function$;', revokeStart);
  const revoke = staffMigration.slice(revokeStart, revokeEnd);
  assert.ok(revoke.includes('revoked_at = coalesce(revoked_at,clock_timestamp())'));
  assert.ok(revoke.includes('public.is_srk_admin()'));

  const normalizedMigration = staffMigration.replace(/\s+/g, '');
  for (const table of ['srk_admin_staff','srk_admin_permissions','srk_admin_role_permissions','srk_admin_staff_sessions','srk_admin_staff_audit_events','srk_admin_support_assignments']) {
    assert.ok(normalizedMigration.includes('revokeallonpublic.' + table + 'frompublic,anon,authenticated'),
      table + ' must not be directly accessible to client roles');
  }
  assert.ok(staffMigration.includes('grant execute on function public.srk_admin_staff_register_invited_user(uuid,text,uuid) to service_role'));
});


const staffPermissionVolatilityFix = fs.readFileSync(path.join(root, 'supabase/migrations/20261116100000_fix_staff_permission_helper_volatility.sql'), 'utf8');

test('Staff permission helper is VOLATILE because it takes row locks', () => {
  const functionStart = staffPermissionVolatilityFix.indexOf('create or replace function public.srk_has_admin_permission(');
  const functionEnd = staffPermissionVolatilityFix.indexOf('$function$;', functionStart);
  assert.ok(functionStart >= 0 && functionEnd > functionStart);
  const helper = staffPermissionVolatilityFix.slice(functionStart, functionEnd);
  assert.ok(helper.includes('language plpgsql') && helper.includes('volatile') && helper.includes('security definer'));
  assert.ok(helper.includes('from public.srk_admin_staff s') && helper.includes('for share;'));
  assert.ok(helper.includes('from public.srk_admin_staff_sessions tracked') && helper.includes('for share;'));
  assert.ok(staffPermissionVolatilityFix.includes('revoke all on function public.srk_has_admin_permission(text) from public, anon;'));
});


test('Staff invite Edge Function authenticates the bearer token and checks Main Admin through the trusted Auth user', () => {
  assert.match(staffFunction, /authHeader\.startsWith\("Bearer "\)/);
  assert.match(staffFunction, /userClient\.auth\.getUser\(token\)/);
  assert.match(staffFunction, /userClient\.rpc\("is_srk_admin"\)/);
  assert.match(staffFunction, /authData\.user\.id/);
  assert.doesNotMatch(staffFunction, /body\.(user_id|actor_admin_id|role|is_admin)/);
});

test('Staff invite Edge Function fixes Support role and removes an orphan Auth user if registry creation fails', () => {
  assert.match(staffFunction, /role: "support"/);
  assert.match(staffFunction, /p_actor_admin_id: authData\.user\.id/);
  assert.match(staffFunction, /if \(registerError \|\| registered !== true\)/);
  assert.match(staffFunction, /service\.auth\.admin\.deleteUser\(invited\.user\.id\)/);
  assert.match(staffFunction, /status: "invited"/);
});


test('Staff invite failure warns that the invitation email may already have been sent', () => {
  assert.match(staffFunction, /invitation email may already have been sent/i);
  assert.match(staffFunction, /ignore any invitation email/i);
  assert.match(staffFunction, /Auth identity cleanup failed/i);
});



test('Every Support Staff SECURITY DEFINER RPC pins an empty search_path and revokes public execution', () => {
  const functions = [...staffMigration.matchAll(/create or replace function public\.([a-z0-9_]+)\s*\([\s\S]*?\$function\$;/gi)];
  assert.ok(functions.length >= 20, 'expected the complete Staff RPC set to be audited');
  for (const match of functions) {
    const body = match[0];
    if (!/security definer/i.test(body)) continue;
    assert.match(body, /set search_path\s*=\s*''/i, match[1] + ' must pin an empty search_path');
    const start = staffMigration.indexOf(body);
    const after = staffMigration.slice(start + body.length, start + body.length + 240);
    assert.ok(after.includes('revoke all on function public.' + match[1] + '('),
      match[1] + ' must revoke default public execution');
  }
});


test('Staff suspension, session registration, and permission checks serialize in registry-first order', () => {
  const getFn = (name) => {
    const start = staffMigration.lastIndexOf('create or replace function public.' + name);
    assert.notEqual(start, -1, name + ' must exist');
    const end = staffMigration.indexOf('$function$;', start);
    assert.ok(end > start, name + ' must have a closed function body');
    return staffMigration.slice(start, end);
  };
  const status = getFn('srk_admin_staff_set_status');
  const statusRegistryLock = status.indexOf('for update');
  const sessionRevocation = status.indexOf('update public.srk_admin_staff_sessions');
  assert.ok(statusRegistryLock >= 0 && sessionRevocation > statusRegistryLock,
    'suspension must lock the Staff registry before revoking tracked sessions');

  const register = getFn('srk_admin_staff_register_session');
  const registerRegistryLock = register.indexOf('for share');
  const registerInsert = register.indexOf('insert into public.srk_admin_staff_sessions');
  assert.ok(registerRegistryLock >= 0 && registerInsert > registerRegistryLock,
    'session registration must lock the Staff registry before writing the tracked session');

  const permission = getFn('srk_has_admin_permission');
  const permissionRegistryLock = permission.indexOf('for share');
  const permissionSessionLock = permission.indexOf('for share', permissionRegistryLock + 1);
  assert.ok(permissionRegistryLock >= 0 && permissionSessionLock > permissionRegistryLock,
    'permission check must lock Staff registry before tracked session');
  assert.ok(permission.includes('auth.sessions auth_s') && permission.includes('auth_s.id = v_session_id'),
    'permission check must still verify the live Supabase Auth session');
});


test('Support replies and status updates lock the case before its current assignment and reject closed cases', () => {
  const names = [
    'srk_admin_staff_send_customer_message',
    'srk_admin_staff_update_customer_complaint',
    'srk_admin_staff_send_electrician_message',
    'srk_admin_staff_update_electrician_ticket'
  ];
  for (const name of names) {
    const start = staffMigration.lastIndexOf('create or replace function public.' + name);
    assert.notEqual(start, -1, name + ' must exist');
    const end = staffMigration.indexOf('$function$;', start);
    const body = staffMigration.slice(start, end);
    const caseLock = body.indexOf('for update');
    const assignmentLock = body.indexOf('for update', caseLock + 1);
    assert.ok(caseLock >= 0 && assignmentLock > caseLock,
      name + ' must lock the case before checking/locking its assignment');
    assert.match(body, /assigned_staff_user_id\s*=\s*v_uid/);
    assert.match(body, /v_case_status\s*=\s*'closed'|v_old_status\s*=\s*'closed'/);
    assert.match(body, /SUPPORT_CASE_NOT_ASSIGNED_TO_YOU/);
    assert.match(body, /SUPPORT_CASE_CLOSED/);
  }
});


const financialReadSearchPathFix = fs.readFileSync(path.join(root, 'supabase/migrations/20261116110000_pin_legacy_financial_read_rpc_search_paths.sql'), 'utf8');

test('Legacy financial SECURITY DEFINER read RPCs use an empty search_path', () => {
  for (const name of [
    'srk_admin_commission_report',
    'srk_get_my_wallet_summary',
    'srk_admin_wallet_overview'
  ]) {
    assert.match(
      financialReadSearchPathFix,
      new RegExp('alter function public\\.' + name + '\\(\\)\\s+set search_path\\s*=\\s*\\x27\\x27', 'i'),
      name + ' must be pinned to an empty search_path'
    );
  }
});


const customerCallSearchPathFix = fs.readFileSync(path.join(root, 'supabase/migrations/20261116120000_pin_customer_call_contact_rpc_search_paths.sql'), 'utf8');

test('Customer call-contact RPCs are pinned to an empty search_path', () => {
  assert.ok(customerCallSearchPathFix.includes("alter function private.srk_get_customer_call_contacts_impl()"));
  assert.ok(customerCallSearchPathFix.includes("alter function public.srk_get_customer_call_contacts()"));
  assert.equal((customerCallSearchPathFix.match(/set search_path = '';/g) || []).length, 2);
});


const walletReceiptSearchPathFix = fs.readFileSync(path.join(root, 'supabase/migrations/20261116130000_pin_wallet_and_receipt_rpc_search_paths.sql'), 'utf8');

test('Wallet and customer receipt SECURITY DEFINER RPCs use an empty search_path', () => {
  for (const [schema, name, signature] of [
    ['public', 'srk_get_my_wallet_summary', ''],
    ['public', 'srk_admin_wallet_overview', ''],
    ['public', 'srk_get_my_earnings', ''],
    ['public', 'srk_customer_get_payment_receipt', 'uuid']
  ]) {
    assert.match(
      walletReceiptSearchPathFix,
      new RegExp('alter function ' + schema + '\\.' + name + '\\(' + signature + '\\)\\s+set search_path\\s*=\\s*\\x27\\x27', 'i'),
      name + ' must be pinned to an empty search_path'
    );
  }
});


const electricianOfferSearchPathFix = fs.readFileSync(path.join(root, 'supabase/migrations/20261116140000_pin_electrician_offer_details_search_path.sql'), 'utf8');

test('Electrician offer-details RPC is pinned to an empty search_path', () => {
  assert.ok(electricianOfferSearchPathFix.includes("alter function public.srk_get_my_offer_details()"));
  assert.ok(electricianOfferSearchPathFix.includes("set search_path = '';"));
});

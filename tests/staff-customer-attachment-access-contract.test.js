const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261117110000_support_staff_assigned_customer_attachment_read.sql'), 'utf8');

function functionBody(source, name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' client handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

test('Support Staff customer thread loads attachment metadata only through its assigned-case RPC', () => {
  const open = functionBody(admin, 'openStaffCustomerThread');
  assert.match(open, /srk_admin_staff_list_customer_messages/);
  assert.match(open, /srk_admin_staff_list_customer_attachments/);
  assert.match(open, /a\.message_id/);
  assert.match(open, /esc\(a\.file_name\)/);
  assert.match(open, /request!==staffCustomerThreadRequest/);
  assert.match(migration, /support\.customer\.read/);
  assert.match(migration, /assigned_staff_user_id=auth\.uid\(\)/);
});

test('Staff attachment open re-checks Storage RLS on download and does not mint a signed URL', () => {
  const open = functionBody(admin, 'openStaffCustomerAttachment');
  assert.match(open, /storage\.from\('srk-customer-support'\)\.download\(attachment\.storage_path\)/);
  assert.doesNotMatch(open, /createSignedUrl/);
  assert.match(open, /attachment\.complaint_id!==staffCustomerSelectedId/);
  assert.match(open, /फ़ाइल उपलब्ध नहीं है/);
});

test('Staff attachment state is cleared when another thread opens and on logout', () => {
  const open = functionBody(admin, 'openStaffCustomerThread');
  const logout = functionBody(admin, 'logout');
  assert.match(open, /clearStaffCustomerAttachmentState\(\)/);
  assert.match(logout, /clearStaffCustomerAttachmentState\(\)/);
  assert.match(admin, /URL\.revokeObjectURL\(url\)/);
});

test('Storage read guard requires current active permission, exact customer path and current assignment', () => {
  assert.match(migration, /language plpgsql\s+volatile\s+security definer\s+set search_path = ''/i);
  assert.match(migration, /srk_has_admin_permission\('support\.customer\.read'\)/);
  assert.match(migration, /storage\.foldername\(p_object_name\)/);
  assert.match(migration, /customer_user_id::text=v_parts\[1\]/);
  assert.match(migration, /case_type='customer_complaint'/);
  assert.match(migration, /assigned_staff_user_id=v_uid/);
  assert.match(migration, /a\.storage_path=p_object_name/);
  assert.match(migration, /for share/i);
});

test('Storage policy adds only assigned Staff SELECT while preserving existing owner/Admin and write boundaries', () => {
  assert.match(migration, /srk_customer_support_object_access\(name,true\)/);
  assert.match(migration, /srk_admin_staff_can_read_customer_attachment\(name\)/);
  assert.doesNotMatch(migration, /create policy[^;]+for (?:insert|delete)[^;]*srk_admin_staff_can_read_customer_attachment/is);
  assert.match(migration, /srk_customer_support_read_own_or_admin/);
});

test('Staff attachment metadata RPC locks the complaint then assignment and is authenticated-only', () => {
  assert.match(migration, /srk_admin_staff_list_customer_attachments/);
  assert.match(migration, /from public\.srk_booking_complaints c[\s\S]*?for share[\s\S]*?from public\.srk_admin_support_assignments a[\s\S]*?assigned_staff_user_id=auth\.uid\(\)[\s\S]*?for share/);
  assert.match(migration, /revoke all on function public\.srk_admin_staff_list_customer_attachments\(uuid\) from public,anon/i);
  assert.match(migration, /grant execute on function public\.srk_admin_staff_list_customer_attachments\(uuid\) to authenticated/i);
});

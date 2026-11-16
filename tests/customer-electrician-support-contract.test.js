const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const customerSupportSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261113220000_customer_support_conversation_schema.sql'), 'utf8');
const customerAttachmentSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261113230000_support_attachment_paths_and_admin_message_list.sql'), 'utf8');
const electricianSupportSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114350000_electrician_support_tickets_and_admin_inbox.sql'), 'utf8');

test('Customer support UI uses authenticated complaint and private message RPCs', () => {
  for (const rpc of [
    'srk_customer_create_booking_complaint',
    'srk_customer_list_booking_complaints',
    'srk_customer_send_booking_complaint_message',
    'srk_customer_list_booking_complaint_messages',
    'srk_customer_list_complaint_message_attachments',
    'srk_customer_link_complaint_message_attachment'
  ]) assert.ok(customer.includes(".rpc('" + rpc + "'"), 'missing Customer support RPC caller: ' + rpc);
  assert.match(customer, /customerSb\.auth\.getSession\(\)/);
  assert.match(customer, /customer_user_id',session\.user\.id/);
});

test('Customer support attachments are limited to five allowlisted files up to 10 MiB', () => {
  assert.match(customer, /const allowed=\['image\/jpeg','image\/png','image\/webp','application\/pdf'\]/);
  assert.match(customer, /files\.length>5/);
  assert.match(customer, /f\.size>10485760/);
  assert.match(customer, /createSignedUrl\(a\.storage_path,300\)/);
  assert.match(customer, /rel='noopener noreferrer'/);
});

test('Customer support message send reconciles uncertain RPC responses before allowing a retry', () => {
  const send = customer.slice(customer.indexOf('async function sendCustomerSupportMessage()'), customer.indexOf('async function syncCustomerSession()'));
  assert.match(send, /srk_customer_list_booking_complaint_messages/);
  assert.match(send, /previousMessageIds=new Set/);
  assert.match(send, /sendAttempted=true/);
  assert.match(send, /m\.sender_role==='customer'&&m\.body===messageBody/);
  assert.match(send, /संदेश भेजने का परिणाम स्पष्ट नहीं है/);
  assert.match(send, /दोबारा भेजने से पहले बातचीत Refresh करके जाँचें/);
});

test('Customer complaint uncertain-result reconciliation excludes pre-existing identical complaints', () => {
  const create = customer.slice(customer.indexOf('async function createCustomerSupportComplaint()'), customer.indexOf('async function loadCustomerSupportAttachments'));
  assert.match(create, /srk_customer_list_booking_complaints/);
  assert.match(create, /priorComplaintIds=new Set\(before\.map\(row=>row\.id\)\)/);
  assert.match(create, /!priorComplaintIds\.has\(row\.id\)/);
  assert.match(create, /newMatches\.length===1\?newMatches\[0\]:null/);
  assert.ok(create.indexOf('priorComplaintIds=new Set') < create.indexOf("rpc('srk_customer_create_booking_complaint'"));
});

test('Customer support SQL enforces complaint ownership and private storage object ownership', () => {
  assert.match(customerSupportSql, /c\.id=p_complaint_id and c\.customer_user_id=v_user_id/);
  assert.match(customerSupportSql, /o\.bucket_id='srk-customer-support'/);
  assert.match(customerSupportSql, /o\.owner_id=v_user_id::text/);
  assert.match(customerSupportSql, /p_file_size_bytes is null or p_file_size_bytes not between 1 and 10485760/);
  assert.match(customerAttachmentSql, /public\.is_srk_admin\(\)/);
  assert.match(customerAttachmentSql, /limit 100/);
});

test('Electrician support UI sends the expected ticket, thread and reply RPC contracts', () => {
  for (const rpc of [
    'srk_electrician_create_support_ticket',
    'srk_electrician_list_my_support_tickets',
    'srk_electrician_list_my_support_messages',
    'srk_electrician_send_support_message'
  ]) assert.ok(electrician.includes(".rpc('" + rpc + "'"), 'missing Electrician support RPC caller: ' + rpc);
  assert.match(electrician, /electricianSupportCreateBusy/);
  assert.match(electrician, /electricianSupportReplyBusy/);
  assert.match(electrician, /esc\(t\.subject\)/);
  assert.match(electrician, /esc\(m\.body\)/);
});

test('Electrician support SQL enforces profile ownership, assigned-booking scope and bounded ticket creation', () => {
  assert.match(electricianSupportSql, /where user_id=v_uid and auth_user_id=v_uid/);
  assert.match(electricianSupportSql, /b\.assigned_electrician_id=v_profile\.id/);
  assert.match(electricianSupportSql, /daily_support_ticket_limit_reached/i);
  assert.match(electricianSupportSql, /where t\.user_id=v_uid/);
  assert.match(electricianSupportSql, /set search_path = ''/);
});

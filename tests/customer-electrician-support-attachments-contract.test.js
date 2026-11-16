const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const customerSchema = fs.readFileSync(path.join(root, 'supabase/migrations/20261113220000_customer_support_conversation_schema.sql'), 'utf8');
const customerAttachments = fs.readFileSync(path.join(root, 'supabase/migrations/20261113230000_support_attachment_paths_and_admin_message_list.sql'), 'utf8');
const electricianSchema = fs.readFileSync(path.join(root, 'supabase/migrations/20261114350000_electrician_support_tickets_and_admin_inbox.sql'), 'utf8');

function functionBody(source, name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' client handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

test('customer complaint creation and thread reads use the customer-scoped RPC contracts', () => {
  const create = functionBody(customer, 'createCustomerSupportComplaint');
  const list = functionBody(customer, 'loadCustomerSupportComplaints');
  const messages = functionBody(customer, 'loadCustomerSupportMessages');
  assert.match(create, /srk_customer_create_booking_complaint/);
  assert.match(create, /p_booking_id:bookingId,p_category:category,p_description:description/);
  assert.match(list, /srk_customer_list_booking_complaints/);
  assert.match(messages, /srk_customer_list_booking_complaint_messages/);
  assert.match(messages, /request!==customerSupportThreadRequest/);
  assert.match(customerSchema, /where c\.id=p_complaint_id and c\.customer_user_id=v_user_id/);
});

test('customer attachment upload enforces count, MIME and size before upload and links only uploaded owned objects', () => {
  const send = functionBody(customer, 'sendCustomerSupportMessage');
  assert.match(send, /files\.length>5/);
  assert.match(send, /image\/jpeg','image\/png','image\/webp','application\/pdf/);
  assert.match(send, /f\.size>10485760/);
  assert.match(send, /srk-customer-support'\)\.upload\(path,file/);
  assert.match(send, /srk_customer_link_complaint_message_attachment/);
  assert.match(send, /if\(pendingUploadPath\).*?remove\(\[pendingUploadPath\]\)/s);
  assert.match(customerSchema, /p_storage_path not like v_user_id::text \|\| '\/' \|\| p_complaint_id::text \|\| '\/%'/);
  assert.match(customerSchema, /o\.bucket_id='srk-customer-support'[\s\S]*?o\.owner_id=v_user_id::text/);
  assert.match(customerSchema, /p_file_size_bytes not between 1 and 10485760/);
});

test('customer attachment listing checks complaint ownership and client creates short-lived private signed URLs', () => {
  const load = functionBody(customer, 'loadCustomerSupportAttachments');
  assert.match(load, /srk_customer_list_complaint_message_attachments/);
  assert.match(load, /createSignedUrl\(a\.storage_path,300\)/);
  assert.match(customerAttachments, /where c\.id=p_complaint_id and c\.customer_user_id=v_user_id/);
  assert.match(customerSchema, /values\('srk-customer-support','srk-customer-support',false,10485760/);
  assert.match(customer, /link\.rel='noopener noreferrer'/);
  assert.match(customer, /body\.textContent=row\.body\|\|''/);
});

test('electrician support client creates, lists, opens and replies through self-service RPCs', () => {
  const create = functionBody(electrician, 'createElectricianSupportTicket');
  const open = functionBody(electrician, 'openElectricianSupportThread');
  const reply = functionBody(electrician, 'sendElectricianSupportReply');
  const list = functionBody(electrician, 'loadElectricianSupportTickets');
  assert.match(create, /srk_electrician_create_support_ticket/);
  assert.match(list, /srk_electrician_list_my_support_tickets/);
  assert.match(open, /srk_electrician_list_my_support_messages/);
  assert.match(open, /request!==electricianSupportThreadRequest/);
  assert.match(reply, /srk_electrician_send_support_message/);
  assert.match(reply, /await openElectricianSupportThread\(ticketId\)/);
  assert.match(open, /esc\(m\.body\)/);
  assert.match(list, /esc\(t\.subject\)/);
  const clearStart=electrician.indexOf('function clearElectricianAccountView()');
  const clearEnd=electrician.indexOf('\nfunction init()',clearStart);
  assert.ok(clearStart>=0&&clearEnd>clearStart,'account reset handler exists');
  const clear=electrician.slice(clearStart,clearEnd);
  assert.match(clear,/electricianSupportThreadRequest\+\+/);
  assert.match(clear,/electricianSupportSelectedId=null/);
  assert.match(clear,/electricianSupportReplyBusy=false/);
  assert.match(create,/const requestedUserId=user\.id,requestedProfileId=profile\.id,requestedGeneration=electricianAccountViewGeneration/);
  assert.match(create,/if\(!isCurrent\(\)\)return/);
  assert.match(open,/requestedGeneration=electricianAccountViewGeneration/);
  assert.match(open,/if\(!isCurrent\(\)\|\|request!==electricianSupportThreadRequest/);
  assert.match(reply,/const requestedUserId=user\.id,requestedProfileId=profile\.id,requestedGeneration=electricianAccountViewGeneration/);
  assert.match(reply,/if\(!isCurrent\(\)\)return/);
  assert.match(reply, /finally\{\s*if\(isCurrent\(\)\)\s*\{\s*electricianSupportReplyBusy=false;/);
});

test('electrician support backend scopes tickets to authenticated owner and rejects closed-ticket replies', () => {
  assert.match(electricianSchema, /from public\.srk_electrician_support_tickets t where t\.user_id=v_uid[\s\S]*?order by t\.updated_at desc/);
  assert.match(electricianSchema, /where t\.id=p_ticket_id and t\.user_id=v_uid/);
  assert.match(electricianSchema, /if v_status='closed' then raise exception 'TICKET_CLOSED'/);
  assert.match(electricianSchema, /where b\.id=p_booking_id and b\.assigned_electrician_id=v_profile\.id/);
  assert.match(electricianSchema, /public\.is_srk_admin\(\)/);
  assert.match(electricianSchema, /grant execute on function public\.srk_electrician_create_support_ticket\(text,text,text,uuid\) to authenticated/i);
});

test('customer and electrician support UI validate message length and prevent duplicate sends', () => {
  const customerSend = functionBody(customer, 'sendCustomerSupportMessage');
  const electricianReply = functionBody(electrician, 'sendElectricianSupportReply');
  assert.match(customerSend, /customerSupportSendBusy/);
  assert.match(customerSend, /body\.length>4000/);
  assert.match(electricianReply, /electricianSupportReplyBusy/);
  assert.match(electricianReply, /body\.length>4000/);
});


test('customer support thread transport failure does not reject the complaint list refresh', () => {
  const list = functionBody(customer, 'loadCustomerSupportComplaints');
  const thread = functionBody(customer, 'loadCustomerSupportMessages');
  assert.match(list, /if\(customerSupportSelectedId\)await loadCustomerSupportMessages\(\)/);
  assert.match(thread, /Promise\.resolve\(\)\.then\(\(\)=>customerSb\.rpc\('srk_customer_list_booking_complaint_messages'/);
  assert.match(thread, /\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(thread, /if\(messageResult\.error\)\{supportStatus\('बातचीत लोड नहीं हो सकी। शिकायत सूची उपलब्ध है/);
  assert.match(thread, /if\(!isCurrent\(\)\|\|request!==customerSupportThreadRequest\|\|id!==customerSupportSelectedId\)return/);
});


test('customer support attachment cleanup re-reads authoritative links before deleting after an uncertain link result', () => {
  const send = functionBody(customer, 'sendCustomerSupportMessage');
  assert.match(send, /srk_customer_list_complaint_message_attachments/);
  assert.match(send, /safeToRemovePendingUpload=!linkedAttachments\.some\(row=>row\.storage_path===pendingUploadPath\)/);
  assert.match(send, /if\(safeToRemovePendingUpload\)await customerSb\.storage\.from\('srk-customer-support'\)\.remove\(\[pendingUploadPath\]\)/);
  assert.match(send, /if\(!lookupError&&Array\.isArray\(linkedAttachments\)\)/);
});


test('customer complaint submission reconciles an uncertain RPC result through the owner-scoped complaint list', () => {
  const create = functionBody(customer, 'createCustomerSupportComplaint');
  assert.match(create, /srk_customer_create_booking_complaint/);
  assert.match(create, /srk_customer_list_booking_complaints/);
  assert.match(create, /complaints\.find\(row=>row\.booking_id===bookingId&&row\.category===category&&row\.description===description\)/);
  assert.match(create, /customerSupportSelectedId=confirmedComplaint\.id/);
  assert.match(create, /दोबारा शिकायत नहीं भेजी गई/);
  assert.match(create, /lookupSucceeded/);
  assert.doesNotMatch(create,/catch[\s\S]*?customerSb\.rpc\('srk_customer_create_booking_complaint'/);
});

test('customer support lists, threads and writes are invalidated when the OTP account changes', () => {
  const resetStart = customer.indexOf('function clearCustomerSupportView()');
  const resetEnd = customer.indexOf('\nfunction renderCustomerSupportThread', resetStart);
  assert.ok(resetStart >= 0 && resetEnd > resetStart, 'customer support reset handler exists');
  const reset = customer.slice(resetStart, resetEnd);
  const create = functionBody(customer, 'createCustomerSupportComplaint');
  const list = functionBody(customer, 'loadCustomerSupportComplaints');
  const thread = functionBody(customer, 'loadCustomerSupportMessages');
  const send = functionBody(customer, 'sendCustomerSupportMessage');
  const authStart = customer.indexOf('customerSb.auth.onAuthStateChange');
  const authEnd = customer.indexOf('setTimeout(syncCustomerSession, 0);', authStart);
  assert.ok(authStart >= 0 && authEnd > authStart, 'customer auth-change handler exists');
  const authHandler = customer.slice(authStart, authEnd);
  assert.match(reset, /customerSupportGeneration\+\+/);
  assert.match(reset, /customerSupportThreadRequest\+\+/);
  assert.match(reset, /customerSupportComplaints=\[\];customerSupportSelectedId=null;customerSupportAttachments=\[\]/);
  assert.match(authHandler, /clearCustomerSupportView\(\)/);
  assert.match(create, /const request=customerSupportGeneration,isCurrent=\(\)=>request===customerSupportGeneration/);
  assert.match(create, /if\(!isCurrent\(\)\)return/);
  assert.match(create, /finally \{if\(isCurrent\(\)\)/);
  assert.match(list, /const request=customerSupportGeneration,isCurrent=\(\)=>request===customerSupportGeneration/);
  assert.match(list, /if\(!isCurrent\(\)\)return/);
  assert.match(thread, /const generation=customerSupportGeneration,isCurrent=\(\)=>generation===customerSupportGeneration/);
  assert.match(thread, /if\(!isCurrent\(\)\|\|request!==customerSupportThreadRequest/);
  assert.match(send, /const generation=customerSupportGeneration,isCurrent=\(\)=>generation===customerSupportGeneration/);
  assert.match(send, /if\(!isCurrent\(\)\)return/);
  assert.match(send, /finally\{if\(isCurrent\(\)\)/);
});

test('customer support booking options cannot leak across OTP account switches', () => {
  const load = functionBody(customer, 'loadCustomerSupportBookings');
  const resetStart = customer.indexOf('function clearCustomerSupportView()');
  const resetEnd = customer.indexOf('\nfunction renderCustomerSupportThread', resetStart);
  assert.ok(resetStart >= 0 && resetEnd > resetStart);
  const reset = customer.slice(resetStart, resetEnd);
  assert.match(load, /const request=customerSupportGeneration,isCurrent=\(\)=>request===customerSupportGeneration/);
  assert.match(load, /if\(!isCurrent\(\)\)return/g);
  assert.match(load, /finally \{if\(isCurrent\(\)\)select\.disabled=false;\}/);
  assert.match(reset, /booking\.disabled=false/);
});

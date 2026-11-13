const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('admin.html', 'utf8');

test('Admin panel has navigable anchors for its existing operational sections', () => {
  const navStart = html.indexOf('<nav class="admin-menu"');
  const navEnd = html.indexOf('</nav>', navStart);
  assert.ok(navStart >= 0 && navEnd > navStart);
  const nav = html.slice(navStart, navEnd + 6);
  for (const id of ['adminOverview','adminBookings','adminApplications','adminElectricians','skillMatchingAdmin','adminFinance','adminWallet','adminPlatformFee','adminSupportPanel','adminFinanceDashboard','adminStaff']) {
    assert.ok(nav.includes('href="#' + id + '"'), 'missing Admin navigation target: ' + id);
    assert.equal((html.match(new RegExp('id="' + id + '"','g'))||[]).length, 1, 'target must be unique: ' + id);
  }
});

test('Admin access still requires server-side Main Admin allow-list check', () => {
  assert.ok(html.includes("sb.rpc('is_srk_admin')"));
  assert.ok(html.includes("if(error||data!==true)"));
  assert.ok(html.includes("await sb.auth.signOut()"));
});

test('Staff management is not falsely exposed before role, permission and RLS implementation', () => {
  assert.ok(html.includes('Authorized Staff Management अभी लागू नहीं है।'));
  assert.ok(html.includes('View / Add / Edit / Manage permissions'));
  assert.ok(html.includes('कोई Staff account जोड़ने, अनुमति देने या staff login करने का control सक्रिय नहीं है।'));
  assert.ok(!html.includes('srk_admin_create_staff'));
  assert.ok(!html.includes('srk_admin_grant_staff_permission'));
});

test('Admin inline JavaScript parses after navigation changes', () => {
  const start = html.lastIndexOf('<script>');
  const end = html.lastIndexOf('</script>');
  assert.ok(start >= 0 && end > start);
  assert.doesNotThrow(() => new vm.Script(html.slice(start + 8, end)));
});

test('Admin booking/location and electrician activation mutations use existing server RPCs, not direct table updates', () => {
  assert.ok(html.includes("sb.rpc('srk_admin_update_booking'"));
  assert.ok(html.includes("sb.rpc('srk_admin_set_electrician_active'"));
  assert.ok(!html.includes("sb.from('service_bookings').update("));
  assert.ok(!html.includes("sb.from('electrician_profiles').update("));
  assert.ok(html.includes("sb.rpc('srk_admin_record_manual_payment'"));
});

test('legacy booking amount is read-only while workflow status remains server-validated', () => {
  assert.ok(html.includes('पुरानी बुकिंग राशि (Read-only)'));
  assert.ok(html.includes('title="ऐतिहासिक राशि सुरक्षित रखने के लिए संपादन बंद है" disabled'));
  assert.ok(html.includes("p_status:status"));
  assert.ok(html.includes("p_address:booking.address"));
});

test('Admin Finance UI reads server summary and private expense history through Admin RPCs', () => {
  assert.ok(html.includes("sb.rpc('srk_admin_finance_dashboard'"));
  assert.ok(html.includes("sb.rpc('srk_admin_finance_list_expenses'"));
  assert.ok(html.includes("sb.rpc('srk_admin_finance_add_expense'"));
  assert.ok(html.includes('id="financeExpenseRows"'));
  assert.ok(html.includes('id="expenseAmount"'));
});

test('Admin Finance UI labels preliminary net result honestly and does not claim receipt upload exists', () => {
  assert.ok(html.includes('preliminary indicator'));
  assert.ok(html.includes('इसे audited final P&amp;L न मानें'));
  assert.ok(html.includes('अभी receipt/document upload नहीं है'));
  assert.ok(!html.includes('expenseReceiptUpload'));
});

test('Admin Finance expense form validates amounts and requires confirmation before ledger write', () => {
  assert.ok(html.includes('amount<=0||amount>100000000'));
  assert.ok(html.includes("if(!confirm('क्या यह वास्तविक कंपनी खर्च है"));
  assert.ok(html.includes("p_amount:amount"));
});

test('Admin Finance report does not conflate legacy commission with reconciled Platform Fee or settled payout', () => {
  assert.ok(html.includes('legacy commission और नई Platform Fee का पूर्ण अलग-अलग reconciliation'));
  assert.ok(html.includes('Recorded Commission (legacy/new split pending)'));
  assert.ok(html.includes('Electrician Share (settlement नहीं)'));
  assert.ok(html.includes('Period में बने Pending Payout'));
});

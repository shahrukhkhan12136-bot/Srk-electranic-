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
  for (const id of ['adminOverview','adminBookings','adminApplications','adminElectricians','adminVerificationDocuments','skillMatchingAdmin','adminFinance','adminWallet','adminPlatformFee','adminSupportPanel','adminFinanceDashboard','adminStaff']) {
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

test('Admin KYC panel lists private electrician documents, signs short-lived links and records review decisions', () => {
  assert.ok(html.includes('id="adminVerificationDocuments"'));
  assert.ok(html.includes('srk_admin_list_electrician_verification_documents'));
  assert.ok(html.includes("createSignedUrl(path,60)"));
  assert.ok(html.includes("srk_admin_review_electrician_document"));
  assert.ok(html.includes("status==='rejected'"));
  assert.ok(html.includes('needs_resubmission'));
  assert.ok(html.includes('window.srkVerificationDocumentPaths'));
  assert.ok(html.includes("await Promise.all([loadSkillMatchingConfig(),loadAdminVerificationDocuments()])"));
});
test('Admin KYC file access uses signed URLs rather than public object URLs', () => {
  assert.ok(html.includes("from('srk-electrician-verification').createSignedUrl"));
  assert.ok(!html.includes('getPublicUrl(path)'));
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

test('Admin Razorpay settlement panel is navigable and shows provider fee, tax, net and bank evidence separately', () => {
  assert.ok(html.includes('id="adminRazorpaySettlements"'));
  assert.ok(html.includes('href="#adminRazorpaySettlements"'));
  assert.ok(html.includes('id="settlementFrom"'));
  assert.ok(html.includes('id="settlementTo"'));
  assert.ok(html.includes('id="razorpaySettlementRows"'));
  assert.ok(html.includes('fee_amount_paise'));
  assert.ok(html.includes('tax_amount_paise'));
  assert.ok(html.includes('provider_net_amount_paise'));
  assert.ok(html.includes('bank_credit_amount_paise'));
  assert.ok(html.includes('Bank UTR / Reference'));
});

test('Admin settlement import sends only the signed-in Admin JWT and a bounded date range to the Netlify function', () => {
  assert.ok(html.includes("fetch('/.netlify/functions/razorpay-settlement-sync'"));
  assert.ok(html.includes("'Authorization':'Bearer '+session.access_token"));
  assert.ok(html.includes('end-start>90*86400'));
  assert.ok(html.includes('await loadRazorpaySettlements()'));
  assert.ok(!html.includes('SUPABASE_SERVICE_ROLE_KEY'));
  assert.ok(!html.includes('RAZORPAY_KEY_SECRET'));
});

test('Admin bank reconciliation calls the protected RPC with exact paise and requires confirmation and note', () => {
  assert.ok(html.includes("sb.rpc('srk_admin_reconcile_razorpay_settlement'"));
  assert.ok(html.includes('p_bank_credit_amount_paise:Math.round(amount*100)'));
  assert.ok(html.includes('p_bank_credit_at:new Date(at).toISOString()'));
  assert.ok(html.includes('p_bank_reference:reference'));
  assert.ok(html.includes('p_reconciliation_status:status'));
  assert.ok(html.includes('p_note:note'));
  assert.ok(html.includes("if(!confirm('क्या आपने Bank Statement"));
  assert.ok(html.includes('note.length<10'));
});

test('Admin settlement table is read-only and does not directly mutate reconciliation tables', () => {
  assert.ok(html.includes("sb.from('srk_razorpay_settlements').select("));
  assert.ok(!html.includes("sb.from('srk_razorpay_settlements').update("));
  assert.ok(!html.includes("sb.from('srk_razorpay_settlement_items').insert("));
  assert.ok(html.includes("reconciliation_note,provider_created_at"));
});

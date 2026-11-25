import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
import 'worker_rate_card.dart';
import 'worker_application_and_work_session.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSrkSupabase();
  runApp(const ElectricianApp());
}

class ElectricianApp extends StatelessWidget {
  const ElectricianApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SRK ELECTRONIC', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E8B)), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF4F7FB)),
    home: const ElectricianGate(),
  );
}

class ElectricianGate extends StatelessWidget {
  const ElectricianGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) => (snapshot.data?.session ?? Supabase.instance.client.auth.currentSession) == null
      ? const ElectricianLoginPage() : const ElectricianDashboard(),
  );
}

class ElectricianLoginPage extends StatefulWidget {
  const ElectricianLoginPage({super.key});
  @override
  State<ElectricianLoginPage> createState() => _ElectricianLoginPageState();
}
class _ElectricianLoginPageState extends State<ElectricianLoginPage> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  bool sent = false, busy = false;
  String? message;
  @override
  void dispose() { phone.dispose(); otp.dispose(); super.dispose(); }
  String? get normalizedPhone {
    final raw = phone.text.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91' + digits;
    if (raw.startsWith('+') && digits.length >= 10 && digits.length <= 15) return '+' + digits;
    return null;
  }
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try { await action(); }
    on AuthException catch (e) { if (mounted) setState(() => message = e.message); }
    catch (_) { if (mounted) setState(() => message = 'अभी प्रक्रिया पूरी नहीं हुई। कृपया फिर कोशिश करें।'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> sendOtp() async {
    final p = normalizedPhone;
    if (p == null) { setState(() => message = 'सही 10 अंकों का रजिस्टर्ड मोबाइल नंबर दर्ज करें।'); return; }
    await run(() async {
      await Supabase.instance.client.auth.signInWithOtp(phone: p);
      if (mounted) setState(() { sent = true; message = 'OTP भेजा गया है। OTP किसी से साझा न करें।'; });
    });
  }
  Future<void> verifyOtp() async {
    final p = normalizedPhone, token = otp.text.trim();
    final validOtp = token.length >= 4 && token.length <= 8 && token.codeUnits.every((unit) => unit >= 48 && unit <= 57);
    if (p == null || !validOtp) { setState(() => message = 'सही मोबाइल नंबर और SMS OTP दर्ज करें।'); return; }
    await run(() async { await Supabase.instance.client.auth.verifyOTP(phone: p, token: token, type: OtpType.sms); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SRK ELECTRONIC — Technician')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SrkWelcomeHeader(),
          Text('टेक्नीशियन लॉगिन', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'रजिस्टर्ड मोबाइल नंबर')),
          if (sent) ...[const SizedBox(height: 12), TextField(controller: otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SMS OTP'))],
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : (sent ? verifyOtp : sendOtp), child: Text(busy ? 'कृपया प्रतीक्षा करें…' : (sent ? 'OTP सत्यापित करें' : 'OTP भेजें'))),
          if (sent) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: busy ? null : sendOtp, child: const Text('OTP दोबारा भेजें')),
            TextButton(onPressed: busy ? null : () => setState(() { sent = false; otp.clear(); message = 'मोबाइल नंबर जाँचें और OTP फिर से भेजें।'; }), child: const Text('मोबाइल नंबर बदलें')),
          ],
          const Text('लॉगिन के लिए आवेदन में दर्ज रजिस्टर्ड नंबर का OTP सत्यापन जरूरी है।', textAlign: TextAlign.center),
          if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, textAlign: TextAlign.center)),
        ],
      ))),
    ))),
  );
}

class ElectricianDashboard extends StatefulWidget {
  const ElectricianDashboard({super.key});
  @override
  State<ElectricianDashboard> createState() => _ElectricianDashboardState();
}
class _ElectricianDashboardState extends State<ElectricianDashboard> {
  final client = Supabase.instance.client;
  final upiController = TextEditingController();
  Map<String, dynamic>? profile, wallet, paymentCycle;
  List<Map<String, dynamic>> rateCardCategories = [];
  List<Map<String, dynamic>> payoutRequests = [];
  List<Map<String, dynamic>> applicationRows = [];
  List<Map<String, dynamic>> offers = [], offerDetails = [], earnings = [], offerPriceDetails = [], bookingDetails = [];
  bool loading = true;
  String? error;
  List<String> loadWarnings = [];
  int _selectedNavIndex = 0;
  final ScrollController _dashboardScrollController = ScrollController();
  final GlobalKey _offersKey = GlobalKey();
  final GlobalKey _workKey = GlobalKey();
  final GlobalKey _earningsKey = GlobalKey();
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { upiController.dispose(); _dashboardScrollController.dispose(); super.dispose(); }

  Future<void> _goToSection(int index, GlobalKey? key) async {
    setState(() => _selectedNavIndex = index);
    if (key == null) {
      if (_dashboardScrollController.hasClients) await _dashboardScrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      return;
    }
    final target = key.currentContext;
    if (target != null) await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<void> _showWorkerProfile() async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('मेरी प्रोफाइल', style: Theme.of(ctx).textTheme.titleLarge),
        ListTile(leading: const Icon(Icons.person_outline), title: Text(profile?['display_name']?.toString() ?? 'प्रोफाइल लिंक नहीं हुई'), subtitle: Text(profile?['worker_type']?.toString() ?? 'Technician / Helper')),
        ListTile(leading: const Icon(Icons.location_on_outlined), title: Text('${profile?['district'] ?? '—'}, ${profile?['state'] ?? '—'}'), subtitle: Text('PIN ${profile?['pincode'] ?? '—'}')),
        FilledButton.icon(onPressed: () { Navigator.pop(ctx); _sendSos(); }, icon: const Icon(Icons.sos), label: const Text('Emergency SOS')),
      ]),
    )));
    if (mounted) setState(() => _selectedNavIndex = 0);
  }
  Future<void> requestAccountDeletion() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Deletion Request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Request का कारण (वैकल्पिक)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Request भेजें')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      await client.rpc('srk_request_account_deletion', params: {'p_reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account deletion request Admin समीक्षा के लिए भेजी गई। Account अभी delete नहीं हुआ है।'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Request नहीं भेजी गई: ' + e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; loadWarnings = []; });
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Session expired');

      final workerRow = await client.from('srk_worker_profiles')
          .select('id,worker_type,full_name,phone,state,district,pincode,is_active,verification_status,is_online,category_id,upi_id,pending_upi_id,payout_details_change_status')
          .eq('user_id', uid)
          .maybeSingle();

      if (workerRow == null) {
        try {
          final rows = await client.from('srk_worker_applications')
              .select('id,worker_type,category_id,full_name,status,admin_note,created_at,updated_at')
              .eq('user_id', uid).order('created_at', ascending: false);
          applicationRows = List<Map<String, dynamic>>.from(rows);
        } catch (_) {
          applicationRows = [];
          loadWarnings.add('आपके Registration आवेदन की स्थिति अभी लोड नहीं हुई। Refresh करें।');
        }
        profile = null;
        offers = [];
        offerDetails = [];
        earnings = [];
        offerPriceDetails = [];
        bookingDetails = [];
        wallet = null;
        paymentCycle = null;
        rateCardCategories = [];
        payoutRequests = [];
        return;
      }

      profile = {
        ...Map<String, dynamic>.from(workerRow),
        'display_name': workerRow['full_name'],
        'active': workerRow['is_active'],
      };

      try {
        final cycleRows = await client.rpc('srk_worker_get_my_payment_cycle');
        final rows = List<Map<String, dynamic>>.from(cycleRows as List);
        paymentCycle = rows.isEmpty ? null : rows.first;
      } catch (_) {
        paymentCycle = null;
        loadWarnings.add('अगले काम की भुगतान स्थिति अभी लोड नहीं हो पाई। कृपया Refresh करें।');
      }

      try {
        final rateCardResult = await client.rpc('srk_worker_get_my_rate_card');
        rateCardCategories = List<Map<String, dynamic>>.from(rateCardResult as List);
      } catch (_) {
        rateCardCategories = [];
        loadWarnings.add('छहों कैटेगरी की आपकी रेट सूची अभी लोड नहीं हो पाई। Refresh करके फिर कोशिश करें।');
      }

      final assignmentRows = await client.rpc('srk_worker_get_my_assignments');
      final assignments = List<Map<String, dynamic>>.from(assignmentRows as List);

      final contactRows = await client.rpc('srk_worker_get_my_booking_customer_contacts');
      final customerPhones = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(contactRows as List)) {
        final phone = row['customer_phone']?.toString().trim() ?? '';
        if (phone.isNotEmpty) customerPhones[row['booking_id'].toString()] = phone;
      }

      offers = assignments.map((a) => {
        'id': a['assignment_id'],
        'assignment_id': a['assignment_id'],
        'offer_id': a['assignment_id'],
        'status': a['assignment_status'] == 'rejected' ? 'declined' : a['assignment_status'],
      }).toList();

      offerDetails = assignments
          .where((a) => a['assignment_status'] == 'offered')
          .map((a) => {
            ...a,
            'offer_status': a['assignment_status'],
            'booking_id': a['booking_id'],
            'service_type': a['service_type'],
            'match_level': 'district',
            'work_details': a['work_details'],
          }).toList();

      bookingDetails = assignments
          .where((a) => ['accepted','assigned','working','paused','completed'].contains(a['assignment_status']))
          .map((a) {
            final bookingStatus = a['booking_status']?.toString();
            final normalizedStatus = bookingStatus == 'confirmed' || bookingStatus == 'new'
                ? 'assigned'
                : bookingStatus;
            final phone = customerPhones[a['booking_id'].toString()];
            return {
              ...a,
              'booking_status': normalizedStatus,
              'service_charge': a['service_charge'],
              'quoted_amount': a['quoted_amount'] ?? a['final_bill_total'],
              'quote_note': a['quote_note'],
              'location_lat': a['booking_latitude'],
              'location_lng': a['booking_longitude'],
              if (phone != null) 'customer_phone': phone,
            };
          }).toList();

      offerPriceDetails = assignments
          .where((a) => a['service_charge'] != null)
          .map((a) => {
            'booking_id': a['booking_id'],
            'service_charge': a['service_charge'],
            'quote_status': a['quote_status'],
            'quote_note': a['quote_note'],
            'electrician_quote_kind': 'labour_quote',
          }).toList();

      try {
        final earningRows = await client.rpc('srk_worker_get_my_earnings');
        earnings = List<Map<String, dynamic>>.from(earningRows as List).map((row) => {
          ...row,
          'electrician_earning': row['net_earning'],
        }).toList();
      } catch (_) {
        earnings = [];
        loadWarnings.add('कमाई का विवरण अभी लोड नहीं हो पाया। Refresh करके फिर कोशिश करें।');
      }

      try {
        final walletResult = await client.rpc('srk_worker_get_my_wallet_summary');
        final walletData = Map<String, dynamic>.from(walletResult as Map);
        wallet = {
          'balance': walletData['available_for_payout'] ?? 0,
          ...walletData,
        };
      } catch (_) {
        wallet = null;
        loadWarnings.add('वॉलेट का बैलेंस अभी लोड नहीं हो पाया। Refresh करके फिर कोशिश करें।');
      }

      try {
        final payoutRows = await client.rpc('srk_worker_get_my_payout_requests');
        payoutRequests = List<Map<String, dynamic>>.from(payoutRows as List);
      } catch (_) {
        payoutRequests = [];
        loadWarnings.add('पेआउट रिक्वेस्ट की स्थिति अभी लोड नहीं हो पाई। Refresh करके फिर कोशिश करें।');
      }
    } catch (_) {
      error = 'टेक्नीशियन डैशबोर्ड लोड नहीं हो सका। आवश्यक Worker API migration लागू होने और इंटरनेट की जाँच करें।';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }




  double _number(dynamic value) => value is num ? value.toDouble() : (double.tryParse(value?.toString() ?? '') ?? 0);
  String _money(dynamic value) => '₹' + _number(value).toStringAsFixed(2);

  Future<void> createDynamicQr(Map<String, dynamic> bill) async {
    final bookingId = bill['booking_id']?.toString();
    final finalBillId = bill['final_bill_id']?.toString();
    if (bookingId == null || bookingId.isEmpty || finalBillId == null || finalBillId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('इस बुकिंग का Final Bill ID उपलब्ध नहीं है।')),
      );
      return;
    }
    try {
      final result = await client.functions.invoke(
        'create-razorpay-dynamic-qr',
        body: {
          'booking_id': bookingId,
          'final_bill_id': finalBillId,
          'idempotency_key': 'srk-qr-$bookingId-$finalBillId',
        },
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      final imageUrl = data['image_url']?.toString() ?? '';
      if (data['success'] != true || !imageUrl.startsWith('https://')) {
        final status = data['status']?.toString() ?? data['error']?.toString() ?? 'QR अभी तैयार नहीं हुआ।';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'RECONCILIATION_REQUIRED'
            ? 'QR Provider स्थिति जाँची जा रही है। कुछ देर बाद Refresh करें।'
            : 'Dynamic QR नहीं बना: $status')),
        );
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Customer On-site UPI QR'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Final Bill: ' + (bill['bill_number']?.toString() ?? bookingId)),
                const SizedBox(height: 8),
                Text('भुगतान राशि: ' + _money(bill['bill_total']),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Image.network(imageUrl, width: 260, height: 260,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('QR Image लोड नहीं हुई। Refresh करके फिर कोशिश करें।')),
                const SizedBox(height: 8),
                const Text('यह QR केवल इसी Final Bill के लिए है। भुगतान Razorpay Merchant Account में जाएगा।'),
                if (data['short_url']?.toString().isNotEmpty == true)
                  SelectableText(data['short_url'].toString()),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करें'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dynamic QR तैयार नहीं हुआ: ' + e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> openFinancialDetails(Map<String, dynamic> earning) async {
    final bookingId = earning['booking_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;
    try {
      final result = await client.rpc('srk_worker_get_my_booking_financial_details', params: {'p_booking_id': bookingId});
      final d = Map<String, dynamic>.from(result as Map);
      if (!mounted) return;
      final isCash = d['payment_method'] == 'cash';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('पूरा बिल और कमाई — ' + (d['bill_number']?.toString() ?? bookingId)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ग्राहक का कुल बिल: ' + _money(d['bill_total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('ग्राहक ने वास्तव में दिया: ' + _money(d['customer_paid_amount'])),
                Text('भुगतान तरीका: ' + (isCash ? 'Cash' : 'Online')),
                const Divider(),
                Text('कुल लेबर बिल: ' + _money(d['labour_total'])),
                Text('कंपनी प्रतिशत: ' + ((d['commission_rate'] as num?)?.toStringAsFixed(2) ?? '0.00') + '%'),
                Text('कंपनी का कुल हिस्सा: ' + _money(d['company_commission_total'])),
                Text('सभी Workers की कुल कमाई: ' + _money(d['worker_earnings_total'])),
                const Divider(),
                Text('आपका कुल Labour हिस्सा: ' + _money(d['my_gross_allocation'])),
                Text('आपकी कमाई में कंपनी का हिस्सा: ' + _money(d['my_company_commission'])),
                Text('आपकी 85% कमाई: ' + _money(d['my_net_earning']), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (isCash) ...[
                  Text('आपको ग्राहक से नकद मिला: ' + _money(d['my_net_earning'])),
                  Text('कंपनी को Wallet में देना बाकी: −' + _money(d['my_cash_commission_due'])),
                ] else ...[
                  Text('आपके Wallet में जमा: ' + _money(d['my_wallet_credit'])),
                  if (_number(d['my_cash_commission_recovered']) > 0)
                    Text('पुराना Cash कमीशन इस Online कमाई से समायोजित: ' + _money(d['my_cash_commission_recovered'])),
                ],
                Text('कंपनी का कुल Cash बकाया: ' + _money(d['cash_commission_outstanding'])),
                Text('भुगतान स्थिति: ' + (d['payment_status']?.toString() ?? '—')),
                const Divider(),
                const Text('बिल के आइटम', style: TextStyle(fontWeight: FontWeight.bold)),
                ...List<Map<String, dynamic>>.from(d['bill_items'] as List? ?? const []).map((item) =>
                  Padding(padding: const EdgeInsets.only(top: 5), child: Text(
                    (item['description']?.toString() ?? item['item_type']?.toString() ?? 'सेवा') +
                    ' — ' + _money(item['line_total'])
                  ))
                ),
              ],
            )),
          ),
          actions: [
            if (!isCash && d['payment_status'] != 'paid' && d['bill_status'] == 'issued')
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  createDynamicQr(d);
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('On-site QR बनाएँ'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करें')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('पूरा बिल नहीं खुल सका। Refresh करके फिर कोशिश करें।')));
    }
  }

  Future<void> updatePayoutUpi() async {
    upiController.text = (profile?['pending_upi_id'] ?? profile?['upi_id'] ?? '').toString();
    final upi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payout के लिए UPI ID'),
        content: TextField(
          controller: upiController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'आपकी UPI ID', hintText: 'name@bank'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          FilledButton(onPressed: () => Navigator.pop(ctx, upiController.text.trim()), child: const Text('सत्यापन के लिए भेजें')),
        ],
      ),
    );
    if (upi == null) return;
    final parts = upi.split('@');
    if (parts.length != 2 || parts[0].length < 2 || parts[1].length < 2 ||
        upi.contains(' ') || parts[1].contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('सही UPI ID दर्ज करें। उदाहरण: name@bank')));
      return;
    }
    try {
      await client.rpc('srk_worker_update_payout_details', params: {
        'p_upi_id': upi,
        'p_bank_account_last4': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID Main Admin के सत्यापन के लिए भेज दी गई।')));
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID भेजी नहीं जा सकी। सही UPI ID और लॉगिन जाँचें।')));
    }
  }

  Future<void> requestAvailablePayout() async {
    final amount = (wallet?['available_for_payout'] as num?)?.toDouble() ?? 0;
    if (amount <= 0 || wallet?['payout_blocked'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('अभी Payout के लिए उपलब्ध रकम नहीं है या कमाई समीक्षा में रुकी हुई है।')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payout Request भेजें?'),
        content: Text('आपकी उपलब्ध रकम ' + _money(amount) + ' का Payout Request Admin को भेजा जाएगा। Admin सत्यापन और वास्तविक बैंक/UPI भुगतान के बाद UTR दर्ज करेगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('अभी नहीं')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request भेजें')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await client.rpc('srk_worker_request_payout', params: {'p_amount': amount});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout Request Admin को भेज दी गई।')));
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout Request नहीं भेजी गई। उपलब्ध Wallet रकम और बैंक/UPI विवरण जाँचें।')));
    }
  }

  Future<void> openBookingMap(Map<String,dynamic> booking) async {
    final lat=booking['location_lat'], lng=booking['location_lng'];
    final query=lat is num && lng is num ? '${lat.toString()},${lng.toString()}' :
      '${booking['address'] ?? ''}, ${booking['district'] ?? ''}, ${booking['state'] ?? ''} ${booking['pincode'] ?? ''}';
    if(query.trim().isEmpty)return;
    final uri=Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri,mode:LaunchMode.externalApplication);
  }

  String bookingStatusLabel(String? status) => switch (status) {
    'assigned' => 'टेक्नीशियन नियुक्त',
    'inspection' => 'जाँच / निरीक्षण',
    'awaiting_quote_approval' => 'ग्राहक की कोटेशन मंजूरी बाकी',
    'quote_approved' => 'कोटेशन मंजूर',
    'quote_rejected' => 'ग्राहक ने कोटेशन में बदलाव माँगा',
    'in_progress' => 'काम जारी',
    'completed' => 'काम पूरा',
    _ => status ?? 'स्थिति उपलब्ध नहीं',
  };

  Future<void> sendSos() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 तत्काल सहायता'),
        content: const Text('यदि काम के दौरान आपको खतरा है, कारण चुनें। यह अलर्ट SRK Admin के in-app SOS नियंत्रण कक्ष में जाएगा। SMS/Police को स्वतः कॉल या संदेश नहीं जाएगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'customer_at_risk'), child: const Text('Customer से खतरा')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'electrician_at_risk'), child: const Text('मुझे खतरा है')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'violence_or_other_emergency'), child: const Text('मारपीट / अन्य आपात स्थिति')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      final result = await Supabase.instance.client.rpc('srk_create_sos_alert', params: {'p_reason': reason});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result as Map);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['created'] == true
          ? 'SOS Admin नियंत्रण कक्ष में दर्ज हुआ। केस: ${data['case_id']}'
          : 'आपका SOS पहले से लंबित है। केस: ${data['case_id']}'),
        duration: const Duration(seconds: 8),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('SOS दर्ज नहीं हुआ: ' + e.toString().replaceFirst('Exception: ', '')),
        duration: const Duration(seconds: 8),
      ));
    }
  }

  Future<void> respondToOffer(Map<String, dynamic> offer, String response) async {
    final accept = response == 'accepted';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accept ? 'बुकिंग ऑफर स्वीकार करें?' : 'बुकिंग ऑफर मना करें?'),
        content: Text(accept
          ? 'स्वीकार करते ही यह बुकिंग आपके नाम नियुक्त हो जाएगी। अन्य Technician के ऑफर बंद हो जाएँगे।'
          : 'यह ऑफर आपकी सूची से हट जाएगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('वापस')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(accept ? 'स्वीकार करें' : 'मना करें')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await client.rpc('srk_worker_respond_assignment', params: {
        'p_assignment_id': offer['assignment_id'], 'p_accept': accept,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? 'बुकिंग आपके नाम नियुक्त हो गई।' : 'ऑफर मना कर दिया गया।')));
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ऑफर अपडेट नहीं हुआ। संभव है बुकिंग किसी दूसरे Technician को मिल गई हो।')));
      await load();
    }
  }

  Future<void> proposeSchedule(Map<String, dynamic> booking) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!start.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('भविष्य का समय चुनें।')),
      );
      return;
    }
    final hours = (booking['requested_duration_hours'] as num?)?.toInt() ?? 1;
    final end = start.add(Duration(hours: hours < 1 ? 1 : hours));
    try {
      await client.rpc('srk_worker_propose_next_schedule', params: {
        'p_booking_worker_id': booking['assignment_id'],
        'p_start_at': start.toUtc().toIso8601String(),
        'p_end_at': end.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('समय का प्रस्ताव ग्राहक को मंजूरी के लिए भेज दिया गया।')),
      );
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('समय का प्रस्ताव नहीं भेजा गया। बुकिंग की स्थिति जाँचें।')),
      );
    }
  }

  Future<void> requestWorkStartApproval(String bookingWorkerId) async {
    try {
      await client.rpc('srk_worker_request_work_start_approval', params: {
        'p_booking_worker_id': bookingWorkerId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('काम शुरू करने की मंजूरी ग्राहक को भेज दी गई है।')),
      );
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('काम शुरू करने की मंजूरी नहीं भेजी गई। ग्राहक की कोटेशन मंजूरी जाँचें।')),
      );
    }
  }

  Future<void> openQuoteForm(Map<String, dynamic> booking) async {
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuoteSubmissionDialog(
        client: client,
        bookingId: booking['booking_id'].toString(),
      ),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कोटेशन ग्राहक को मंजूरी के लिए भेज दिया गया।')),
      );
      await load();
    }
  }

  int count(String status) => offers.where((o) => o['status'] == status).length;
  @override
  Widget build(BuildContext context) {
    final p = profile;
    final active = p?['verification_status'] == 'approved' && p?['active'] == true;
    final completed = earnings.where((e) => e['booking_status'] == 'completed').length;
    final paid = earnings.where((e) => e['booking_status'] == 'completed' && e['payment_status'] == 'paid');
    final earned = paid.fold<double>(0, (sum, row) => sum + (double.tryParse(row['electrician_earning']?.toString() ?? '0') ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('SRK ELECTRONIC'), actions: [
        TextButton.icon(onPressed: loading ? null : load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        PopupMenuButton<String>(tooltip: 'अधिक विकल्प', icon: const Icon(Icons.more_vert),
          onSelected: (value) { if (value == 'delete') requestAccountDeletion(); if (value == 'logout') client.auth.signOut(); },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'delete', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_remove_outlined), title: Text('Account Deletion Request'))),
            PopupMenuItem(value: 'logout', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout), title: Text('Logout'))),
          ],
        ),
      ]),
      body: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE4F7F8), Color(0xFFF8FCFF), Color(0xFFFFF3E6)])), child: Stack(children: [
        Positioned(top: 28, right: -48, child: Container(width: 160, height: 160, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x2220A6A6)))),
        Positioned(bottom: 65, left: -55, child: Container(width: 190, height: 190, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x22F5B544)))),
        RefreshIndicator(onRefresh: load, child: loading
        ? ListView(controller: _dashboardScrollController, children: const [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
        : ListView(controller: _dashboardScrollController, padding: const EdgeInsets.all(16), children: [
          const SrkFounderBanner(),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.red)))),
          ...loadWarnings.map((warning) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(warning)))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?['display_name']?.toString() ?? 'प्रोफाइल लिंक नहीं हुई', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (p == null) const Text('आवेदन अभी अप्रूव नहीं हुआ है या रजिस्टर्ड मोबाइल OTP से लिंक नहीं है। Admin से संपर्क करें।')
            else Text((p['district'] ?? '').toString() + ', ' + (p['state'] ?? '').toString() + ' • PIN ' + (p['pincode'] ?? '').toString()),
            if (p != null) Padding(padding: const EdgeInsets.only(top: 8), child: Chip(avatar: Icon(active ? Icons.verified : Icons.info_outline), label: Text(active ? 'Approved और Active' : 'Inactive / Approval बाकी'))),
          ]))),
          if (p != null && active && paymentCycle != null)
            Card(
              color: (paymentCycle!['next_booking_requires_online'] == true)
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('मेरा भुगतान चक्र', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('पूरे किए गए काम: ${paymentCycle!['completed_booking_count'] ?? 0}'),
                  Text('अगला काम क्रमांक: ${paymentCycle!['next_sequence_number'] ?? '—'}'),
                  const SizedBox(height: 4),
                  Text(paymentCycle!['next_booking_requires_online'] == true
                    ? 'इस क्रमांक पर केवल Online भुगतान स्वीकार होगा। Cash विकल्प सर्वर पर भी बंद रहेगा।'
                    : 'इस क्रमांक पर Cash या Online — दोनों भुगतान विकल्प उपलब्ध रहेंगे।'),
                ]),
              ),
            ),
          if (p == null) ...[
            if (applicationRows.isEmpty)
              WorkerApplicationPage(onSubmitted: load)
            else
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('आपके Registration आवेदन', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...applicationRows.map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text((a['worker_type'] == 'helper' ? 'Helper' : 'Technician') + ' • ' + (a['full_name']?.toString() ?? 'आवेदन')),
                    subtitle: Text('स्थिति: ' + ({'pending':'जाँच बाकी','under_review':'जाँच चल रही है','approved':'स्वीकृत','rejected':'अस्वीकृत','more_info':'अधिक जानकारी चाहिए','withdrawn':'वापस लिया गया'}[a['status']] ?? a['status'].toString()) + (a['admin_note']?.toString().isNotEmpty == true ? '\nAdmin: ' + a['admin_note'].toString() : '')),
                  )),
                  const Text('Admin की स्वीकृति और Worker Profile सक्रिय होने के बाद ही Booking Offers मिलेंगे।'),
                ],
              ))),
          ],
          if (p != null) WorkerRateCard(categories: rateCardCategories),
          if (p == null || !active)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p == null ? 'टेक्नीशियन आवेदन' : 'प्रोफाइल सत्यापन / एक्टिवेशन बाकी',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p == null
                        ? 'आपका डैशबोर्ड खुल गया है। सेवाएँ और काम देखने की सुविधा उपलब्ध रहेगी। आवेदन, अनिवार्य आधार सत्यापन और स्किल जाँच पूरी होने तथा Admin की मंजूरी के बाद ही काम के ऑफर चालू होंगे।'
                        : 'आपका डैशबोर्ड और प्रोफाइल उपलब्ध हैं। Admin की मंजूरी और Active स्थिति होने तक बुकिंग ऑफर स्वीकार करना, काम शुरू करना और काम पूरा करना बंद रहेगा।',
                    ),
                    const SizedBox(height: 8),
                    const Text('अभी काम के ऑफर, कोटेशन और काम की स्थिति वाले एक्शन उपलब्ध नहीं हैं।'),
                  ],
                ),
              ),
            ),
          if (p != null && active) ...[
            Text('बुकिंग ऑफर', key: _offersKey, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'नए ऑफर', value: count('offered').toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'स्वीकार', value: count('accepted').toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'मना किए', value: count('declined').toString())),
            ]),
            Text('नए बुकिंग ऑफर', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (offerDetails.where((o) => o['offer_status'] == 'offered').isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कोई नया बुकिंग ऑफर नहीं है। Refresh करके फिर जाँचें।')))
            else ...offerDetails.where((o) => o['offer_status'] == 'offered').map((offer) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer['service_type']?.toString() ?? 'नई सर्विस बुकिंग', style: Theme.of(context).textTheme.titleMedium),
                  Text('बुकिंग: ${offer['booking_id'] ?? '—'}'),
                  Text('क्षेत्र: ${offer['district'] ?? '—'}, ${offer['state'] ?? '—'} • PIN ${offer['pincode'] ?? '—'}'),
                  Text('तारीख: ${offer['preferred_date'] ?? '—'} • समय: ${offer['preferred_time'] ?? '—'}'),
                  if ((offer['work_details'] ?? '').toString().isNotEmpty)
                    Text('काम: ${offer['work_details']}'),
                  Text('मैच: ${offer['match_level'] == 'pincode' ? 'आपके PIN Code में' : 'जिले के आधार पर'}'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    FilledButton.icon(
                      onPressed: loading ? null : () => respondToOffer(offer, 'accepted'),
                      icon: const Icon(Icons.check_circle_outline), label: const Text('ऑफर स्वीकार करें'),
                    ),
                    OutlinedButton.icon(
                      onPressed: loading ? null : () => respondToOffer(offer, 'declined'),
                      icon: const Icon(Icons.close), label: const Text('मना करें'),
                    ),
                  ]),
                ],
              )),
            )),
            if (offerPriceDetails.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कीमत की जानकारी वाला कोई ऑफर उपलब्ध नहीं है।')))
            else ...offerPriceDetails.map((detail) {
              final service = (detail['service_charge'] as num?)?.toDouble();
              final kind = detail['electrician_quote_kind']?.toString() ?? 'electrician_quote';
              return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('बुकिंग ' + (detail['booking_id']?.toString() ?? '—'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (service != null) ...[
                    const Divider(),
                    Text(kind == 'counter_offer' ? 'आपका Counter Offer' : kind == 'matches_suggestion' ? 'ग्राहक की कीमत के अनुसार कोटेशन' : 'आपका कोटेशन'),
                    Text('लेबर चार्ज: ₹' + service.toStringAsFixed(2)),
                    Text('कुल: ₹' + service.toStringAsFixed(2)),
                    Text('स्थिति: ' + (detail['quote_status']?.toString() ?? '—')),
                  ],
                  if ((detail['quote_note'] ?? '').toString().isNotEmpty) Text('नोट: ' + detail['quote_note'].toString()),
                ],
              )));
            }),

            Text('मेरी नियुक्त बुकिंग और कोटेशन', key: _workKey, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (bookingDetails.where((b) => ['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed'].contains(b['booking_status'])).isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कोई नियुक्त बुकिंग उपलब्ध नहीं है। नई बुकिंग स्वीकार होने के बाद यहाँ कोटेशन भेज सकेंगे।')))
            else ...bookingDetails.where((b) => ['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed'].contains(b['booking_status'])).map((booking) {
              final status = booking['booking_status']?.toString();
              final activeBookingCount = bookingDetails.where((b) => b['booking_status'] == 'in_progress').length;
              final canQuote = ['assigned','inspection','quote_rejected'].contains(status);
              final service = (booking['service_charge'] as num?)?.toDouble();
              final total = (booking['quoted_amount'] as num?)?.toDouble();
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking['service_type']?.toString() ?? 'सर्विस बुकिंग', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text('बुकिंग: ' + (booking['booking_id']?.toString() ?? '—')),
                  Text('स्थान: ' + (booking['district']?.toString() ?? '') + ', ' + (booking['state']?.toString() ?? '') + ' • PIN ' + (booking['pincode']?.toString() ?? '')),
                  Text('स्थिति: ' + bookingStatusLabel(status)),
                  OutlinedButton.icon(onPressed:()=>openBookingMap(booking),icon:const Icon(Icons.directions),label:const Text('ग्राहक की लोकेशन / रास्ता खोलें')),
                  if (['assigned','quote_approved'].contains(status))
                    OutlinedButton.icon(
                      onPressed: loading ? null : () => proposeSchedule(booking),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('ग्राहक को समय प्रस्तावित करें'),
                    ),
                  if(booking['payment_status']=='paid')
                    const Text('भुगतान प्राप्त दर्ज है',style:TextStyle(color:Colors.green,fontWeight:FontWeight.bold)),
                  if ((booking['customer_phone'] ?? '').toString().trim().isNotEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: const Icon(Icons.call),
                        title: const Text('ग्राहक का मोबाइल नंबर'),
                        subtitle: SelectableText(booking['customer_phone'].toString()),
                        trailing: IconButton(
                          tooltip: 'कॉल करें',
                          icon: const Icon(Icons.call_outlined),
                          onPressed: () => _callPhone(booking['customer_phone'].toString()),
                        ),
                      ),
                    ),
                  if (service != null) Text('लेबर चार्ज: ₹' + service.toStringAsFixed(2)),
                  if (total != null) Text('कुल कोटेशन: ₹' + total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if ((booking['quote_note'] ?? '').toString().isNotEmpty) Text('नोट: ' + booking['quote_note'].toString()),
                  if (status == 'quote_approved')
                    Align(alignment: Alignment.centerRight, child: FilledButton.icon(
                      onPressed: loading ? null : () => requestWorkStartApproval(booking['assignment_id'].toString()),
                      icon: const Icon(Icons.play_arrow), label: const Text('काम शुरू करने की मंजूरी माँगें'),
                    )),
                  if (status == 'in_progress') ...[
                    WorkerWorkSessionPanel(
                      assignmentId: booking['assignment_id'].toString(),
                      pricingUnit: booking['pricing_unit_snapshot']?.toString() ?? 'hourly',
                      onChanged: load,
                      onProposeSchedule: () => proposeSchedule(booking),
                    ),
                    if (activeBookingCount == 1)
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: sendSos,
                        icon: const Icon(Icons.sos), label: const Text('🚨 तत्काल सहायता / SOS'),
                      )),
                  ],
                  if (canQuote) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: loading ? null : () => openQuoteForm(booking),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('ग्राहक को कोटेशन भेजें'),
                    )),
                  ] else if (status == 'awaiting_quote_approval')
                    const Text('कोटेशन ग्राहक को भेज दिया गया है। ग्राहक की मंजूरी का इंतजार करें।'),
                ],
              )));
            }),
            Text('कमाई', key: _earningsKey, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'पूरे काम', value: completed.toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Paid कमाई', value: '₹' + earned.toStringAsFixed(0))),
            ]),
            if (earnings.isNotEmpty) ...[
              Text('हर बुकिंग का पूरा बिल और कमाई', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...earnings.where((e) => e['booking_status'] == 'completed').map((e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(e['service_type']?.toString() ?? 'पूरी हुई बुकिंग'),
                  subtitle: Text('बुकिंग: ' + (e['booking_id']?.toString() ?? '—') + ' • आपकी कमाई: ' + _money(e['net_earning']) + ' • ' + (e['payment_method']?.toString() ?? 'भुगतान लंबित')),
                  trailing: IconButton(icon: const Icon(Icons.visibility_outlined), tooltip: 'पूरा बिल देखें', onPressed: () => openFinancialDetails(e)),
                ),
              )),
            ],
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('मेरा Worker Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Payout के लिए उपलब्ध: ' + _money(wallet?['available_for_payout']), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_number(wallet?['recovery_debt']) > 0)
                  Text('Wallet में कंपनी का Cash कमीशन बकाया: −' + _money(wallet?['recovery_debt']), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text('कंपनी का Cash कमीशन बाकी: ' + _money(wallet?['cash_commission_outstanding'])),
                Text('रुकी हुई कमाई: ' + _money(wallet?['held_earnings'])),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: loading || ((wallet?['available_for_payout'] as num?)?.toDouble() ?? 0) <= 0 || wallet?['payout_blocked'] == true ? null : requestAvailablePayout,
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('उपलब्ध रकम का Payout Request भेजें'),
                )),
              ],
            ))),
            if (payoutRequests.isNotEmpty) ...[
              Text('मेरी Payout Requests', style: Theme.of(context).textTheme.titleLarge),
              ...payoutRequests.map((r) => Card(child: ListTile(
                leading: Icon(r['status'] == 'paid' ? Icons.check_circle : Icons.hourglass_top),
                title: Text(_money(r['approved_amount'] ?? r['requested_amount']) + ' • ' + (r['status']?.toString() ?? '—')),
                subtitle: Text((r['payout_code']?.toString() ?? '') +
                  (r['payment_reference']?.toString().isNotEmpty == true ? ' • UTR: ' + r['payment_reference'].toString() : '') +
                  (r['admin_note']?.toString().isNotEmpty == true ? ' • ' + r['admin_note'].toString() : '')),
              ))),
            ],
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('ग्राहक का पूरा मोबाइल नंबर केवल आपकी नियुक्त बुकिंग में दिखता है।'))),
          ],
        ]),
      ),
      ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) {
          if (index == 0) _goToSection(0, null);
          if (index == 1) _goToSection(1, _offersKey);
          if (index == 2) _goToSection(2, _workKey);
          if (index == 3) _goToSection(3, _earningsKey);
          if (index == 4) _showWorkerProfile();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'होम'),
          NavigationDestination(icon: Icon(Icons.notifications_active_outlined), selectedIcon: Icon(Icons.notifications_active), label: 'ऑफर'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman), label: 'काम'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'कमाई'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'प्रोफाइल'),
        ],
      ),
    );
  }
}

class _QuoteSubmissionDialog extends StatefulWidget {
  const _QuoteSubmissionDialog({
    required this.client,
    required this.bookingId,
  });

  final SupabaseClient client;
  final String bookingId;

  @override
  State<_QuoteSubmissionDialog> createState() => _QuoteSubmissionDialogState();
}

class _QuoteSubmissionDialogState extends State<_QuoteSubmissionDialog> {
  final serviceController = TextEditingController();
  final noteController = TextEditingController();
  bool saving = false;
  String? formError;

  @override
  void dispose() {
    serviceController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final service = double.tryParse(serviceController.text.trim());
    if (service == null || service <= 0 || service > 10000000) {
      setState(() => formError =
          'सही लेबर चार्ज भरें। रकम शून्य से अधिक होनी चाहिए।');
      return;
    }

    setState(() {
      saving = true;
      formError = null;
    });
    try {
      await widget.client.rpc('srk_submit_labour_quote', params: {
        'p_booking_id': widget.bookingId,
        'p_service_charge': service,
        'p_quote_note': noteController.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          formError = 'कोटेशन नहीं भेजा जा सका। कृपया दोबारा कोशिश करें।';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ग्राहक को कोटेशन भेजें'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('केवल लेबर चार्ज दर्ज करें। ग्राहक की मंजूरी के बाद ही काम शुरू होगा।'),
          const SizedBox(height: 12),
          TextField(
            controller: serviceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'मेहनताना / सर्विस चार्ज (₹)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'काम का विवरण / नोट (वैकल्पिक)'),
          ),
          if (formError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(formError!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.of(context).pop(false),
        child: const Text('रद्द करें'),
      ),
      FilledButton(
        onPressed: saving ? null : submit,
        child: Text(saving ? 'भेजा जा रहा है…' : 'कोटेशन भेजें'),
      ),
    ],
  );
}

Future<void> _callPhone(String raw) async {
  final number = raw.trim();
  if (number.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: number));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Column(children: [
    Text(value, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 4), Text(label, textAlign: TextAlign.center),
  ])));
}

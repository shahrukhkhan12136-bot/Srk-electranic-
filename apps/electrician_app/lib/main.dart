import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';

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
    if (p == null || !RegExp(r'^\d{4,8}.hasMatch(token)) { setState(() => message = 'सही मोबाइल नंबर और SMS OTP दर्ज करें।'); return; }
    await run(() async { await Supabase.instance.client.auth.verifyOTP(phone: p, token: token, type: OtpType.sms); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SRK ELECTRONIC — Electrician')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.electrical_services, size: 52),
          Text('इलेक्ट्रिशियन लॉगिन', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'रजिस्टर्ड मोबाइल नंबर')),
          if (sent) ...[const SizedBox(height: 12), TextField(controller: otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SMS OTP'))],
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : (sent ? verifyOtp : sendOtp), child: Text(busy ? 'कृपया प्रतीक्षा करें…' : (sent ? 'OTP सत्यापित करें' : 'OTP भेजें'))),
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
  Map<String, dynamic>? profile, wallet;
  List<Map<String, dynamic>> offers = [], earnings = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Session expired');
      profile = await client.from('electrician_profiles').select('id,display_name,state,district,pincode,active,verification_status').or('user_id.eq.$uid,auth_user_id.eq.$uid').maybeSingle();
      if (profile != null) {
        final pid = profile!['id'] as String;
        final offerRows = await client.from('job_offers').select('id,status,match_level,created_at').eq('electrician_id', pid).order('created_at', ascending: false).limit(100);
        offers = List<Map<String, dynamic>>.from(offerRows);
        final earningRows = await client.rpc('srk_get_my_earnings');
        earnings = List<Map<String, dynamic>>.from(earningRows as List);
        final walletResult = await client.rpc('srk_get_my_wallet_summary');
        final walletData = Map<String, dynamic>.from(walletResult as Map);
        final partnerWallet = walletData['electrician'];
        wallet = partnerWallet == null ? null : Map<String, dynamic>.from(partnerWallet as Map);
      } else { offers = []; earnings = []; wallet = null; }
    } catch (_) { error = 'डैशबोर्ड लोड नहीं हो सका। इंटरनेट जाँचकर Refresh करें।'; }
    finally { if (mounted) setState(() => loading = false); }
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
        IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => client.auth.signOut(), icon: const Icon(Icons.logout)),
      ]),
      body: RefreshIndicator(onRefresh: load, child: loading
        ? const ListView(children: [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
        : ListView(padding: const EdgeInsets.all(16), children: [
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.red)))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?['display_name']?.toString() ?? 'प्रोफाइल लिंक नहीं हुई', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (p == null) const Text('आवेदन अभी अप्रूव नहीं हुआ है या रजिस्टर्ड मोबाइल OTP से लिंक नहीं है। Admin से संपर्क करें।')
            else Text((p['district'] ?? '').toString() + ', ' + (p['state'] ?? '').toString() + ' • PIN ' + (p['pincode'] ?? '').toString()),
            if (p != null) Padding(padding: const EdgeInsets.only(top: 8), child: Chip(avatar: Icon(active ? Icons.verified : Icons.info_outline), label: Text(active ? 'Approved और Active' : 'Inactive / Approval बाकी'))),
          ]))),
          if (p != null) ...[
            Text('बुकिंग ऑफर', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'नए ऑफर', value: count('offered').toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'स्वीकार', value: count('accepted').toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'मना किए', value: count('declined').toString())),
            ]),
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ऑफर की पूरी जानकारी अभी सुरक्षित रूप से उपलब्ध नहीं है।', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('मौजूदा backend का offer-details RPC ग्राहक का असली फोन नंबर भी ऐप को भेजता है। आपकी तय Masked Calling नीति के अनुसार हम वह डेटा मोबाइल ऐप में नहीं मँगाएँगे या दिखाएँगे। पहले फोन नंबर हटाकर सुरक्षित offer-details RPC बनाना जरूरी है।'),
              SizedBox(height: 8),
              Text('मौजूदा backend में केवल Accept और Reject उपलब्ध हैं। Counter Offer के लिए अलग backend सुविधा भी अभी नहीं बनी है।'),
            ]))),
            Text('कमाई', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'पूरे काम', value: completed.toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Paid कमाई', value: '₹' + earned.toStringAsFixed(0))),
            ]),
            Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('वॉलेट बैलेंस: ₹' + ((wallet?['balance'] as num?)?.toStringAsFixed(2) ?? '0.00')),
              subtitle: const Text('बैंक पेआउट अभी बंद है; Route onboarding और live approval बाकी है।'))),
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('सुरक्षा: इस ऐप में ग्राहक का फोन नंबर या direct tel: कॉल लिंक नहीं दिखाया जाता। Masked Calling provider का परीक्षण अलग से होगा।'))),
          ],
        ]),
      ),
    );
  }
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
).hasMatch(token)) { setState(() => message = 'सही मोबाइल नंबर और SMS OTP दर्ज करें।'); return; }
    await run(() async { await Supabase.instance.client.auth.verifyOTP(phone: p, token: token, type: OtpType.sms); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SRK ELECTRONIC — Electrician')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.electrical_services, size: 52),
          Text('इलेक्ट्रिशियन लॉगिन', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'रजिस्टर्ड मोबाइल नंबर')),
          if (sent) ...[const SizedBox(height: 12), TextField(controller: otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SMS OTP'))],
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : (sent ? verifyOtp : sendOtp), child: Text(busy ? 'कृपया प्रतीक्षा करें…' : (sent ? 'OTP सत्यापित करें' : 'OTP भेजें'))),
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
  Map<String, dynamic>? profile, wallet;
  List<Map<String, dynamic>> offers = [], earnings = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Session expired');
      profile = await client.from('electrician_profiles').select('id,display_name,state,district,pincode,active,verification_status').eq('user_id', uid).maybeSingle();
      if (profile != null) {
        final pid = profile!['id'] as String;
        final offerRows = await client.from('job_offers').select('id,status,match_level,created_at').eq('electrician_id', pid).order('created_at', ascending: false).limit(100);
        offers = List<Map<String, dynamic>>.from(offerRows);
        final earningRows = await client.rpc('srk_get_my_earnings');
        earnings = List<Map<String, dynamic>>.from(earningRows as List);
        final walletResult = await client.rpc('srk_get_my_wallet_summary');
        final walletData = Map<String, dynamic>.from(walletResult as Map);
        final partnerWallet = walletData['electrician'];
        wallet = partnerWallet == null ? null : Map<String, dynamic>.from(partnerWallet as Map);
      } else { offers = []; earnings = []; wallet = null; }
    } catch (_) { error = 'डैशबोर्ड लोड नहीं हो सका। इंटरनेट जाँचकर Refresh करें।'; }
    finally { if (mounted) setState(() => loading = false); }
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
        IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => client.auth.signOut(), icon: const Icon(Icons.logout)),
      ]),
      body: RefreshIndicator(onRefresh: load, child: loading
        ? const ListView(children: [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
        : ListView(padding: const EdgeInsets.all(16), children: [
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.red)))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?['display_name']?.toString() ?? 'प्रोफाइल लिंक नहीं हुई', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (p == null) const Text('आवेदन अभी अप्रूव नहीं हुआ है या रजिस्टर्ड मोबाइल OTP से लिंक नहीं है। Admin से संपर्क करें।')
            else Text((p['district'] ?? '').toString() + ', ' + (p['state'] ?? '').toString() + ' • PIN ' + (p['pincode'] ?? '').toString()),
            if (p != null) Padding(padding: const EdgeInsets.only(top: 8), child: Chip(avatar: Icon(active ? Icons.verified : Icons.info_outline), label: Text(active ? 'Approved और Active' : 'Inactive / Approval बाकी'))),
          ]))),
          if (p != null) ...[
            Text('बुकिंग ऑफर', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'नए ऑफर', value: count('offered').toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'स्वीकार', value: count('accepted').toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'मना किए', value: count('declined').toString())),
            ]),
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ऑफर की पूरी जानकारी अभी सुरक्षित रूप से उपलब्ध नहीं है।', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('मौजूदा backend का offer-details RPC ग्राहक का असली फोन नंबर भी ऐप को भेजता है। आपकी तय Masked Calling नीति के अनुसार हम वह डेटा मोबाइल ऐप में नहीं मँगाएँगे या दिखाएँगे। पहले फोन नंबर हटाकर सुरक्षित offer-details RPC बनाना जरूरी है।'),
              SizedBox(height: 8),
              Text('मौजूदा backend में केवल Accept और Reject उपलब्ध हैं। Counter Offer के लिए अलग backend सुविधा भी अभी नहीं बनी है।'),
            ]))),
            Text('कमाई', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'पूरे काम', value: completed.toString())),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Paid कमाई', value: '₹' + earned.toStringAsFixed(0))),
            ]),
            Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('वॉलेट बैलेंस: ₹' + ((wallet?['balance'] as num?)?.toStringAsFixed(2) ?? '0.00')),
              subtitle: const Text('बैंक पेआउट अभी बंद है; Route onboarding और live approval बाकी है।'))),
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('सुरक्षा: इस ऐप में ग्राहक का फोन नंबर या direct tel: कॉल लिंक नहीं दिखाया जाता। Masked Calling provider का परीक्षण अलग से होगा।'))),
          ],
        ]),
      ),
    );
  }
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

import 'package:flutter/material.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSrkSupabase();
  runApp(const SrkAdminApp());
}

class SrkAdminApp extends StatelessWidget {
  const SrkAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SRK ELECTRONIC',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF173B72)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF3F6FA),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        home: const AdminGate(),
      );
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
          return session == null ? const AdminLoginPage() : const AdminDashboard();
        },
      );
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Admin ईमेल और पासवर्ड भरें।');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      await auth.signInWithPassword(email: email, password: password);
      final allowed = await Supabase.instance.client.rpc('is_srk_admin');
      if (allowed != true) {
        await auth.signOut();
        throw StateError('इस खाते को Admin अनुमति नहीं मिली।');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (e) {
      if (mounted) setState(() => _message = e is StateError ? e.message : 'लॉगिन सत्यापित नहीं हो सका।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 58),
                      const SizedBox(height: 12),
                      Text('SRK ELECTRONIC', textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Text('Admin Dashboard', textAlign: TextAlign.center),
                      const SizedBox(height: 26),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(labelText: 'Admin ईमेल')),
                      const SizedBox(height: 14),
                      TextField(controller: _password, obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(labelText: 'पासवर्ड')),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _busy ? null : _login,
                        icon: const Icon(Icons.lock_open),
                        label: Text(_busy ? 'जाँच हो रही है…' : 'सुरक्षित Admin Login'),
                      ),
                      const SizedBox(height: 10),
                      const Text('लॉगिन के बाद सर्वर पर is_srk_admin() से अनुमति जाँची जाती है।',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                      if (_message != null) Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_message!, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _client = Supabase.instance.client;
  String _period = 'monthly';
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _finance = {};
  Map<String, dynamic> _wallet = {};
  Map<String, dynamic> _commission = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  String _money(dynamic value) => '₹${_number(value).toStringAsFixed(2)}';
  String _count(dynamic value) => (value ?? 0).toString();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final allowed = await _client.rpc('is_srk_admin');
      if (allowed != true) {
        await _client.auth.signOut();
        throw StateError('Admin अनुमति समाप्त या उपलब्ध नहीं है। दोबारा लॉगिन करें।');
      }
      final today = DateTime.now();
      final anchor = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        _client.rpc('srk_admin_finance_dashboard', params: {'p_period': _period, 'p_anchor_date': anchor}),
        _client.rpc('srk_admin_wallet_overview'),
        _client.rpc('srk_admin_commission_report'),
      ]);
      _finance = Map<String, dynamic>.from(results[0] as Map);
      _wallet = Map<String, dynamic>.from(results[1] as Map);
      _commission = Map<String, dynamic>.from(results[2] as Map);
    } catch (e) {
      _error = e is StateError ? e.message : 'डैशबोर्ड डेटा लोड नहीं हुआ। अनुमति और नेटवर्क जाँचें।';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() => _client.auth.signOut();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('SRK ELECTRONIC • Admin'),
          actions: [
            IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
            IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('व्यवसाय डैशबोर्ड', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('सुरक्षित Admin डेटा • ${_client.auth.currentUser?.email ?? 'Admin'}'),
              const SizedBox(height: 14),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )),
              Row(children: [
                const Expanded(child: Text('वित्तीय अवधि', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButton<String>(
                  value: _period,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('आज')),
                    DropdownMenuItem(value: 'monthly', child: Text('इस महीने')),
                    DropdownMenuItem(value: 'yearly', child: Text('इस साल')),
                  ],
                  onChanged: _loading ? null : (v) { if (v != null) setState(() => _period = v); _load(); },
                ),
              ]),
              _section('वित्तीय सारांश', Icons.insights),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _metric('ग्राहक भुगतान', _money(_finance['customer_payments']), Icons.payments),
                _metric('प्लेटफॉर्म कमीशन', _money(_finance['platform_commission']), Icons.account_balance),
                _metric('इलेक्ट्रिशियन हिस्सा', _money(_finance['electrician_share']), Icons.engineering),
                _metric('शुद्ध लाभ', _money(_finance['net_profit']), Icons.trending_up),
                _metric('पूरे और Paid काम', _count(_finance['paid_completed_bookings']), Icons.task_alt),
                _metric('कुल खर्च', _money(_finance['total_expenses']), Icons.receipt_long),
              ]),
              _section('पेआउट स्थिति', Icons.account_balance_wallet),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _metric('Paid पेआउट', _money(_finance['electrician_payout_paid']), Icons.check_circle),
                _metric('Pending पेआउट', _money(_finance['electrician_payout_pending']), Icons.pending_actions),
              ]),
              _section('वॉलेट अवलोकन', Icons.wallet),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _metric('Customer वॉलेट', _count(_wallet['customer_wallets']), Icons.person),
                _metric('Electrician वॉलेट', _count(_wallet['electrician_wallets']), Icons.electrical_services),
                _metric('Ledger Credits', _money(_wallet['posted_ledger_credits']), Icons.south_west),
                _metric('Ledger Debits', _money(_wallet['posted_ledger_debits']), Icons.north_east),
                _metric('Pending Entries', _count(_wallet['pending_entries']), Icons.hourglass_empty),
                _metric('Verified Bank Links', _count(_wallet['verified_bank_links']), Icons.verified_user),
              ]),
              _section('कमीशन रिपोर्ट', Icons.bar_chart),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _line('कुल वसूली', _money(_commission['total_collected'])),
                  _line('कुल कंपनी कमीशन', _money(_commission['total_commission'])),
                  _line('इलेक्ट्रिशियन को देय', _money(_commission['total_electrician_payable'])),
                  const Divider(),
                  Text('इलेक्ट्रिशियन रिपोर्ट: ${(_commission['partners'] is List ? (_commission['partners'] as List).length : 0)} पार्टनर',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              )),
              _section('खर्च का विवरण', Icons.pie_chart_outline),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _line('SMS / OTP', _money(_finance['sms_otp_cost'])),
                  _line('Razorpay फीस', _money(_finance['razorpay_fees'])),
                  _line('Supabase', _money(_finance['supabase_cost'])),
                  _line('Netlify', _money(_finance['netlify_cost'])),
                  _line('विज्ञापन', _money(_finance['advertising_cost'])),
                  _line('स्टाफ', _money(_finance['staff_cost'])),
                  _line('अन्य', _money(_finance['other_cost'])),
                ]),
              )),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('सुरक्षा: यह डैशबोर्ड केवल सर्वर से Admin सत्यापित खाते के लिए है। भुगतान, रिफंड या बैंक पेआउट यहाँ से स्वतः नहीं किए जाते।',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
          ),
        ),
      );

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 21),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _metric(String label, String value, IconData icon) => SizedBox(
        width: 164,
        child: Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        )),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

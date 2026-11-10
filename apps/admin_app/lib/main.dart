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
  void _openOperations() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminOperationsPage()));

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
              const SrkFounderBanner(),
              const SizedBox(height: 14),
              Text('व्यवसाय डैशबोर्ड', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('सुरक्षित Admin डेटा • ${_client.auth.currentUser?.email ?? 'Admin'}'),
              const SizedBox(height: 14),
              Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
                title: const Text('बुकिंग और इलेक्ट्रिशियन प्रबंधन', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('बुकिंग ऑफर, आवेदन समीक्षा और दस्तावेज़ सत्यापन'),
                trailing: const Icon(Icons.chevron_right), onTap: _openOperations,
              )),
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

class AdminOperationsPage extends StatefulWidget {
  const AdminOperationsPage({super.key});
  @override
  State<AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<AdminOperationsPage> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [], _applications = [], _documents = [];
  final Set<String> _busy = {};

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (await _client.rpc('is_srk_admin') != true) {
        await _client.auth.signOut();
        throw StateError('Admin अनुमति नहीं मिली। दोबारा लॉगिन करें।');
      }
      final bookingsResult = await _client
          .from('service_bookings')
          .select('id,created_at,customer_name,state,district,pincode,address,service_type,preferred_date,preferred_time,work_details,status,assigned_electrician_id,quoted_amount,payment_status,service_charge,materials_amount,quote_status')
          .order('created_at', ascending: false)
          .limit(100);
      final applicationsResult = await _client
          .from('electrician_applications')
          .select('id,created_at,full_name,state,district,pincode,skills,experience_years,about,verification_status,active')
          .order('created_at', ascending: false)
          .limit(100);
      final documentsResult = await _client.rpc(
        'srk_admin_list_electrician_verification_documents',
        params: {'p_limit': 200},
      );
      final contactRows = await _client.rpc('srk_admin_get_booking_contacts');
      final bookingContacts = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(contactRows as List)) {
        bookingContacts[row['booking_id'].toString()] = row;
      }
      _bookings = (bookingsResult as List).map((x) {
        final booking = Map<String,dynamic>.from(x as Map);
        final contacts = bookingContacts[booking['id'].toString()];
        if (contacts != null) {
          booking['customer_phone'] = contacts['customer_phone'];
          booking['electrician_phone'] = contacts['electrician_phone'];
        }
        return booking;
      }).toList();
      _applications = (applicationsResult as List).map((x) => Map<String,dynamic>.from(x as Map)).toList();
      _documents = (documentsResult as List).map((x) => Map<String,dynamic>.from(x as Map)).toList();
    } catch(e) { _error = e is StateError ? e.message : 'डेटा लोड नहीं हुआ। Admin अनुमति और नेटवर्क जाँचें।'; }
    finally { if (mounted) setState(() => _loading = false); }
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    return d == null ? v.toString() : '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
  }

  Future<void> _run(String id, Future<dynamic> Function() action, String message) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('कार्रवाई पूरी नहीं हुई: ${e.toString().replaceFirst('Exception: ','')}')));
    } finally { if (mounted) setState(() => _busy.remove(id)); }
  }

  Future<String?> _note({required String title, required bool requiredNote}) async {
    final ctl = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, maxLines: 3, maxLength: 1000,
        decoration: InputDecoration(labelText: requiredNote ? 'कारण (अनिवार्य)' : 'Admin टिप्पणी (वैकल्पिक)', border: const OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
        FilledButton(onPressed: () { final s=ctl.text.trim(); if(requiredNote && s.isEmpty) return; Navigator.pop(ctx,s); }, child: const Text('जारी रखें')),
      ],
    ));
    ctl.dispose(); return value;
  }

  Future<void> _offer(Map<String,dynamic> b) async {
    final id=b['id'].toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('बुकिंग ऑफर भेजें?'),
      content:const Text('पहले उसी PIN के Active और Approved इलेक्ट्रिशियन को ऑफर जाएगा। वहाँ कोई योग्य पार्टनर न मिलने पर उसी जिले में fallback होगा।'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ऑफर भेजें'))],
    ));
    if(ok!=true)return;
    await _run(id,() async {
      final v=Map<String,dynamic>.from(await _client.rpc('srk_admin_offer_booking',params:{'p_booking_id':id}) as Map);
      if(v['success']!=true) throw StateError(v['message']?.toString() ?? 'योग्य इलेक्ट्रिशियन उपलब्ध नहीं है।');
      return v;
    },'बुकिंग ऑफर प्रक्रिया पूरी हुई।');
  }

  Future<void> _application(Map<String,dynamic> a,String decision) async {
    final approve=decision=='approved';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(approve?'इलेक्ट्रिशियन आवेदन Approve करें?':decision=='rejected'?'आवेदन Reject करें?':'आवेदन Suspend करें?'),
      content:Text(approve?'सर्वर आवेदन के मोबाइल नंबर से OTP सत्यापन जाँचेगा। Approval के बाद भी प्रोफाइल Inactive रहेगी।':'यह आवेदन की verification स्थिति बदलेगा।'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('पुष्टि करें'))],
    ));
    if(ok!=true)return;
    final id=a['id'].toString();
    await _run(id,()=>_client.rpc('srk_admin_review_application',params:{'p_application_id':id,'p_decision':decision}),'आवेदन समीक्षा अपडेट हो गई।');
  }

  Future<void> _document(Map<String,dynamic> d,String status) async {
    final note=await _note(title:status=='approved'?'दस्तावेज़ Approve करें':'दस्तावेज़ पर कारण लिखें',requiredNote:status!='approved');
    if(note==null)return;
    final id=d['id'].toString();
    await _run(id,()=>_client.rpc('srk_admin_review_electrician_document',params:{'p_document_id':id,'p_review_status':status,'p_admin_note':note}),'दस्तावेज़ समीक्षा अपडेट हो गई।');
  }

  Future<void> _active(Map<String,dynamic> d,bool active) async {
    final id=d['electrician_profile_id'].toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(active?'इलेक्ट्रिशियन Activate करें?':'इलेक्ट्रिशियन Deactivate करें?'),
      content:Text(active?'सर्वर OTP-linked approval और नवीनतम Identity तथा Address proof दोनों के Approved होने की जाँच करेगा।':'इलेक्ट्रिशियन को नए काम के ऑफर मिलना बंद हो जाएगा।'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('पुष्टि करें'))],
    ));
    if(ok!=true)return;
    await _run(id,()=>_client.rpc('srk_admin_set_electrician_active',params:{'p_profile_id':id,'p_active':active}),active?'इलेक्ट्रिशियन सक्रिय हो गया।':'इलेक्ट्रिशियन निष्क्रिय हो गया।');
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('बुकिंग और पार्टनर प्रबंधन'),
      actions:[IconButton(onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))],
      bottom:TabBar(controller:_tabs,isScrollable:true,tabs:[
        Tab(text:'बुकिंग (${_bookings.length})'),Tab(text:'आवेदन (${_applications.length})'),Tab(text:'दस्तावेज़ (${_documents.length})')
      ])),
    body:Column(children:[
      if(_loading)const LinearProgressIndicator(),
      if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(_error!,style:const TextStyle(color:Colors.red))),
      Expanded(child:TabBarView(controller:_tabs,children:[_bookingList(),_applicationList(),_documentList()])),
    ]),
  );

  Widget _bookingList()=>RefreshIndicator(onRefresh:_load,child:_bookings.isEmpty
    ?ListView(children:const [SizedBox(height:100),Center(child:Text('अभी कोई बुकिंग उपलब्ध नहीं है।'))])
    :ListView.builder(padding:const EdgeInsets.all(12),itemCount:_bookings.length,itemBuilder:(ctx,i){
      final b=_bookings[i]; final id=b['id'].toString(); final assigned=b['assigned_electrician_id']!=null; final status=b['status']?.toString()??'—';
      return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(b['service_type']?.toString()??'सेवा बुकिंग',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),Chip(label:Text(status))]),
        Text('ग्राहक: ${b['customer_name']??'—'}'),
        if ((b['customer_phone'] ?? '').toString().trim().isNotEmpty)
          SelectableText('ग्राहक मोबाइल: ${b['customer_phone']}'),
        if ((b['electrician_phone'] ?? '').toString().trim().isNotEmpty)
          SelectableText('इलेक्ट्रिशियन मोबाइल: ${b['electrician_phone']}'),
        Text('स्थान: ${b['district']??'—'}, ${b['state']??'—'} • PIN ${b['pincode']??'—'}'),
        Text('पता: ${b['address']??'—'}',maxLines:2,overflow:TextOverflow.ellipsis),
        Text('तारीख: ${_date(b['preferred_date'])} • भुगतान: ${b['payment_status']??'—'}'),
        if(b['work_details']!=null)Text('काम: ${b['work_details']}',maxLines:2,overflow:TextOverflow.ellipsis),
        if(b['quote_status']!=null)Text('Quote: ${b['quote_status']} • Labour ₹${b['service_charge']??'0'} • Materials ₹${b['materials_amount']??'0'}'),
        const SizedBox(height:8),
        Row(children:[Expanded(child:Text(assigned?'इलेक्ट्रिशियन नियुक्त है':'इलेक्ट्रिशियन नियुक्त नहीं है',style:const TextStyle(fontSize:12,color:Colors.black54))),
          if(!assigned&&(status=='new'||status=='confirmed'))FilledButton.tonalIcon(onPressed:_busy.contains(id)?null:()=>_offer(b),icon:const Icon(Icons.campaign),label:const Text('ऑफर भेजें'))]),
      ])));
    }));

  Widget _applicationList()=>RefreshIndicator(onRefresh:_load,child:_applications.isEmpty
    ?ListView(children:const [SizedBox(height:100),Center(child:Text('कोई आवेदन उपलब्ध नहीं है।'))])
    :ListView.builder(padding:const EdgeInsets.all(12),itemCount:_applications.length,itemBuilder:(ctx,i){
      final a=_applications[i]; final id=a['id'].toString(); final status=a['verification_status']?.toString()??'pending';
      return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(a['full_name']?.toString()??'इलेक्ट्रिशियन आवेदन',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        Text('${a['district']??'—'}, ${a['state']??'—'} • PIN ${a['pincode']??'—'}'),
        Text('कौशल: ${a['skills']??'—'} • अनुभव: ${a['experience_years']??0} वर्ष'),
        Text('स्थिति: $status • आवेदन: ${_date(a['created_at'])}'),
        if(a['about']!=null)Text(a['about'].toString(),maxLines:3,overflow:TextOverflow.ellipsis),
        if(status=='pending')Wrap(spacing:8,children:[
          FilledButton.tonal(onPressed:_busy.contains(id)?null:()=>_application(a,'approved'),child:const Text('Approve')),
          OutlinedButton(onPressed:_busy.contains(id)?null:()=>_application(a,'rejected'),child:const Text('Reject')),
        ]),
        if(status=='approved')OutlinedButton(onPressed:_busy.contains(id)?null:()=>_application(a,'suspended'),child:const Text('Suspend')),
      ])));
    }));

  Widget _documentList()=>RefreshIndicator(onRefresh:_load,child:_documents.isEmpty
    ?ListView(children:const [SizedBox(height:100),Center(child:Text('कोई सत्यापन दस्तावेज़ उपलब्ध नहीं है।'))])
    :ListView.builder(padding:const EdgeInsets.all(12),itemCount:_documents.length,itemBuilder:(ctx,i){
      final d=_documents[i]; final id=d['id'].toString(); final status=d['review_status']?.toString()??'pending';
      final profileStatus=d['verification_status']?.toString()??'—'; final active=d['active']==true;
      return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(d['electrician_name']?.toString()??'इलेक्ट्रिशियन',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        Text('दस्तावेज़: ${d['document_type']??'—'} • समीक्षा: $status'),
        Text('फाइल: ${d['file_name']??'—'} • अपलोड: ${_date(d['uploaded_at'])}'),
        Text('प्रोफाइल: $profileStatus • ${active?'Active':'Inactive'}'),
        if(d['admin_note']!=null)Text('Admin टिप्पणी: ${d['admin_note']}'),
        if(status=='pending'||status=='needs_resubmission')Wrap(spacing:8,children:[
          FilledButton.tonal(onPressed:_busy.contains(id)?null:()=>_document(d,'approved'),child:const Text('Approve')),
          OutlinedButton(onPressed:_busy.contains(id)?null:()=>_document(d,'rejected'),child:const Text('Reject')),
          TextButton(onPressed:_busy.contains(id)?null:()=>_document(d,'needs_resubmission'),child:const Text('दोबारा माँगें')),
        ]),
        if(profileStatus=='approved')OutlinedButton.icon(
          onPressed:_busy.contains(d['electrician_profile_id'].toString())?null:()=>_active(d,!active),
          icon:Icon(active?Icons.pause_circle_outline:Icons.check_circle_outline),
          label:Text(active?'Deactivate Partner':'Activate Partner')),
      ])));
    }));
}

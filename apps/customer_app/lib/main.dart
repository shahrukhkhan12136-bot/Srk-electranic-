import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'service_category_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSrkSupabase();
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SRK ELECTRONIC',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5ED7)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        ),
        home: const CustomerGate(),
      );
}

class CustomerGate extends StatelessWidget {
  const CustomerGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user == null) return const SrkLoginPage(role: SrkAppRole.customer);
        return const CustomerDashboard();
      },
    );
  }
}

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _complaints = [];
  String? _contactLoadWarning;
  String? _complaintLoadWarning;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  String _status(String value) => switch (value) {
        'new' => 'नई बुकिंग',
        'confirmed' => 'पुष्टि हुई',
        'assigned' => 'इलेक्ट्रिशियन नियुक्त',
        'inspection' => 'निरीक्षण चल रहा है',
        'awaiting_quote_approval' => 'कोटेशन मंजूरी बाकी',
        'quote_approved' => 'कोटेशन मंजूर',
        'quote_rejected' => 'कोटेशन में बदलाव चाहिए',
        'in_progress' => 'काम चल रहा है',
        'completed' => 'काम पूरा',
        'cancelled' => 'रद्द',
        _ => value,
      };

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
      _contactLoadWarning = null;
      _complaintLoadWarning = null;
    });
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _error = 'लॉगिन सत्र समाप्त हो गया है। कृपया दोबारा OTP से लॉगिन करें।';
        return;
      }
      final response = await _client
          .from('service_bookings')
          .select('id,service_type,status,payment_status,payment_method,preferred_date,preferred_time,created_at,quoted_amount,service_charge,materials_amount,quote_status,quote_note,district,state,pincode,electrician_quote_kind')
          .eq('customer_user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      final contacts = <String, String>{};
      try {
        final rows = await _client.rpc('srk_customer_get_my_booking_contacts');
        for (final row in List<Map<String, dynamic>>.from(rows as List)) {
          final phone = row['electrician_phone']?.toString().trim() ?? '';
          if (phone.isNotEmpty) contacts[row['booking_id'].toString()] = phone;
        }
      } catch (_) {
        _contactLoadWarning = 'इलेक्ट्रिशियन का संपर्क अभी लोड नहीं हो पाया। बुकिंग सुरक्षित है; Refresh करके फिर कोशिश करें।';
      }
      try {
        final complaintRows = await _client.rpc('srk_customer_list_booking_complaints');
        _complaints = List<Map<String, dynamic>>.from(complaintRows as List);
      } catch (_) {
        _complaintLoadWarning = 'शिकायतों की सूची अभी लोड नहीं हो पाई। Refresh करके फिर कोशिश करें।';
      }
      _bookings = List<Map<String, dynamic>>.from(response).map((booking) {
        final phone = contacts[booking['id'].toString()] ?? booking['electrician_phone']?.toString();
        return {...booking, if (phone != null) 'electrician_phone': phone};
      }).toList();
    } catch (_) {
      _error = 'बुकिंग अभी लोड नहीं हो सकीं। इंटरनेट और लॉगिन जाँचकर फिर कोशिश करें।';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respondQuote(String id, String response) async {
    final approved = response == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'कोटेशन मंजूर करें?' : 'कोटेशन अस्वीकार करें?'),
        content: Text(approved
            ? 'मंजूरी के बाद इलेक्ट्रिशियन काम शुरू कर सकता है।'
            : 'इलेक्ट्रिशियन संशोधित कोटेशन भेज सकता है।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('वापस')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(approved ? 'मंजूर करें' : 'अस्वीकार करें')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.rpc('srk_customer_respond_booking_quote', params: {
        'p_booking_id': id,
        'p_response': response,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'कोटेशन मंजूर हो गया।' : 'कोटेशन अस्वीकार हो गया।')),
      );
      await _loadBookings();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('जवाब सेव नहीं हुआ। कृपया दोबारा कोशिश करें।')),
      );
    }
  }

  Future<void> _cancelBooking(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('बुकिंग रद्द करें?'),
        content: const Text('यह विकल्प केवल तब उपलब्ध है जब इलेक्ट्रिशियन नियुक्त नहीं हुआ है।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('वापस')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('बुकिंग रद्द करें')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.rpc('srk_customer_cancel_my_booking', params: {'p_booking_id': id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('बुकिंग रद्द कर दी गई।')));
      await _loadBookings();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('बुकिंग रद्द नहीं हो सकी। हो सकता है इलेक्ट्रिशियन नियुक्त हो चुका हो।')));
    }
  }

  Future<void> _createComplaint(String bookingId) async {
    final description = TextEditingController();
    String category = 'काम की गुणवत्ता';
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('शिकायत / सहायता'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(labelText: 'शिकायत का विषय'),
            items: const ['काम की गुणवत्ता','व्यवहार','कीमत / कोटेशन','समय पर नहीं पहुँचे','भुगतान','अन्य']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: saving ? null : (v) { if (v != null) setDialogState(() => category = v); },
          ),
          const SizedBox(height: 10),
          TextField(controller: description, maxLines: 4, maxLength: 1000,
            decoration: const InputDecoration(labelText: 'समस्या का पूरा विवरण')),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          FilledButton(onPressed: saving ? null : () async {
            if (description.text.trim().length < 10) {
              setDialogState(() => error = 'कृपया कम से कम 10 अक्षरों में समस्या बताएँ।');
              return;
            }
            setDialogState(() { saving = true; error = null; });
            try {
              await _client.rpc('srk_customer_create_booking_complaint', params: {
                'p_booking_id': bookingId, 'p_category': category, 'p_description': description.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('आपकी शिकायत दर्ज हो गई।')));
                await _loadBookings();
              }
            } catch (_) { setDialogState(() { saving = false; error = 'शिकायत दर्ज नहीं हुई। दोबारा कोशिश करें।'; }); }
          }, child: Text(saving ? 'भेज रहे हैं…' : 'शिकायत भेजें')),
        ],
      )),
    );
    description.dispose();
  }


  Future<void> _payOnline(Map<String, dynamic> booking) async {
    final session = _client.auth.currentSession;
    if (session == null) return;
    const base = String.fromEnvironment('SRK_API_BASE_URL', defaultValue: 'https://srk-electronic-india.netlify.app');
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    HttpClient? http;
    Razorpay? checkout;
    final done = Completer<String>();
    try {
      http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final req = await http.postUrl(Uri.parse(root + '/api/create-order'));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ' + session.accessToken);
      req.write(jsonEncode({'booking_id': booking['id'].toString()}));
      final res = await req.close().timeout(const Duration(seconds: 30));
      final raw = await res.transform(utf8.decoder).join();
      final order = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (res.statusCode < 200 || res.statusCode >= 300 || order['success'] != true) throw StateError(order['error']?.toString() ?? 'पेमेंट ऑर्डर नहीं बन पाया।');
      checkout = Razorpay();
      checkout.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse p) async {
        try {
          final verifier = HttpClient()..connectionTimeout = const Duration(seconds: 20);
          try {
            final vr = await verifier.postUrl(Uri.parse(root + '/api/verify-payment'));
            vr.headers.contentType = ContentType.json;
            vr.headers.set(HttpHeaders.authorizationHeader, 'Bearer ' + session.accessToken);
            vr.write(jsonEncode({'razorpay_payment_id':p.paymentId,'razorpay_order_id':p.orderId,'razorpay_signature':p.signature}));
            final vres = await vr.close().timeout(const Duration(seconds: 30));
            final vdata = Map<String,dynamic>.from(jsonDecode(await vres.transform(utf8.decoder).join()) as Map);
            if (!done.isCompleted) done.complete(vres.statusCode >= 200 && vres.statusCode < 300 && vdata['success'] == true ? 'ऑनलाइन भुगतान सफल और सत्यापित हो गया।' : (vdata['error']?.toString() ?? 'भुगतान की पुष्टि बाकी है। Refresh करके देखें।'));
          } finally { verifier.close(force:true); }
        } catch (_) { if (!done.isCompleted) done.complete('भुगतान हुआ हो सकता है, लेकिन पुष्टि नहीं मिली। Refresh करके भुगतान स्थिति जाँचें।'); }
      });
      checkout.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse p) { if (!done.isCompleted) done.complete('भुगतान पूरा नहीं हुआ: ' + (p.message ?? 'दोबारा कोशिश करें।')); });
      checkout.open({'key':order['key_id'],'amount':order['amount'],'currency':order['currency'] ?? 'INR','order_id':order['order_id'],'name':'SRK ELECTRONIC','description':booking['service_type']?.toString() ?? 'Electrical service','prefill':{'contact':_client.auth.currentUser?.phone?.replaceFirst('+91','') ?? ''},'theme':{'color':'#0B5ED7'}});
      final message = await done.future.timeout(const Duration(minutes:5), onTimeout:()=> 'भुगतान की स्थिति अभी नहीं मिली। Refresh करके जाँचें।');
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message))); await _loadBookings(); }
    } catch (err) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err.toString().replaceFirst('Bad state: ','')))); }
    finally { checkout?.clear(); http?.close(force:true); }
  }
  Future<void> _logout() async {
    await _client.auth.signOut();
  }

  Future<void> _openBookingForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const CustomerBookingFormPage(),
    ));
    if (mounted) _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRK ELECTRONIC'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBookingForm,
        icon: const Icon(Icons.add),
        label: const Text('नई बुकिंग'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SrkFounderBanner(),
            const SizedBox(height: 14),
            Text('मेरी बुकिंग',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('आपकी OTP-लिंक की गई बुकिंग और इलेक्ट्रिशियन के कोटेशन यहाँ दिखेंगे।'),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              )),
            if (_contactLoadWarning != null)
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_contactLoadWarning!),
              )),
            if (!_loading && _error == null && _bookings.isEmpty)
              const Card(child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('अभी इस OTP लॉगिन से कोई बुकिंग लिंक नहीं है।'),
              )),
            ..._bookings.map(_bookingCard),
            if (_complaintLoadWarning != null)
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_complaintLoadWarning!),
              )),
            if (_complaints.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('मेरी शिकायतें', style: Theme.of(context).textTheme.titleLarge),
              ..._complaints.map((c) => Card(child: ListTile(
                leading: const Icon(Icons.support_agent),
                title: Text(c['category']?.toString() ?? 'शिकायत'),
                subtitle: Text('${c['description'] ?? ''}\\nस्थिति: ${c['status'] ?? '—'}${(c['admin_note'] ?? '').toString().isEmpty ? '' : '\\nAdmin जवाब: ${c['admin_note']}'}'),
                isThreeLine: true,
              ))),
            ],
            const SizedBox(height: 24),
            const Text(
              'नंबर केवल इलेक्ट्रिशियन द्वारा ऑर्डर स्वीकार किए जाने के बाद दिखता है।',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final quoteStatus = booking['quote_status']?.toString() ?? 'not_submitted';
    final status = booking['status']?.toString() ?? '';
    final waiting = quoteStatus == 'pending' && status == 'awaiting_quote_approval';
    final service = (booking['service_charge'] as num?)?.toDouble() ?? 0;
    final materials = (booking['materials_amount'] as num?)?.toDouble() ?? 0;
    final total = (booking['quoted_amount'] as num?)?.toDouble() ?? service + materials;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking['service_type']?.toString() ?? 'सर्विस बुकिंग',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('बुकिंग: ${booking['id']}'),
            Text('स्थिति: ${_status(status)}'),
            if ((booking['electrician_phone'] ?? '').toString().trim().isNotEmpty &&
                ['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed'].contains(status))
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.call),
                  title: const Text('इलेक्ट्रिशियन का मोबाइल नंबर'),
                  subtitle: SelectableText(booking['electrician_phone'].toString()),
                  trailing: IconButton(
                    tooltip: 'कॉल करें',
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () => _callPhone(booking['electrician_phone'].toString()),
                  ),
                ),
              ),
            Text('इलाका: ${booking['district'] ?? ''}, ${booking['state'] ?? ''} • PIN ${booking['pincode'] ?? ''}'),
            Text('तारीख: ${booking['preferred_date'] ?? '—'} • समय: ${booking['preferred_time'] ?? '—'}'),
            if (quoteStatus != 'not_submitted') ...[
              const Divider(),
              Text(booking['electrician_quote_kind'] == 'counter_offer' ? 'इलेक्ट्रिशियन का Counter Offer' : 'इलेक्ट्रिशियन का कोटेशन',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('सर्विस / मेहनताना: ₹${service.toStringAsFixed(2)}'),
              Text('सामान / पार्ट्स: ₹${materials.toStringAsFixed(2)}'),
              Text('कुल: ₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('कोटेशन स्थिति: $quoteStatus'),
              if ((booking['quote_note'] ?? '').toString().isNotEmpty)
                Text('विवरण: ${booking['quote_note']}'),
              if (waiting) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => _respondQuote(booking['id'].toString(), 'approved'),
                      child: const Text('कोटेशन मंजूर करें'),
                    ),
                    OutlinedButton(
                      onPressed: () => _respondQuote(booking['id'].toString(), 'rejected'),
                      child: const Text('अस्वीकार करें'),
                    ),
                  ],
                ),
              ],
            ],
            if (status == 'new' || status == 'confirmed')
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: () => _cancelBooking(booking['id'].toString()),
                icon: const Icon(Icons.cancel_outlined), label: const Text('बुकिंग रद्द करें'),
              )),
            if (status != 'cancelled')
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: () => _createComplaint(booking['id'].toString()),
                icon: const Icon(Icons.support_agent), label: const Text('शिकायत / सहायता'),
              )),
            if (status == 'completed' && booking['payment_status'] != 'paid' && quoteStatus == 'approved') ...[
              Text('भुगतान तरीका: ' + (booking['payment_method']?.toString() ?? 'cash')),
              if ((booking['payment_method'] ?? 'cash').toString().toLowerCase() == 'online')
                FilledButton.icon(onPressed: () => _payOnline(booking), icon: const Icon(Icons.lock_outline), label: Text('ऑनलाइन भुगतान करें • ₹' + total.toStringAsFixed(2)))
              else const Text('काम पूरा होने पर इलेक्ट्रिशियन को नकद भुगतान करें।'),
            ],
            if (booking['payment_status'] == 'paid')
              const Text('भुगतान प्राप्त और सत्यापित', style: TextStyle(color: Colors.green,fontWeight:FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

Future<void> _callPhone(String raw) async {
  final number = raw.trim();
  if (number.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: number));
}

/// Uses the existing rate-limited Netlify booking endpoint. The service-role
/// credential remains server-side and is never included in this app.
class CustomerBookingFormPage extends StatefulWidget {
  const CustomerBookingFormPage({super.key});
  @override
  State<CustomerBookingFormPage> createState() => _CustomerBookingFormPageState();
}

class _CustomerBookingFormPageState extends State<CustomerBookingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _state = TextEditingController();
  final _district = TextEditingController();
  final _pincode = TextEditingController();
  final _address = TextEditingController();
  final _client = Supabase.instance.client;

  SrkBackendServiceSelection? _selection;
  Map<String, dynamic>? _pricePreview;
  String? _priceError;
  int _durationHours = 1, _technicianCount = 1, _helperCount = 0, _unitCount = 1;
  int _previewRequest = 0;
  bool _submitting = false, _locationBusy = false, _priceBusy = false;
  double? _locationLat, _locationLng;

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    _phone.text = (user?.phone ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
    _name.text = user?.userMetadata?['full_name']?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _state.dispose();
    _district.dispose(); _pincode.dispose(); _address.dispose();
    super.dispose();
  }

  String? _required(String? value, String label, {int min = 2}) {
    final v = value?.trim() ?? '';
    return v.length < min ? '$label सही भरें' : null;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locationBusy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('फोन की Location/GPS चालू करें।');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('लोकेशन अनुमति दें या पता मैन्युअल भरें।');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (!mounted) return;
      setState(() { _locationLat = pos.latitude; _locationLng = pos.longitude; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('वर्तमान GPS लोकेशन जोड़ दी गई।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _refreshPricePreview() async {
    final selection = _selection;
    final request = ++_previewRequest;
    if (selection == null) {
      if (mounted) setState(() { _pricePreview = null; _priceError = null; _priceBusy = false; });
      return;
    }
    setState(() { _priceBusy = true; _priceError = null; _pricePreview = null; });
    try {
      final data = await _client.rpc('srk_customer_preview_booking_price_v2', params: {
        'p_category_id': selection.categoryId,
        'p_service_type_id': selection.serviceTypeId,
        'p_skill_id': selection.skillId,
        'p_skill_level_id': selection.skillLevelId,
        'p_technician_count': _technicianCount,
        'p_helper_count': _helperCount,
        'p_duration_hours': selection.pricingUnit == 'hour' ? _durationHours : 1,
        'p_motor_hp': selection.motorHp,
        'p_unit_count': selection.pricingUnit == 'per_item' ? _unitCount : 1,
      });
      final rows = List<Map<String, dynamic>>.from(data as List);
      if (rows.isEmpty) throw StateError('इस सेवा के लिए सक्रिय दर उपलब्ध नहीं है।');
      if (!mounted || request != _previewRequest) return;
      setState(() { _pricePreview = rows.first; _priceBusy = false; });
    } catch (e) {
      if (!mounted || request != _previewRequest) return;
      setState(() { _priceError = e.toString().replaceFirst('Exception: ', ''); _priceBusy = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final selection = _selection;
    if (selection == null || _pricePreview == null || _priceBusy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('पहले लाइव कैटलॉग से सेवा चुनें और सर्वर दर की पुष्टि करें।')));
      return;
    }
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session == null || user == null || user.phoneConfirmedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('बुकिंग के लिए पहले मोबाइल OTP सत्यापन पूरा करें।')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _client.rpc('srk_customer_upsert_profile', params: {
        'p_full_name': _name.text.trim(),
        'p_phone': _phone.text.trim(),
      });
      final response = await _client.rpc('srk_customer_create_booking', params: {
        'p_category_id': selection.categoryId,
        'p_service_type_id': selection.serviceTypeId,
        'p_skill_id': selection.skillId,
        'p_technician_count': _technicianCount,
        'p_helper_count': _helperCount,
        'p_duration_hours': selection.pricingUnit == 'hour' ? _durationHours : 1,
        'p_state': _state.text.trim(),
        'p_district': _district.text.trim(),
        'p_pincode': _pincode.text.trim(),
        'p_address': _address.text.trim(),
        'p_booking_latitude': _locationLat,
        'p_booking_longitude': _locationLng,
        'p_current_gps_latitude': _locationLat,
        'p_current_gps_longitude': _locationLng,
        'p_motor_hp': selection.motorHp,
        'p_skill_level_id': selection.skillLevelId,
        'p_unit_count': selection.pricingUnit == 'per_item' ? _unitCount : 1,
      });
      final booking = Map<String, dynamic>.from(response as Map);
      if (!mounted) return;
      await showDialog<void>(
        context: context, barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
          title: const Text('बुकिंग सफलतापूर्वक भेजी गई'),
          content: Text('बुकिंग ID: ${booking['id'] ?? '—'}\n\nअभी कोई अग्रिम भुगतान नहीं लिया गया है। योग्य Technician को सेवा के अनुसार ऑफर भेजा जाएगा।'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक है'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label, hintText: hint, border: const OutlineInputBorder(),
    filled: true, fillColor: Colors.white,
  );

  Widget _field(TextEditingController controller, String label, {
    String? hint, TextInputType? keyboard, int maxLines = 1, int maxLength = 250,
    String? Function(String?)? validator, bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller, decoration: _decoration(label, hint: hint),
      keyboardType: keyboard, maxLines: maxLines, maxLength: maxLength, readOnly: readOnly,
      validator: validator ?? (v) => _required(v, label),
    ),
  );

  String _money(dynamic value) => '₹${(value as num?)?.toStringAsFixed(2) ?? '—'}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('नई सर्विस बुकिंग')),
    body: SafeArea(child: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: const [
          Icon(Icons.verified_user, color: Colors.green), SizedBox(width: 10),
          Expanded(child: Text('बुकिंग आपके OTP-verified मोबाइल खाते से जुड़ेगी। भुगतान काम पूरा होने और अंतिम बिल बनने के बाद ही होगा।')),
        ]))),
        const SizedBox(height: 12),
        Text('ग्राहक की जानकारी', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _field(_name, 'पूरा नाम', maxLength: 100),
        _field(_phone, 'OTP verified मोबाइल नंबर', keyboard: TextInputType.phone, maxLength: 10, readOnly: true,
          validator: (v) => RegExp(r'^\d{10}.hasMatch(v?.trim() ?? '') ? null : '10 अंकों का वही OTP verified नंबर भरें'),
        const SizedBox(height: 4),
        Text('सेवा का पता', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _field(_state, 'राज्य', maxLength: 100),
        _field(_district, 'जिला', maxLength: 100),
        _field(_pincode, '6 अंकों का PIN Code', keyboard: TextInputType.number, maxLength: 6,
          validator: (v) => RegExp(r'^\d{6}.hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        OutlinedButton.icon(
          onPressed: _locationBusy ? null : _useCurrentLocation,
          icon: _locationBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
          label: Text(_locationBusy ? 'GPS लोकेशन ली जा रही है…' : (_locationLat == null ? 'वर्तमान GPS लोकेशन जोड़ें' : 'GPS लोकेशन जुड़ गई • दोबारा चुनें')),
        ),
        const SizedBox(height: 14),
        Text('आपको कौन-सी सेवा चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SrkServiceCategoryPicker(onSelection: (selection) {
          setState(() { _selection = selection; _pricePreview = null; _priceError = null; });
          _refreshPricePreview();
        }),
        if (_selection != null) ...[
          const SizedBox(height: 12),
          Text('${_selection!.categoryName} • ${_selection!.serviceName}\n${_selection!.skillName} • ${_selection!.skillLevelName}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_selection!.pricingUnit == 'hour') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _durationHours, decoration: _decoration('काम की अवधि'),
              items: const [1,3,8].map((v) => DropdownMenuItem(value:v,child:Text('$v घंटे'))).toList(),
              onChanged: (v) { setState(() => _durationHours=v??1); _refreshPricePreview(); },
            ),
          ],
          if (_selection!.pricingUnit == 'per_item') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _unitCount, decoration: _decoration('कितने कूलर / यूनिट'),
              items: List.generate(10,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v यूनिट'))).toList(),
              onChanged: (v) { setState(() => _unitCount=v??1); _refreshPricePreview(); },
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _technicianCount, decoration: _decoration('कितने Technician चाहिए?'),
            items: const [1,2,3].map((v)=>DropdownMenuItem(value:v,child:Text('$v Technician'))).toList(),
            onChanged: (v) { setState(() => _technicianCount=v??1); _refreshPricePreview(); },
          ),
          const SizedBox(height: 8),
          if (_selection!.pricingUnit == 'hour' && ((_pricePreview?['helper_rate'] as num?) ?? 0) > 0)
            DropdownButtonFormField<int>(
              value: _helperCount, decoration: _decoration('Helper (वैकल्पिक)'),
              items: const [0,1].map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'Helper नहीं':'1 Helper'))).toList(),
              onChanged: (v) { setState(() => _helperCount=v??0); _refreshPricePreview(); },
            ),
          const SizedBox(height: 12),
          Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('सर्वर से अनुमानित मजदूरी', style: Theme.of(context).textTheme.titleMedium),
              if (_priceBusy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              if (_priceError != null) Text(_priceError!, style: const TextStyle(color: Colors.red)),
              if (_pricePreview != null) ...[
                Text('अनुमानित कुल: ${_money(_pricePreview!['estimated_customer_total'])}', style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                Text('मजदूरी: ${_money(_pricePreview!['estimated_base_total'])}'),
                Text('कंपनी कमीशन (अनुमान): ${_money(_pricePreview!['estimated_company_commission'])}'),
                Text('Technician का हिस्सा (अनुमान): ${_money(_pricePreview!['estimated_worker_net'])}'),
                Text((_pricePreview!['price_note']??'').toString()),
                const Text('सामान / पार्ट्स इस अनुमान में शामिल नहीं हैं; अलग सूची और आपकी मंजूरी के बाद ही जोड़े जाएँगे।'),
              ],
            ]))),
        ],
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'बुकिंग भेजने के बाद योग्य Technician को ऑफर मिलेगा। Technician स्वीकार करने के बाद काम का समय तय करने का प्रस्ताव भेज सकता है, जिसे आप स्वीकार या अस्वीकार कर सकेंगे। कोई अग्रिम भुगतान नहीं।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting || _selection == null || _pricePreview == null || _priceBusy ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
  );
}
).hasMatch(v?.trim() ?? '') ? null : '10 अंकों का वही OTP verified नंबर भरें'),
        const SizedBox(height: 4),
        Text('सेवा का पता', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _field(_state, 'राज्य', maxLength: 100),
        _field(_district, 'जिला', maxLength: 100),
        _field(_pincode, '6 अंकों का PIN Code', keyboard: TextInputType.number, maxLength: 6,
          validator: (v) => RegExp(r'^\\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        OutlinedButton.icon(
          onPressed: _locationBusy ? null : _useCurrentLocation,
          icon: _locationBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
          label: Text(_locationBusy ? 'GPS लोकेशन ली जा रही है…' : (_locationLat == null ? 'वर्तमान GPS लोकेशन जोड़ें' : 'GPS लोकेशन जुड़ गई • दोबारा चुनें')),
        ),
        const SizedBox(height: 14),
        Text('आपको कौन-सी सेवा चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SrkServiceCategoryPicker(onSelection: (selection) {
          setState(() { _selection = selection; _pricePreview = null; _priceError = null; });
          _refreshPricePreview();
        }),
        if (_selection != null) ...[
          const SizedBox(height: 12),
          Text('${_selection!.categoryName} • ${_selection!.serviceName}\n${_selection!.skillName} • ${_selection!.skillLevelName}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_selection!.pricingUnit == 'hour') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _durationHours, decoration: _decoration('काम की अवधि'),
              items: const [1,3,8].map((v) => DropdownMenuItem(value:v,child:Text('$v घंटे'))).toList(),
              onChanged: (v) { setState(() => _durationHours=v??1); _refreshPricePreview(); },
            ),
          ],
          if (_selection!.pricingUnit == 'per_item') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _unitCount, decoration: _decoration('कितने कूलर / यूनिट'),
              items: List.generate(10,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v यूनिट'))).toList(),
              onChanged: (v) { setState(() => _unitCount=v??1); _refreshPricePreview(); },
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _technicianCount, decoration: _decoration('कितने Technician चाहिए?'),
            items: const [1,2,3].map((v)=>DropdownMenuItem(value:v,child:Text('$v Technician'))).toList(),
            onChanged: (v) { setState(() => _technicianCount=v??1); _refreshPricePreview(); },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _helperCount, decoration: _decoration('Helper (वैकल्पिक)'),
            items: const [0,1].map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'Helper नहीं':'1 Helper'))).toList(),
            onChanged: (v) { setState(() => _helperCount=v??0); _refreshPricePreview(); },
          ),
          const SizedBox(height: 12),
          Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('सर्वर से अनुमानित मजदूरी', style: Theme.of(context).textTheme.titleMedium),
              if (_priceBusy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              if (_priceError != null) Text(_priceError!, style: const TextStyle(color: Colors.red)),
              if (_pricePreview != null) ...[
                Text('अनुमानित कुल: ${_money(_pricePreview!['estimated_customer_total'])}', style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                Text('मजदूरी: ${_money(_pricePreview!['estimated_base_total'])}'),
                Text('कंपनी कमीशन (अनुमान): ${_money(_pricePreview!['estimated_company_commission'])}'),
                Text('Technician का हिस्सा (अनुमान): ${_money(_pricePreview!['estimated_worker_net'])}'),
                Text((_pricePreview!['price_note']??'').toString()),
                const Text('सामान / पार्ट्स इस अनुमान में शामिल नहीं हैं; अलग सूची और आपकी मंजूरी के बाद ही जोड़े जाएँगे।'),
              ],
            ]))),
        ],
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'बुकिंग भेजने के बाद योग्य Technician को ऑफर मिलेगा। Technician स्वीकार करने के बाद काम का समय तय करने का प्रस्ताव भेज सकता है, जिसे आप स्वीकार या अस्वीकार कर सकेंगे। कोई अग्रिम भुगतान नहीं।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting || _selection == null || _pricePreview == null || _priceBusy ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
  );
}
).hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        OutlinedButton.icon(
          onPressed: _locationBusy ? null : _useCurrentLocation,
          icon: _locationBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
          label: Text(_locationBusy ? 'GPS लोकेशन ली जा रही है…' : (_locationLat == null ? 'वर्तमान GPS लोकेशन जोड़ें' : 'GPS लोकेशन जुड़ गई • दोबारा चुनें')),
        ),
        const SizedBox(height: 14),
        Text('आपको कौन-सी सेवा चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SrkServiceCategoryPicker(onSelection: (selection) {
          setState(() { _selection = selection; _pricePreview = null; _priceError = null; });
          _refreshPricePreview();
        }),
        if (_selection != null) ...[
          const SizedBox(height: 12),
          Text('${_selection!.categoryName} • ${_selection!.serviceName}\n${_selection!.skillName} • ${_selection!.skillLevelName}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_selection!.pricingUnit == 'hour') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _durationHours, decoration: _decoration('काम की अवधि'),
              items: const [1,3,8].map((v) => DropdownMenuItem(value:v,child:Text('$v घंटे'))).toList(),
              onChanged: (v) { setState(() => _durationHours=v??1); _refreshPricePreview(); },
            ),
          ],
          if (_selection!.pricingUnit == 'per_item') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _unitCount, decoration: _decoration('कितने कूलर / यूनिट'),
              items: List.generate(10,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v यूनिट'))).toList(),
              onChanged: (v) { setState(() => _unitCount=v??1); _refreshPricePreview(); },
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _technicianCount, decoration: _decoration('कितने Technician चाहिए?'),
            items: const [1,2,3].map((v)=>DropdownMenuItem(value:v,child:Text('$v Technician'))).toList(),
            onChanged: (v) { setState(() => _technicianCount=v??1); _refreshPricePreview(); },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _helperCount, decoration: _decoration('Helper (वैकल्पिक)'),
            items: const [0,1].map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'Helper नहीं':'1 Helper'))).toList(),
            onChanged: (v) { setState(() => _helperCount=v??0); _refreshPricePreview(); },
          ),
          const SizedBox(height: 12),
          Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('सर्वर से अनुमानित मजदूरी', style: Theme.of(context).textTheme.titleMedium),
              if (_priceBusy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              if (_priceError != null) Text(_priceError!, style: const TextStyle(color: Colors.red)),
              if (_pricePreview != null) ...[
                Text('अनुमानित कुल: ${_money(_pricePreview!['estimated_customer_total'])}', style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                Text('मजदूरी: ${_money(_pricePreview!['estimated_base_total'])}'),
                Text('कंपनी कमीशन (अनुमान): ${_money(_pricePreview!['estimated_company_commission'])}'),
                Text('Technician का हिस्सा (अनुमान): ${_money(_pricePreview!['estimated_worker_net'])}'),
                Text((_pricePreview!['price_note']??'').toString()),
                const Text('सामान / पार्ट्स इस अनुमान में शामिल नहीं हैं; अलग सूची और आपकी मंजूरी के बाद ही जोड़े जाएँगे।'),
              ],
            ]))),
        ],
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'बुकिंग भेजने के बाद योग्य Technician को ऑफर मिलेगा। Technician स्वीकार करने के बाद काम का समय तय करने का प्रस्ताव भेज सकता है, जिसे आप स्वीकार या अस्वीकार कर सकेंगे। कोई अग्रिम भुगतान नहीं।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting || _selection == null || _pricePreview == null || _priceBusy ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
  );
}
).hasMatch(v?.trim() ?? '') ? null : '10 अंकों का वही OTP verified नंबर भरें'),
        const SizedBox(height: 4),
        Text('सेवा का पता', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _field(_state, 'राज्य', maxLength: 100),
        _field(_district, 'जिला', maxLength: 100),
        _field(_pincode, '6 अंकों का PIN Code', keyboard: TextInputType.number, maxLength: 6,
          validator: (v) => RegExp(r'^\d{6}.hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        OutlinedButton.icon(
          onPressed: _locationBusy ? null : _useCurrentLocation,
          icon: _locationBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
          label: Text(_locationBusy ? 'GPS लोकेशन ली जा रही है…' : (_locationLat == null ? 'वर्तमान GPS लोकेशन जोड़ें' : 'GPS लोकेशन जुड़ गई • दोबारा चुनें')),
        ),
        const SizedBox(height: 14),
        Text('आपको कौन-सी सेवा चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SrkServiceCategoryPicker(onSelection: (selection) {
          setState(() { _selection = selection; _pricePreview = null; _priceError = null; });
          _refreshPricePreview();
        }),
        if (_selection != null) ...[
          const SizedBox(height: 12),
          Text('${_selection!.categoryName} • ${_selection!.serviceName}\n${_selection!.skillName} • ${_selection!.skillLevelName}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_selection!.pricingUnit == 'hour') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _durationHours, decoration: _decoration('काम की अवधि'),
              items: const [1,3,8].map((v) => DropdownMenuItem(value:v,child:Text('$v घंटे'))).toList(),
              onChanged: (v) { setState(() => _durationHours=v??1); _refreshPricePreview(); },
            ),
          ],
          if (_selection!.pricingUnit == 'per_item') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _unitCount, decoration: _decoration('कितने कूलर / यूनिट'),
              items: List.generate(10,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v यूनिट'))).toList(),
              onChanged: (v) { setState(() => _unitCount=v??1); _refreshPricePreview(); },
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _technicianCount, decoration: _decoration('कितने Technician चाहिए?'),
            items: const [1,2,3].map((v)=>DropdownMenuItem(value:v,child:Text('$v Technician'))).toList(),
            onChanged: (v) { setState(() => _technicianCount=v??1); _refreshPricePreview(); },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _helperCount, decoration: _decoration('Helper (वैकल्पिक)'),
            items: const [0,1].map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'Helper नहीं':'1 Helper'))).toList(),
            onChanged: (v) { setState(() => _helperCount=v??0); _refreshPricePreview(); },
          ),
          const SizedBox(height: 12),
          Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('सर्वर से अनुमानित मजदूरी', style: Theme.of(context).textTheme.titleMedium),
              if (_priceBusy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              if (_priceError != null) Text(_priceError!, style: const TextStyle(color: Colors.red)),
              if (_pricePreview != null) ...[
                Text('अनुमानित कुल: ${_money(_pricePreview!['estimated_customer_total'])}', style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                Text('मजदूरी: ${_money(_pricePreview!['estimated_base_total'])}'),
                Text('कंपनी कमीशन (अनुमान): ${_money(_pricePreview!['estimated_company_commission'])}'),
                Text('Technician का हिस्सा (अनुमान): ${_money(_pricePreview!['estimated_worker_net'])}'),
                Text((_pricePreview!['price_note']??'').toString()),
                const Text('सामान / पार्ट्स इस अनुमान में शामिल नहीं हैं; अलग सूची और आपकी मंजूरी के बाद ही जोड़े जाएँगे।'),
              ],
            ]))),
        ],
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'बुकिंग भेजने के बाद योग्य Technician को ऑफर मिलेगा। Technician स्वीकार करने के बाद काम का समय तय करने का प्रस्ताव भेज सकता है, जिसे आप स्वीकार या अस्वीकार कर सकेंगे। कोई अग्रिम भुगतान नहीं।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting || _selection == null || _pricePreview == null || _priceBusy ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
  );
}
).hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        OutlinedButton.icon(
          onPressed: _locationBusy ? null : _useCurrentLocation,
          icon: _locationBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
          label: Text(_locationBusy ? 'GPS लोकेशन ली जा रही है…' : (_locationLat == null ? 'वर्तमान GPS लोकेशन जोड़ें' : 'GPS लोकेशन जुड़ गई • दोबारा चुनें')),
        ),
        const SizedBox(height: 14),
        Text('आपको कौन-सी सेवा चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SrkServiceCategoryPicker(onSelection: (selection) {
          setState(() { _selection = selection; _pricePreview = null; _priceError = null; });
          _refreshPricePreview();
        }),
        if (_selection != null) ...[
          const SizedBox(height: 12),
          Text('${_selection!.categoryName} • ${_selection!.serviceName}\n${_selection!.skillName} • ${_selection!.skillLevelName}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_selection!.pricingUnit == 'hour') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _durationHours, decoration: _decoration('काम की अवधि'),
              items: const [1,3,8].map((v) => DropdownMenuItem(value:v,child:Text('$v घंटे'))).toList(),
              onChanged: (v) { setState(() => _durationHours=v??1); _refreshPricePreview(); },
            ),
          ],
          if (_selection!.pricingUnit == 'per_item') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _unitCount, decoration: _decoration('कितने कूलर / यूनिट'),
              items: List.generate(10,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v यूनिट'))).toList(),
              onChanged: (v) { setState(() => _unitCount=v??1); _refreshPricePreview(); },
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _technicianCount, decoration: _decoration('कितने Technician चाहिए?'),
            items: const [1,2,3].map((v)=>DropdownMenuItem(value:v,child:Text('$v Technician'))).toList(),
            onChanged: (v) { setState(() => _technicianCount=v??1); _refreshPricePreview(); },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _helperCount, decoration: _decoration('Helper (वैकल्पिक)'),
            items: const [0,1].map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'Helper नहीं':'1 Helper'))).toList(),
            onChanged: (v) { setState(() => _helperCount=v??0); _refreshPricePreview(); },
          ),
          const SizedBox(height: 12),
          Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('सर्वर से अनुमानित मजदूरी', style: Theme.of(context).textTheme.titleMedium),
              if (_priceBusy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              if (_priceError != null) Text(_priceError!, style: const TextStyle(color: Colors.red)),
              if (_pricePreview != null) ...[
                Text('अनुमानित कुल: ${_money(_pricePreview!['estimated_customer_total'])}', style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                Text('मजदूरी: ${_money(_pricePreview!['estimated_base_total'])}'),
                Text('कंपनी कमीशन (अनुमान): ${_money(_pricePreview!['estimated_company_commission'])}'),
                Text('Technician का हिस्सा (अनुमान): ${_money(_pricePreview!['estimated_worker_net'])}'),
                Text((_pricePreview!['price_note']??'').toString()),
                const Text('सामान / पार्ट्स इस अनुमान में शामिल नहीं हैं; अलग सूची और आपकी मंजूरी के बाद ही जोड़े जाएँगे।'),
              ],
            ]))),
        ],
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'बुकिंग भेजने के बाद योग्य Technician को ऑफर मिलेगा। Technician स्वीकार करने के बाद काम का समय तय करने का प्रस्ताव भेज सकता है, जिसे आप स्वीकार या अस्वीकार कर सकेंगे। कोई अग्रिम भुगतान नहीं।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting || _selection == null || _pricePreview == null || _priceBusy ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
  );
}

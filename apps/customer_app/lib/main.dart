import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    });
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      final response = await _client
          .from('service_bookings')
          .select('id,service_type,status,payment_status,preferred_date,preferred_time,created_at,quoted_amount,service_charge,materials_amount,quote_status,quote_note,district,state,pincode,customer_suggested_amount,electrician_quote_kind')
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
      } catch (_) {}
      _bookings = List<Map<String, dynamic>>.from(response).map((booking) {
        final phone = contacts[booking['id'].toString()];
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
            if (!_loading && _error == null && _bookings.isEmpty)
              const Card(child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('अभी इस OTP लॉगिन से कोई बुकिंग लिंक नहीं है।'),
              )),
            ..._bookings.map(_bookingCard),
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
            if (booking['customer_suggested_amount'] != null)
              Text('आपकी शुरुआती अनुमानित कीमत: ₹${(booking['customer_suggested_amount'] as num).toStringAsFixed(2)}'),
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
            if (status == 'completed' && booking['payment_status'] != 'paid')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('काम पूरा दर्ज है। भुगतान विकल्प वेबसाइट के सुरक्षित Razorpay flow से उपलब्ध होगा।'),
              ),
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
  static const _apiBase = String.fromEnvironment('SRK_API_BASE_URL', defaultValue: 'https://srk-electronic-india.netlify.app');
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _state = TextEditingController();
  final _district = TextEditingController();
  final _pincode = TextEditingController();
  final _address = TextEditingController();
  final _work = TextEditingController();
  final _suggestedAmount = TextEditingController();
  final _client = Supabase.instance.client;
  String? _service;
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;

  static const _services = [
    'Electrical Wiring',
    'Fan Installation / Repair',
    'Switch & Socket Repair',
    'Light Installation',
    'MCB / Distribution Board',
    'Inverter / Battery',
    'Appliance Electrical Repair',
    'Other Electrical Work',
  ];

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    _phone.text = (user?.phone ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
    _name.text = user?.userMetadata?['full_name']?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _state.dispose(); _district.dispose();
    _pincode.dispose(); _address.dispose(); _work.dispose(); _suggestedAmount.dispose();
    super.dispose();
  }

  String? _required(String? value, String label, {int min = 2}) {
    final v = value?.trim() ?? '';
    if (v.length < min) return '$label सही भरें';
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => _time = value);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_service == null || _date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सर्विस, तारीख और समय चुनना जरूरी है।')),
      );
      return;
    }
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session == null || user == null || user.phoneConfirmedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('बुकिंग के लिए पहले मोबाइल OTP सत्यापन पूरा करें।')),
      );
      return;
    }
    if (_apiBase.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ऐप का API domain configure नहीं है। अभी बुकिंग भेजना संभव नहीं है।')),
      );
      return;
    }
    setState(() => _submitting = true);
    HttpClient? http;
    try {
      final base = _apiBase.trim().replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/create-booking');
      if (uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Secure API address is invalid');
      }
      http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final request = await http.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${session.accessToken}');
      request.write(jsonEncode({
        'customer_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'state': _state.text.trim(),
        'district': _district.text.trim(),
        'pincode': _pincode.text.trim(),
        'address': _address.text.trim(),
        'service_type': _service,
        'preferred_date': '${_date!.year}-${_two(_date!.month)}-${_two(_date!.day)}',
        'preferred_time': '${_two(_time!.hour)}:${_two(_time!.minute)}',
        'work_details': _work.text.trim(),
        'customer_suggested_amount': _suggestedAmount.text.trim().isEmpty ? null : double.parse(_suggestedAmount.text.trim()),
        'payment_method': 'नकद (Cash)',
      }));
      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseText = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(responseText) as Map);
      } catch (_) {
        throw StateError('सर्वर से सही जवाब नहीं मिला।');
      }
      if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
        throw StateError(data['error']?.toString() ?? 'बुकिंग सेव नहीं हुई।');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
          title: const Text('बुकिंग सफलतापूर्वक भेजी गई'),
          content: Text(
            '${data['message'] ?? 'आपकी बुकिंग सेव हो गई है।'}\n\nबुकिंग ID: ${data['booking_id'] ?? '—'}',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक है'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is SocketException
              ? 'इंटरनेट कनेक्शन जाँचें और दोबारा कोशिश करें।'
              : e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      http?.close(force: true);
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label, hintText: hint, border: const OutlineInputBorder(),
    filled: true, fillColor: Colors.white,
  );

  Widget _field(TextEditingController controller, String label, {
    String? hint, TextInputType? keyboard, int maxLines = 1, int maxLength = 250,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller, decoration: _decoration(label, hint: hint),
      keyboardType: keyboard, maxLines: maxLines, maxLength: maxLength,
      validator: validator ?? (v) => _required(v, label),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('नई सर्विस बुकिंग')),
    body: SafeArea(child: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(child: Text('बुकिंग आपके OTP-verified मोबाइल खाते से जुड़ी होगी। मोबाइल नंबर वही होना चाहिए जिससे लॉगिन किया है।')),
        ]))),
        const SizedBox(height: 12),
        Text('ग्राहक की जानकारी', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _field(_name, 'पूरा नाम', maxLength: 100),
        _field(_phone, 'OTP verified मोबाइल नंबर', keyboard: TextInputType.phone, maxLength: 10,
          validator: (v) => RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '') ? null : '10 अंकों का वही OTP verified नंबर भरें'),
        const SizedBox(height: 4),
        Text('सेवा का पता', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _field(_state, 'राज्य', maxLength: 100),
        _field(_district, 'जिला', maxLength: 100),
        _field(_pincode, '6 अंकों का PIN Code', keyboard: TextInputType.number, maxLength: 6,
          validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        const SizedBox(height: 4),
        Text('काम की जानकारी', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _service, decoration: _decoration('कौन-सी इलेक्ट्रिकल सर्विस चाहिए?'),
          items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _service = v),
          validator: (v) => v == null ? 'सर्विस चुनें' : null,
        ),
        const SizedBox(height: 12),
        _field(_work, 'काम की समस्या / अतिरिक्त जानकारी', maxLines: 4, maxLength: 2000,
          validator: (v) => (v?.trim().length ?? 0) < 5 ? 'कम से कम 5 अक्षरों में काम समझाएँ' : null),
        _field(_suggestedAmount, 'आपकी शुरुआती अनुमानित कीमत (₹) — वैकल्पिक',
          keyboard: const TextInputType.numberWithOptions(decimal: true), maxLength: 12,
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return null;
            final amount = double.tryParse(value);
            return amount == null || !amount.isFinite || amount <= 0 || amount > 10000000
                ? '₹1 से ₹1,00,00,000 के बीच सही राशि भरें' : null;
          }),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: Text(_date == null ? 'पसंदीदा तारीख चुनें' : 'तारीख: ${_date!.day}-${_date!.month}-${_date!.year}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickTime,
          icon: const Icon(Icons.schedule),
          label: Text(_time == null ? 'पसंदीदा समय चुनें' : 'समय: ${_time!.format(context)}'),
        ),
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'आपकी शुरुआती कीमत वैकल्पिक है और केवल अनुमान है, अंतिम भुगतान नहीं। इलेक्ट्रिशियन निरीक्षण के बाद Labour/Service और Materials का अलग-अलग कोटेशन या Counter Offer भेजेगा। काम शुरू होने से पहले आपकी मंजूरी जरूरी होगी; अभी कोई अग्रिम भुगतान नहीं लिया जाएगा।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
  );
}

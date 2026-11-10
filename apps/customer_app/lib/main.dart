import 'package:flutter/material.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .select('id,service_type,status,payment_status,preferred_date,preferred_time,created_at,quoted_amount,service_charge,materials_amount,quote_status,quote_note,district,state,pincode')
          .eq('customer_user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      _bookings = List<Map<String, dynamic>>.from(response);
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
              'सुरक्षा: इस ऐप में ग्राहक या इलेक्ट्रिशियन के निजी फोन नंबर सीधे नहीं दिखाए जाते। सुरक्षित masked calling सुविधा अलग से जोड़कर जाँची जाएगी।',
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
            Text('इलाका: ${booking['district'] ?? ''}, ${booking['state'] ?? ''} • PIN ${booking['pincode'] ?? ''}'),
            Text('तारीख: ${booking['preferred_date'] ?? '—'} • समय: ${booking['preferred_time'] ?? '—'}'),
            if (quoteStatus != 'not_submitted') ...[
              const Divider(),
              const Text('इलेक्ट्रिशियन का कोटेशन',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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

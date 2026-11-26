import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:flutter/material.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'service_category_picker.dart';

final ValueNotifier<String> customerLanguage = ValueNotifier<String>('hi');
bool get customerEnglish => customerLanguage.value == 'en';

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

class CustomerGate extends StatefulWidget {
  const CustomerGate({super.key});
  @override
  State<CustomerGate> createState() => _CustomerGateState();
}

class _CustomerGateState extends State<CustomerGate> {
  String? _profileUserId;
  Future<Map<String, dynamic>?>? _profileFuture;
  Future<Map<String, dynamic>?> _loadProfile() async {
    final result = await Supabase.instance.client.rpc('srk_customer_get_my_profile');
    final rows = List<Map<String, dynamic>>.from(result as List);
    if (rows.isEmpty) return null;
    final hasCurrentConsent = await Supabase.instance.client.rpc('srk_customer_has_current_policy_consent');
    return hasCurrentConsent == true ? rows.first : null;
  }
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user == null) {
          _profileUserId = null;
          _profileFuture = null;
          return const SrkLoginPage(role: SrkAppRole.customer);
        }
        if (_profileUserId != user.id) {
          _profileUserId = user.id;
          _profileFuture = _loadProfile();
        }
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.id), future: _profileFuture,
          builder: (context, profile) {
            if (profile.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profile.hasError) {
              return Scaffold(body: Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('आपकी प्रोफाइल सुरक्षित रूप से जाँची नहीं जा सकी। इंटरनेट जाँचकर दोबारा कोशिश करें।', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() => _profileFuture = _loadProfile()), child: const Text('दोबारा कोशिश करें')),
                ]),
              )));
            }
            if (profile.data == null) return const CustomerProfileSetupPage();
            return const CustomerDashboard();
          },
        );
      },
    );
  }
}

class CustomerProfileSetupPage extends StatefulWidget {
  const CustomerProfileSetupPage({super.key});
  @override
  State<CustomerProfileSetupPage> createState() => _CustomerProfileSetupPageState();
}
class _CustomerProfileSetupPageState extends State<CustomerProfileSetupPage> {
  final _client = Supabase.instance.client;
  final _name = TextEditingController();
  final Map<String, bool> _accepted = {};
  List<Map<String, dynamic>> _policies = [];
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final metadata = _client.auth.currentUser?.userMetadata ?? const <String, dynamic>{};
    _name.text = (metadata['full_name'] ?? metadata['name'] ?? '').toString();
    _loadPolicies();
  }
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _loadPolicies() async {
    try {
      final rows = await _client.rpc('srk_get_registration_policy_documents', params: {
        'p_worker_type': 'customer', 'p_language_code': 'hi',
      });
      _policies = List<Map<String, dynamic>>.from(rows as List);
      if (_policies.length != 2 ||
          !_policies.any((p) => p['policy_type'] == 'terms') ||
          !_policies.any((p) => p['policy_type'] == 'privacy')) {
        _error = 'Main Admin ने अभी दोनों वर्तमान Hindi दस्तावेज़ प्रकाशित नहीं किए हैं। सहायता से संपर्क करें।';
      }
    } catch (_) {
      _error = 'नीति दस्तावेज़ लोड नहीं हुए। इंटरनेट जाँचकर दोबारा कोशिश करें।';
    } finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _saveProfile() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'कृपया अपना पूरा नाम भरें।'); return;
    }
    if (_policies.length != 2 || _policies.any((p) => _accepted[p['id'].toString()] != true)) {
      setState(() => _error = 'कृपया नियम और शर्तें तथा गोपनीयता नीति स्वीकार करें。'); return;
    }
    final user = _client.auth.currentUser;
    final phone = (user?.phone ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
    if (user == null || user.phoneConfirmedAt == null || !RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      setState(() => _error = 'सत्यापित मोबाइल नंबर उपलब्ध नहीं है। कृपया दोबारा OTP लॉगिन करें。'); return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      for (final policy in _policies) {
        await _client.rpc('srk_record_registration_policy_consent', params: {
          'p_worker_type': 'customer',
          'p_policy_document_id': policy['id'],
          'p_user_agent': 'SRK ELECTRONIC Customer Android App',
        });
      }
      await _client.rpc('srk_customer_upsert_profile', params: {
        'p_full_name': _name.text.trim(), 'p_phone': phone,
      });
      await _client.auth.updateUser(UserAttributes(data: {'full_name': _name.text.trim()}));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CustomerDashboard()));
    } catch (e) {
      if (mounted) setState(() => _error = 'प्रोफाइल सेव नहीं हुई: ' + e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ग्राहक प्रोफाइल')),
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE8F4FF), Color(0xFFF8FBFF), Color(0xFFFFF4E8)],
      )),
      child: SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
        const SrkFounderBanner(compact: true),
        const SizedBox(height: 18),
        Text('अपना नाम सेव करें', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(controller: _name, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'पूरा नाम', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Text('एक बार की सहमति', style: Theme.of(context).textTheme.titleMedium),
        const Text('ये दस्तावेज़ आपकी ग्राहक प्रोफाइल सेव करते समय स्वीकार किए जाएँगे। सामान्य बुकिंग में दोबारा नहीं पूछे जाएँगे।'),
        const SizedBox(height: 8),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && _policies.length == 2) ..._policies.map((policy) {
          final id = policy['id'].toString();
          final title = policy['policy_type'] == 'terms' ? 'नियम और शर्तें' : 'गोपनीयता नीति';
          return Card(child: ExpansionTile(
            title: Text(title + ' • संस्करण ' + policy['version'].toString()),
            children: [
              Padding(padding: const EdgeInsets.all(12), child: SelectableText(policy['body']?.toString() ?? '')),
              CheckboxListTile(
                value: _accepted[id] == true,
                onChanged: _saving ? null : (v) => setState(() => _accepted[id] = v == true),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('मैंने ' + title + ' पढ़ लिया है और स्वीकार करता/करती हूँ।'),
              ),
            ],
          ));
        }),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading || _saving || _policies.length != 2 ? null : _saveProfile,
          icon: _saving ? const SizedBox(width: 18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.save),
          label: Text(_saving ? 'सेव हो रहा है…' : 'नाम और सहमति सेव करें'),
        ),
      ])),
    ),
  );
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
  int _selectedNavIndex = 0;
  final ScrollController _dashboardScrollController = ScrollController();
  final GlobalKey _bookingsSectionKey = GlobalKey();
  Timer? _workTimerTicker;
  int _timerTick = 0;

  @override
  void initState() {
    super.initState();
    final language = _client.auth.currentUser?.userMetadata?['customer_language']?.toString();
    if (language == 'en' || language == 'hi') customerLanguage.value = language!;
    _loadBookings();
    _workTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _bookings.any((b) => b['status'] == 'in_progress' && b['work_timer_running'] == true)) {
        setState(() => _timerTick++);
      }
    });
  }

  @override
  void dispose() {
    _workTimerTicker?.cancel();
    _dashboardScrollController.dispose();
    super.dispose();
  }

  Future<void> _onBottomNavigation(int index) async {
    setState(() => _selectedNavIndex = index);
    switch (index) {
      case 0:
        if (_dashboardScrollController.hasClients) {
          await _dashboardScrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
        }
        break;
      case 1:
        final target = _bookingsSectionKey.currentContext;
        if (target != null) await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
        break;
      case 2:
        await _openSettings();
        if (mounted) setState(() => _selectedNavIndex = 0);
        break;
      case 3:
        await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('सहायता और सुरक्षा', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('बुकिंग से जुड़ी शिकायत के लिए अपनी बुकिंग में शिकायत विकल्प खोलें। आपात स्थिति में Admin को SOS भेजें।'),
            const SizedBox(height: 12),
            if (_bookings.any((booking) => booking['status'] == 'in_progress'))
              FilledButton.icon(onPressed: () { Navigator.pop(ctx); _sendSos(); }, icon: const Icon(Icons.sos), label: const Text('आपातकालीन SOS भेजें'))
            else
              const Text('SOS केवल चालू बुकिंग के दौरान उपलब्ध होगा।'),
          ]),
        )));
        if (mounted) setState(() => _selectedNavIndex = 0);
        break;
      case 4:
        await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('मेरी प्रोफाइल', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.phone_android), title: const Text('लॉगिन मोबाइल'), subtitle: Text(_client.auth.currentUser?.phone ?? '—')),
            ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('Customer Account'), subtitle: Text(_client.auth.currentUser?.id ?? '—')),
          ]),
        )));
        if (mounted) setState(() => _selectedNavIndex = 0);
        break;
    }
  }

  String _status(String value) => customerEnglish ? switch (value) {
        'new' => 'New booking',
        'confirmed' => 'Confirmed',
        'assigned' => 'Technician assigned',
        'inspection' => 'Inspection in progress',
        'awaiting_quote_approval' => 'Quote approval pending',
        'quote_approved' => 'Quote approved',
        'quote_rejected' => 'Quote changes requested',
        'in_progress' => 'Work in progress',
        'completed' => 'Completed',
        'awaiting_work_start_approval' => 'Work start approval pending',
        'cancelled' => 'Cancelled',
        _ => value,
      } : switch (value) {
        'new' => 'नई बुकिंग',
        'confirmed' => 'पुष्टि हुई',
        'assigned' => 'इलेक्ट्रिशियन नियुक्त',
        'inspection' => 'निरीक्षण चल रहा है',
        'awaiting_quote_approval' => 'कोटेशन मंजूरी बाकी',
        'quote_approved' => 'कोटेशन मंजूर',
        'quote_rejected' => 'कोटेशन में बदलाव चाहिए',
        'in_progress' => 'काम चल रहा है',
        'completed' => 'काम पूरा',
        'awaiting_work_start_approval' => 'काम शुरू करने की अनुमति बाकी',
        'cancelled' => 'रद्द',
        _ => value,
      };

  String _customerTimerText(Map<String, dynamic> booking) {
    final accumulated = (booking['work_timer_elapsed_seconds'] as num?)?.toInt() ?? 0;
    final startedAt = DateTime.tryParse(booking['work_started_at']?.toString() ?? '')?.toLocal();
    final running = booking['work_timer_running'] == true;
    final elapsed = accumulated + (running && startedAt != null
        ? DateTime.now().difference(startedAt).inSeconds.clamp(0, 60 * 60 * 24 * 365)
        : 0);
    final h = elapsed ~/ 3600, m = (elapsed % 3600) ~/ 60, s = elapsed % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _requestAccountDeletion() async {
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
      await _client.rpc('srk_request_account_deletion', params: {'p_reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account deletion request Admin समीक्षा के लिए भेज दी गई। Account अभी delete नहीं हुआ है।'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Request नहीं भेजी गई: ' + e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

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
          .select('id,service_type,status,payment_status,payment_method,preferred_date,preferred_time,created_at,quoted_amount,service_charge,quote_status,quote_note,district,state,pincode,electrician_quote_kind,work_start_approval_status,work_start_requested_at,completion_approval_status,completion_requested_at,requested_duration_hours,pricing_unit_snapshot,work_timer_elapsed_seconds,work_started_at,work_timer_running')
          .eq('customer_user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      final bookingRows = List<Map<String, dynamic>>.from(response);
      final finalBills = <String, Map<String, dynamic>>{};
      try {
        final bookingIds = bookingRows.map((b) => b['id'].toString()).toList();
        if (bookingIds.isNotEmpty) {
          final billRows = await _client.from('srk_booking_final_bills')
            .select('id,booking_id,bill_number,service_amount,discount_amount,total_amount,status,prepared_at,revision_no')
            .inFilter('booking_id', bookingIds)
            .order('revision_no', ascending: false);
          for (final row in List<Map<String, dynamic>>.from(billRows)) {
            final bookingId = row['booking_id'].toString();
            finalBills.putIfAbsent(bookingId, () => row);
          }
        }
      } catch (_) {
        _complaintLoadWarning = 'अंतिम बिल का विवरण अभी लोड नहीं हो पाया। Refresh करके फिर कोशिश करें।';
      }
      final paymentCycles = <String, Map<String, dynamic>>{};
      final eligibleBookings = bookingRows.where((b) =>
        b['status'] == 'completed' &&
        b['payment_status'] != 'paid' &&
        finalBills.containsKey(b['id'].toString())).toList();
      await Future.wait(eligibleBookings.map((booking) async {
        final bookingId = booking['id'].toString();
        try {
          final rows = await _client.rpc('srk_customer_get_booking_payment_cycle',
            params: {'p_booking_id': bookingId});
          final list = List<Map<String, dynamic>>.from(rows as List);
          paymentCycles[bookingId] = list.isNotEmpty
              ? list.first
              : {'online_required': true, 'cycle_unverified': true};
        } catch (_) {
          // Fail closed in the UI: keep Online available and hide Cash if the
          // server cannot provide the cycle state. The payment RPC still enforces it.
          paymentCycles[bookingId] = {
            'online_required': true,
            'cycle_unverified': true,
          };
        }
      }));
      final contacts = <String, String>{};
      final workerContacts = <String, List<Map<String, dynamic>>>{};
      try {
        final rows = await _client.rpc('srk_customer_get_my_booking_worker_contacts');
        for (final row in List<Map<String, dynamic>>.from(rows as List)) {
          final phone = row['worker_phone']?.toString().trim() ?? '';
          if (phone.isNotEmpty) {
            final bookingId = row['booking_id'].toString();
            workerContacts.putIfAbsent(bookingId, () => []).add({
              'role': row['worker_role']?.toString() ?? 'technician',
              'name': row['worker_name']?.toString() ?? 'SRK Technician',
              'phone': phone,
            });
          }
        }
      } catch (_) {
        _contactLoadWarning = 'स्वीकृत Technician का संपर्क अभी उपलब्ध नहीं है। बुकिंग सुरक्षित है; Refresh करके फिर कोशिश करें।';
      }
      // Legacy electrician contact fallback for existing migrated bookings.
      try {
        final rows = await _client.rpc('srk_customer_get_my_booking_contacts');
        for (final row in List<Map<String, dynamic>>.from(rows as List)) {
          final phone = row['electrician_phone']?.toString().trim() ?? '';
          if (phone.isNotEmpty) contacts[row['booking_id'].toString()] = phone;
        }
      } catch (_) {
        if (_contactLoadWarning == null) {
          _contactLoadWarning = 'Technician का संपर्क अभी लोड नहीं हो पाया। Refresh करके फिर कोशिश करें।';
        }
      }
      try {
        final complaintRows = await _client.rpc('srk_customer_list_booking_complaints');
        _complaints = List<Map<String, dynamic>>.from(complaintRows as List);
      } catch (_) {
        _complaintLoadWarning = 'शिकायतों की सूची अभी लोड नहीं हो पाई। Refresh करके फिर कोशिश करें।';
      }
      _bookings = bookingRows.map((booking) {
        final phone = contacts[booking['id'].toString()] ?? booking['electrician_phone']?.toString();
        return {
          ...booking,
          if (phone != null) 'electrician_phone': phone,
          'worker_contacts': workerContacts[booking['id'].toString()] ?? <Map<String, dynamic>>[],
          if (finalBills[booking['id'].toString()] != null) 'final_bill': finalBills[booking['id'].toString()],
          if (paymentCycles[booking['id'].toString()] != null) 'payment_cycle': paymentCycles[booking['id'].toString()],
        };
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
            initialValue: category,
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


  Future<void> _payOnline(Map<String, dynamic> booking, Map<String, dynamic> bill) async {
    final billId = bill['id']?.toString();
    final bookingId = booking['id']?.toString();
    if (billId == null || bookingId == null) return;
    Razorpay? checkout;
    final done = Completer<String>();
    try {
      final result = await _client.functions.invoke(
        'create-razorpay-checkout-order',
        body: {
          'booking_id': bookingId,
          'idempotency_key': 'srk-checkout-$bookingId',
        },
      );
      final order = Map<String, dynamic>.from(result.data as Map);
      if (order['success'] != true || order['order_id'] == null) {
        throw StateError(order['error']?.toString() ?? order['status']?.toString() ?? 'भुगतान ऑर्डर तैयार नहीं हुआ।');
      }
      checkout = Razorpay();
      checkout.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse p) {
        if (!done.isCompleted) {
          done.complete('Razorpay ने भुगतान response दिया है। अंतिम पुष्टि webhook से होगी; अभी Refresh करके भुगतान स्थिति देखें।');
        }
      });
      checkout.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse p) {
        if (!done.isCompleted) done.complete('भुगतान पूरा नहीं हुआ: ${p.message ?? 'दोबारा कोशिश करें।'}');
      });
      checkout.open({
        'key': order['key_id'],
        'amount': order['amount'],
        'currency': order['currency'] ?? 'INR',
        'order_id': order['order_id'],
        'name': 'SRK ELECTRONIC',
        'description': booking['service_type']?.toString() ?? 'SRK ELECTRONIC Final Bill',
        'prefill': {'contact': _client.auth.currentUser?.phone?.replaceFirst('+91', '') ?? ''},
        'theme': {'color': '#0B5ED7'},
      });
      final message = await done.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => 'भुगतान की अंतिम स्थिति अभी नहीं मिली। दोबारा भुगतान न करें; पहले Refresh करके स्थिति जाँचें।',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        await _loadBookings();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('FunctionException: ', ''))),
      );
    } finally {
      checkout?.clear();
    }
  }

  Future<void> _respondWorkStart(String bookingId, String response) async {
    final approved = response == 'approved';
    if ((await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? 'काम शुरू करने की अनुमति दें?' : 'काम शुरू करने से मना करें?'),
        content: Text(approved
          ? 'आपकी अनुमति के बाद ही Technician काम शुरू कर सकेगा।'
          : 'Technician को काम शुरू करने की अनुमति नहीं मिलेगी।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('वापस')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('पुष्टि करें')),
        ],
      ),
    )) != true) return;
    try {
      await _client.rpc('srk_customer_respond_work_start', params: {
        'p_booking_id': bookingId, 'p_response': response,
      });
      await _loadBookings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _respondWorkCompletion(String bookingId, String response) async {
    String? note;
    if (response == 'disputed' || response == 'rejected') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(response == 'disputed' ? 'काम पर विवाद दर्ज करें' : 'काम पूरा होने से असहमत हैं?'),
          content: TextField(
            controller: controller, maxLines: 4, maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'कारण लिखें',
              hintText: 'समस्या का स्पष्ट विवरण दें (विवाद के लिए कम-से-कम 20 अक्षर)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('जमा करें')),
          ],
        ),
      );
      controller.dispose();
      if (note == null) return;
      if (response == 'disputed' && note.trim().length < 20) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('विवाद का कारण कम-से-कम 20 अक्षरों का होना चाहिए।')));
        return;
      }
    }
    try {
      await _client.rpc('srk_customer_respond_work_completion', params: {
        'p_booking_id': bookingId, 'p_response': response, 'p_note': note,
      });
      await _loadBookings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _choosePaymentMethod(Map<String, dynamic> booking, Map<String, dynamic> bill, String method) async {
    final bookingId = booking['id'].toString();
    final amount = (bill['total_amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('अंतिम बिल की सही राशि उपलब्ध नहीं है।')));
      return;
    }
    try {
      await _client.rpc('srk_customer_choose_payment_method', params: {
        'p_booking_id': bookingId, 'p_method': method,
      });
      if (method == 'cash') {
        final confirmed = await _client.rpc('srk_confirm_cash_payment', params: {
          'p_booking_id': bookingId,
          'p_amount': amount,
          'p_note': 'Customer confirmed cash payment against final bill',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            confirmed == true
              ? 'ग्राहक और Technician दोनों की पुष्टि हो गई। नकद भुगतान सत्यापित है।'
              : 'आपकी नकद भुगतान पुष्टि दर्ज हुई। Technician की पुष्टि बाकी है; भुगतान अभी Paid नहीं माना गया।',
          )));
        }
        await _loadBookings();
      } else {
        await _payOnline(booking, bill);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      await _loadBookings();
    }
  }  Future<void> _openSettings() async {
    final user = _client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final name = (metadata['full_name'] ?? metadata['name'] ?? 'ग्राहक').toString();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ValueListenableBuilder<String>(
            valueListenable: customerLanguage,
            builder: (context, language, _) {
              final english = language == 'en';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(english ? 'Settings' : 'सेटिंग्स', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(english ? 'App language' : 'ऐप की भाषा'),
                    subtitle: DropdownButton<String>(
                      value: language,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (value) async {
                        if (value == null || user == null) return;
                        try {
                          await _client.auth.updateUser(UserAttributes(data: {'customer_language': value}));
                          customerLanguage.value = value;
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text((english ? 'Language could not be saved: ' : 'भाषा सेव नहीं हुई: ') + e.toString())),
                          );
                        }
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(english ? 'Notifications' : 'सूचनाएँ'),
                    subtitle: Text(english ? 'Booking and offer alerts follow device/app permission' : 'बुकिंग और ऑफर की सूचनाएँ ऐप अनुमति के अनुसार'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(name),
                    subtitle: Text((english ? 'Customer ID: ' : 'ग्राहक ID: ') + (user?.id ?? '—')),
                  ),
                  const SizedBox(height: 4),
                  Text(english ? 'Booking form and service details remain in Hindi.' : 'बुकिंग फॉर्म और सर्विस विवरण हिंदी में ही रहेंगे।',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  Future<void> _logout() async {
    await _client.auth.signOut();
  }

  Future<void> _openBookingForm({String? categoryCode}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerBookingFormPage(initialCategoryCode: categoryCode),
    ));
    if (mounted) _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRK ELECTRONIC'),
        actions: [
          TextButton.icon(onPressed: _loading ? null : _loadBookings, icon: const Icon(Icons.refresh), label: Text(customerEnglish ? 'Refresh' : 'रिफ्रेश')),
          PopupMenuButton<String>(
            tooltip: 'अधिक विकल्प',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'delete') _requestAccountDeletion(); if (value == 'logout') _logout(); },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_remove_outlined), title: Text('Account Deletion Request'))),
              PopupMenuItem(value: 'logout', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout), title: Text('Logout'))),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE8F4FF), Color(0xFFF8FBFF), Color(0xFFFFF4E8)])),
        child: Stack(children: [
          Positioned(top: 34, right: -42, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x222B8DEB)))),
          Positioned(bottom: 80, left: -54, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x22F5B544)))),
          RefreshIndicator(
        onRefresh: _loadBookings,
        child: ListView(
          controller: _dashboardScrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _CustomerIdentityHeader(user: _client.auth.currentUser),
            const SizedBox(height: 12),
            const SrkFounderBanner(),
            const SizedBox(height: 14),
            Text(customerEnglish ? 'Choose a service' : 'अपनी सर्विस चुनें', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.25,
              children: [
                _CustomerCategoryTile(code: 'electrician', title: customerEnglish ? 'Electrician' : 'इलेक्ट्रिशियन', icon: Icons.electrical_services),
                _CustomerCategoryTile(code: 'plumber', title: customerEnglish ? 'Plumber' : 'प्लंबर', icon: Icons.plumbing),
                _CustomerCategoryTile(code: 'painter', title: customerEnglish ? 'Painter' : 'पेंटर', icon: Icons.format_paint),
                _CustomerCategoryTile(code: 'ac_fridge_technician', title: customerEnglish ? 'AC + Fridge Technician' : 'एसी और फ्रिज टेक्नीशियन', icon: Icons.ac_unit),
                _CustomerCategoryTile(code: 'motor_pump_technician', title: customerEnglish ? 'Motor & Pump Technician' : 'मोटर और पंप टेक्नीशियन', icon: Icons.water),
                _CustomerCategoryTile(code: 'cooler_technician', title: customerEnglish ? 'Cooler Technician' : 'कूलर टेक्नीशियन', icon: Icons.air),
              ].map((tile) => _CustomerCategoryTile(
                code: tile.code, title: tile.title, icon: tile.icon,
                onTap: () => _openBookingForm(categoryCode: tile.code),
              )).toList(),
            ),
            const SizedBox(height: 18),
            Text(customerEnglish ? 'My bookings' : 'मेरी बुकिंग', key: _bookingsSectionKey,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(customerEnglish ? 'Your OTP-linked bookings and technician quotes appear here.' : 'आपकी OTP-लिंक की गई बुकिंग और इलेक्ट्रिशियन के कोटेशन यहाँ दिखेंगे।'),
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
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: _onBottomNavigation,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: customerEnglish ? 'Home' : 'होम'),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: customerEnglish ? 'Bookings' : 'बुकिंग'),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: customerEnglish ? 'Settings' : 'सेटिंग्स'),
          NavigationDestination(icon: const Icon(Icons.support_agent_outlined), selectedIcon: const Icon(Icons.support_agent), label: customerEnglish ? 'Help' : 'सहायता'),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: customerEnglish ? 'Profile' : 'प्रोफाइल'),
        ],
      ),
    );
  }

  Future<void> _sendSos() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 तत्काल सहायता'),
        content: const Text('यदि आपको तत्काल खतरा है, कारण चुनें। यह अलर्ट SRK Admin के in-app SOS नियंत्रण कक्ष में जाएगा। SMS/Police को स्वतः कॉल या संदेश नहीं जाएगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'customer_at_risk'), child: const Text('मुझे खतरा है')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'electrician_at_risk'), child: const Text('Technician से खतरा')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'violence_or_other_emergency'), child: const Text('मारपीट / अन्य आपात स्थिति')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      final result = await _client.rpc('srk_create_sos_alert', params: {'p_reason': reason});
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

  Widget _bookingCard(Map<String, dynamic> booking) {
    final quoteStatus = booking['quote_status']?.toString() ?? 'not_submitted';
    final status = booking['status']?.toString() ?? '';
    final waitingQuote = quoteStatus == 'pending' && status == 'awaiting_quote_approval';
    final service = (booking['service_charge'] as num?)?.toDouble() ?? 0;
    final quoteTotal = (booking['quoted_amount'] as num?)?.toDouble() ?? service;
    final bill = booking['final_bill'] is Map<String, dynamic>
      ? Map<String, dynamic>.from(booking['final_bill'] as Map) : null;
    final billTotal = (bill?['total_amount'] as num?)?.toDouble() ?? 0;
    final startWaiting = status == 'awaiting_work_start_approval' &&
      booking['work_start_approval_status'] == 'pending';
    final completionWaiting = status == 'in_progress' &&
      booking['completion_approval_status'] == 'pending' &&
      booking['completion_requested_at'] != null;
    final method = (booking['payment_method'] ?? '').toString().toLowerCase();
    final timerRunning = booking['work_timer_running'] == true;
    final showTimer = status == 'in_progress' && booking['work_started_at'] != null;
    final paymentCycle = booking['payment_cycle'] is Map ? Map<String, dynamic>.from(booking['payment_cycle'] as Map) : <String, dynamic>{};
    final onlineOnly = paymentCycle['online_required'] == true;
    final cycleUnverified = paymentCycle['cycle_unverified'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking['service_type']?.toString() ?? 'सर्विस बुकिंग',
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('बुकिंग: ${booking['id']}'),
          Text('स्थिति: ${_status(status)}'),
          if (showTimer) Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(Icons.timer, color: timerRunning ? Colors.green : Colors.orange),
              title: Text(customerEnglish ? 'Work timer' : 'काम का टाइमर'),
              subtitle: Text(_customerTimerText(booking), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              trailing: Text(timerRunning ? (customerEnglish ? 'Running' : 'चालू') : (customerEnglish ? 'Paused' : 'रुका हुआ')),
            ),
          ),
          if ((booking['worker_contacts'] as List? ?? const []).isNotEmpty)
            ...List<Map<String, dynamic>>.from(booking['worker_contacts'] as List).map((worker) {
              final phone = worker['phone'].toString();
              final role = worker['role'] == 'helper' ? 'Helper' : 'Technician';
              return Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.call),
                  title: Text(role + ' — ' + worker['name'].toString()),
                  subtitle: SelectableText(phone),
                  trailing: IconButton(
                    tooltip: 'कॉल करें', icon: const Icon(Icons.call_outlined),
                    onPressed: () => _callPhone(phone),
                  ),
                ),
              );
            })
          else if ((booking['electrician_phone'] ?? '').toString().trim().isNotEmpty &&
              ['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed'].contains(status))
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.call),
                title: const Text('स्वीकृत Technician का मोबाइल नंबर'),
                subtitle: SelectableText(booking['electrician_phone'].toString()),
                trailing: IconButton(
                  tooltip: 'कॉल करें', icon: const Icon(Icons.call_outlined),
                  onPressed: () => _callPhone(booking['electrician_phone'].toString()),
                ),
              ),
            ),
          if (status == 'in_progress' && _bookings.where((b) => b['status'] == 'in_progress').length == 1) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _sendSos,
              icon: const Icon(Icons.sos), label: const Text('🚨 तत्काल सहायता / SOS'),
            )),
          ],
          Text('इलाका: ${booking['district'] ?? ''}, ${booking['state'] ?? ''} • PIN ${booking['pincode'] ?? ''}'),
          if (booking['preferred_date'] != null || booking['preferred_time'] != null)
            Text('पसंदीदा समय: ${booking['preferred_date'] ?? '—'} • ${booking['preferred_time'] ?? '—'}')
          else if (booking['requested_duration_hours'] != null)
            Text('अनुरोधित अवधि: ${booking['requested_duration_hours']} घंटे'),
          if (startWaiting) ...[
            const Divider(),
            const Text('Technician ने काम शुरू करने की अनुमति माँगी है। आपकी मंजूरी से पहले काम शुरू नहीं होगा।',
              style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: () => _respondWorkStart(booking['id'].toString(), 'approved'),
                child: const Text('काम शुरू मंजूर करें')),
              OutlinedButton(onPressed: () => _respondWorkStart(booking['id'].toString(), 'rejected'),
                child: const Text('अभी मंजूर नहीं')),
            ]),
          ],
          if (completionWaiting) ...[
            const Divider(),
            const Text('Technician ने काम पूरा होने की पुष्टि माँगी है। जाँचकर जवाब दें।',
              style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(spacing: 8, runSpacing: 6, children: [
              FilledButton(onPressed: () => _respondWorkCompletion(booking['id'].toString(), 'approved'),
                child: const Text('काम पूरा मंजूर करें')),
              OutlinedButton(onPressed: () => _respondWorkCompletion(booking['id'].toString(), 'rejected'),
                child: const Text('अभी पूरा नहीं')),
              TextButton(onPressed: () => _respondWorkCompletion(booking['id'].toString(), 'disputed'),
                child: const Text('विवाद दर्ज करें')),
            ]),
          ],
          if (quoteStatus != 'not_submitted' && quoteStatus.isNotEmpty) ...[
            const Divider(),
            Text(booking['electrician_quote_kind'] == 'counter_offer' ? 'पुराना Counter Offer' : 'पुराना कोटेशन',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('लेबर चार्ज: ₹${service.toStringAsFixed(2)}'),
            Text('कुल: ₹${quoteTotal.toStringAsFixed(2)}'),
            Text('कोटेशन स्थिति: $quoteStatus'),
            if ((booking['quote_note'] ?? '').toString().isNotEmpty) Text('विवरण: ${booking['quote_note']}'),
            if (waitingQuote) Wrap(spacing: 8, children: [
              FilledButton(onPressed: () => _respondQuote(booking['id'].toString(), 'approved'),
                child: const Text('कोटेशन मंजूर करें')),
              OutlinedButton(onPressed: () => _respondQuote(booking['id'].toString(), 'rejected'),
                child: const Text('अस्वीकार करें')),
            ]),
          ],
          if (bill != null && ['issued','approved'].contains(bill['status'])) ...[
            const Divider(),
            Text('अंतिम बिल • ${bill['bill_number'] ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('लेबर चार्ज: ₹${(bill['service_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
            if (((bill['discount_amount'] as num?)?.toDouble() ?? 0) > 0)
              Text('छूट: ₹${(bill['discount_amount'] as num).toStringAsFixed(2)}'),
            Text('कुल अंतिम बिल: ₹${billTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (status == 'completed' && booking['payment_status'] != 'paid') ...[
              const SizedBox(height: 8),
              if (onlineOnly)
                Text(cycleUnverified
                  ? 'भुगतान क्रम अभी सत्यापित नहीं हो पाया। सुरक्षित भुगतान के लिए केवल Online विकल्प उपलब्ध है।'
                  : 'यह Technician / Helper का तीसरा, छठा या अगला हर तीसरा काम है। इस बुकिंग में केवल Online भुगतान होगा।',
                  style: const TextStyle(fontWeight: FontWeight.w600))
              else if (method == 'unselected' || method.isEmpty)
                const Text('अंतिम बिल के बाद भुगतान का तरीका चुनें।')
              else
                Text('चुना गया भुगतान तरीका: ${booking['payment_method']}'),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (!onlineOnly)
                  FilledButton.icon(
                    onPressed: () => _choosePaymentMethod(booking, bill, 'cash'),
                    icon: const Icon(Icons.payments), label: const Text('नकद पुष्टि करें')),
                OutlinedButton.icon(
                  onPressed: () => _choosePaymentMethod(booking, bill, 'online'),
                  icon: const Icon(Icons.qr_code_2), label: const Text('ऑनलाइन UPI / Checkout')),
              ]),
              if (method == 'cash')
                const Text('नकद तभी Paid होगा जब ग्राहक और Technician दोनों अपनी पुष्टि करेंगे।'),
            ],
          ] else if (status == 'completed')
            const Text('अंतिम बिल Admin द्वारा तैयार होने के बाद भुगतान विकल्प दिखाई देंगे।'),
          if (status == 'new')
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () => _cancelBooking(booking['id'].toString()),
              icon: const Icon(Icons.cancel_outlined), label: const Text('बुकिंग रद्द करें'),
            )),
          if (status != 'cancelled')
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () => _createComplaint(booking['id'].toString()),
              icon: const Icon(Icons.support_agent), label: const Text('शिकायत / सहायता'),
            )),
          if (booking['payment_status'] == 'paid')
            const Text('भुगतान प्राप्त और सत्यापित', style: TextStyle(color: Colors.green,fontWeight:FontWeight.bold)),
        ]),
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

class _CustomerIdentityHeader extends StatelessWidget {
  const _CustomerIdentityHeader({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final name = (metadata['full_name'] ?? metadata['name'] ?? 'ग्राहक').toString();
    final photo = (metadata['avatar_url'] ?? metadata['picture'] ?? '').toString();
    final customerId = user?.id ?? '—';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: const Color(0xFFE5F0FF),
              backgroundImage: photo.startsWith('https://') ? NetworkImage(photo) : null,
              child: photo.startsWith('https://') ? null : const Icon(Icons.person, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  const Text('Customer Unique ID', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  SelectableText(customerId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.verified_user_outlined, color: Color(0xFF2677C9)),
          ],
        ),
      ),
    );
  }
}

class _CustomerCategoryTile extends StatelessWidget {
  const _CustomerCategoryTile({required this.code, required this.title, required this.icon, this.onTap});
  final String code, title;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 26),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2)),
          const Icon(Icons.chevron_right),
        ]),
      ),
    ),
  );
}

class CustomerBookingFormPage extends StatefulWidget {
  const CustomerBookingFormPage({super.key, this.initialCategoryCode});
  final String? initialCategoryCode;
  @override
  State<CustomerBookingFormPage> createState() => _CustomerBookingFormPageState();
}

class _CustomerBookingFormPageState extends State<CustomerBookingFormPage> {
  final _formKey = GlobalKey<FormState>();
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
  }

  @override
  void dispose() {
    _state.dispose();
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
      List<Placemark> placemarks = [];
      try {
        placemarks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
      } catch (_) {
        // Keep GPS coordinates even if the device geocoder is unavailable.
      }
      if (!mounted) return;
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      setState(() {
        _locationLat = pos.latitude;
        _locationLng = pos.longitude;
        if (place != null) {
          final stateName = (place.administrativeArea ?? '').trim();
          final districtName = (place.subAdministrativeArea ?? place.locality ?? '').trim();
          final pin = (place.postalCode ?? '').replaceAll(RegExp('[^0-9]'), '');
          if (stateName.isNotEmpty) _state.text = stateName;
          if (districtName.isNotEmpty) _district.text = districtName;
          if (pin.length == 6 && int.tryParse(pin) != null) _pincode.text = pin;
          final addressParts = <String?>[place.name, place.subLocality, place.thoroughfare, place.locality]
              .where((part) => part != null && part.trim().isNotEmpty)
              .map((part) => part!.trim()).toSet().toList();
          if (addressParts.isNotEmpty && _address.text.trim().isEmpty) {
            _address.text = addressParts.join(', ');
          }
        }
      });
      final locationMessage = place != null && (place.administrativeArea ?? '').trim().isNotEmpty
          ? 'GPS लोकेशन जुड़ गई। राज्य/जिला/PIN अपने-आप भरे गए हैं—कृपया पुष्टि करें।'
          : 'GPS coordinates जुड़ गए। पता अपने-आप नहीं मिल सका; कृपया मैन्युअल भरें।';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locationMessage)));
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
    if (_state.text.trim().isEmpty || _district.text.trim().isEmpty || _pincode.text.trim().length != 6 || _address.text.trim().isEmpty) {
      setState(() { _priceError = 'पहले राज्य, जिला, 6 अंकों का PIN Code और पूरा पता भरें।'; _pricePreview = null; _priceBusy = false; });
      return;
    }
    setState(() { _priceBusy = true; _priceError = null; _pricePreview = null; });
    try {
      final data = await _client.rpc('srk_customer_preview_booking_price_v3', params: {
        'p_category_id': selection.categoryId,
        'p_service_type_id': selection.serviceTypeId,
        'p_skill_id': selection.skillId,
        'p_skill_level_id': selection.skillLevelId,
        'p_state': _state.text.trim(),
        'p_district': _district.text.trim(),
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
      final response = await _client.rpc('srk_customer_create_booking_v2', params: {
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
      onChanged: (_) {
        if (identical(controller, _state) || identical(controller, _district) ||
            identical(controller, _pincode) || identical(controller, _address)) {
          if (_pricePreview != null || _priceError != null) {
            setState(() { _pricePreview = null; _priceError = null; });
          }
        }
      },
      validator: validator ?? (v) => _required(v, label),
    ),
  );

  String _money(dynamic value) => '₹${(value as num?)?.toStringAsFixed(2) ?? '—'}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('नई सर्विस बुकिंग')),
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE8F4FF), Color(0xFFF8FBFF), Color(0xFFFFF4E8)])),
      child: SafeArea(child: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: const [
          Icon(Icons.verified_user, color: Colors.green), SizedBox(width: 10),
          Expanded(child: Text('बुकिंग आपके OTP-verified मोबाइल खाते से जुड़ेगी। भुगतान काम पूरा होने और अंतिम बिल बनने के बाद ही होगा।')),
        ]))),
        Text('1. सर्विस कैटेगरी और स्तर चुनें', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SrkServiceCategoryPicker(
          initialCategoryCode: widget.initialCategoryCode,
          onSelection: (selection) {
            setState(() {
              _selection = selection;
              _pricePreview = null;
              _priceError = null;
              if (selection == null || !selection.helperAvailable) _helperCount = 0;
            });
          },
        ),
        if (_selection != null) ...[
          const SizedBox(height: 10),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(
            '${_selection!.categoryName} • ${_selection!.skillLevelName}\n${_selection!.serviceName} • ${_selection!.skillName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ))),
          Text('2. कितने लोग चाहिए?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _technicianCount, decoration: _decoration('कितने Technician चाहिए?'),
            items: List.generate(10, (i) => i + 1).map((v)=>DropdownMenuItem(value:v,child:Text('$v टेक्नीशियन'))).toList(),
            onChanged: (v) { setState(() { _technicianCount=v??1; _pricePreview=null; }); },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _helperCount, decoration: _decoration('कितने Helper चाहिए?'),
            items: List.generate(_selection!.pricingUnit == 'hour' && _selection!.helperAvailable ? 11 : 1, (i) => i)
              .map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'हेल्पर नहीं':'$v हेल्पर'))).toList(),
            onChanged: _selection!.pricingUnit == 'hour' && _selection!.helperAvailable
              ? (v) { setState(() { _helperCount=v??0; _pricePreview=null; }); }
              : null,
          ),
          const SizedBox(height: 8),
          if (_selection!.pricingUnit == 'hour') ...[
            Text('3. कितने समय के लिए काम चाहिए?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _durationHours,
              decoration: _decoration('काम की कुल अवधि (घंटे / दिन)'),
              items: [
                ...List.generate(23, (i) => i + 1).map((hours) =>
                  DropdownMenuItem(value: hours, child: Text('$hours घंटे'))),
                ...List.generate(60, (i) => i + 1).map((days) =>
                  DropdownMenuItem(value: days * 24, child: Text('$days दिन'))),
              ],
              onChanged: (v) { setState(() { _durationHours=v??1; _pricePreview=null; }); },
            ),
          ] else if (_selection!.pricingUnit == 'per_item') ...[
            DropdownButtonFormField<int>(
              initialValue: _unitCount, decoration: _decoration('कितने Cooler / Unit'),
              items: List.generate(10,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v यूनिट'))).toList(),
              onChanged: (v) { setState(() { _unitCount=v??1; _pricePreview=null; }); },
            ),
          ] else if (_selection!.pricingUnit == 'motor_hp') ...[
            Text('Motor / Pump का निर्धारित HP रेट लागू होगा।'),
          ],
        ],
        const SizedBox(height: 14),
        Text('4. काम की लोकेशन', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _field(_state, 'राज्य', maxLength: 100),
        _field(_district, 'जिला', maxLength: 100),
        _field(_pincode, '6 अंकों का PIN Code', keyboard: TextInputType.number, maxLength: 6,
          validator: (v) => RegExp(r'^[0-9]{6}$').hasMatch(v?.trim() ?? '') ? null : 'सही 6 अंकों का PIN Code भरें'),
        _field(_address, 'पूरा पता / मकान / गली', maxLines: 3, maxLength: 1000),
        OutlinedButton.icon(
          onPressed: _locationBusy ? null : _useCurrentLocation,
          icon: _locationBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
          label: Text(_locationBusy ? 'GPS लोकेशन ली जा रही है…' : (_locationLat == null ? 'GPS से वर्तमान लोकेशन जोड़ें' : 'GPS लोकेशन जुड़ गई • दोबारा चुनें')),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 14),
        Text('5. अनुमानित कीमत देखें', style: Theme.of(context).textTheme.titleMedium),
        OutlinedButton.icon(
          onPressed: _selection == null || _priceBusy ? null : _refreshPricePreview,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('लोकेशन के अनुसार अनुमानित कीमत देखें'),
        ),
        if (_priceBusy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
        if (_priceError != null) Text(_priceError!, style: const TextStyle(color: Colors.red)),
        if (_pricePreview != null)
          Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('अनुमानित सर्विस चार्ज', style: Theme.of(context).textTheme.titleMedium),
              Text(_money(_pricePreview!['estimated_customer_total']), style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
              Text((_pricePreview!['price_note']??'').toString()),
            ]))),
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(padding: EdgeInsets.all(14), child: Text(
            'सभी विवरण और अनुमानित कीमत जाँचने के बाद बुकिंग भेजें। योग्य और उपलब्ध Technician/Helper को ऑफर भेजा जाएगा। कोई अग्रिम भुगतान नहीं।')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting || _selection == null || _pricePreview == null || _priceBusy ? null : _submit,
          icon: _submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.send),
          label: Text(_submitting ? 'बुकिंग भेजी जा रही है…' : 'अंतिम चरण: बुकिंग भेजें'),
        ),
        const SizedBox(height: 24),
      ]),
    )),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';
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
    appBar: AppBar(title: const Text('SRK ELECTRONIC — Electrician')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SrkWelcomeHeader(),
          Text('इलेक्ट्रिशियन लॉगिन', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
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
  Map<String, dynamic>? profile, wallet;
  List<Map<String, dynamic>> offers = [], offerDetails = [], earnings = [], offerPriceDetails = [], bookingDetails = [];
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
        final offerDetailRows = await client.rpc('srk_get_my_offer_details');
        offerDetails = List<Map<String, dynamic>>.from(offerDetailRows as List);
        final priceDetailsRows = await client.rpc('srk_get_my_offer_price_details');
        offerPriceDetails = List<Map<String, dynamic>>.from(priceDetailsRows as List);
        final bookingRows = await client.rpc('srk_get_my_assigned_booking_quote_details');
        final contactRows = await client.rpc('srk_electrician_get_my_assigned_booking_contacts');
        final customerPhones = <String, String>{};
        for (final row in List<Map<String, dynamic>>.from(contactRows as List)) {
          final phone = row['customer_phone']?.toString().trim() ?? '';
          if (phone.isNotEmpty) customerPhones[row['booking_id'].toString()] = phone;
        }
        bookingDetails = List<Map<String, dynamic>>.from(bookingRows as List).map((booking) {
          final phone = customerPhones[booking['booking_id'].toString()];
          return {...booking, if (phone != null) 'customer_phone': phone};
        }).toList();
        final earningRows = await client.rpc('srk_get_my_earnings');
        earnings = List<Map<String, dynamic>>.from(earningRows as List);
        final walletResult = await client.rpc('srk_get_my_wallet_summary');
        final walletData = Map<String, dynamic>.from(walletResult as Map);
        final partnerWallet = walletData['electrician'];
        wallet = partnerWallet == null ? null : Map<String, dynamic>.from(partnerWallet as Map);
      } else { offers = []; offerDetails = []; earnings = []; offerPriceDetails = []; bookingDetails = []; wallet = null; }
    } catch (_) { error = 'डैशबोर्ड लोड नहीं हो सका। इंटरनेट जाँचकर Refresh करें।'; }
    finally { if (mounted) setState(() => loading = false); }
  }


  Future<void> confirmCashPayment(Map<String,dynamic> booking) async {
    final ok = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('नकद भुगतान की पुष्टि'),
      content:Text('क्या ग्राहक से ₹${booking['quoted_amount'] ?? 0} नकद वास्तव में मिल गए हैं?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('नहीं')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('हाँ, नकद मिला'))],
    ));
    if(ok!=true)return;
    try {
      await client.rpc('srk_electrician_confirm_cash_payment',params:{'p_booking_id':booking['booking_id']});
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('नकद भुगतान दर्ज हो गया।')));
      await load();
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('नकद भुगतान दर्ज नहीं हुआ। बुकिंग और भुगतान तरीका जाँचें।')));
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
    'assigned' => 'इलेक्ट्रिशियन नियुक्त',
    'inspection' => 'जाँच / निरीक्षण',
    'awaiting_quote_approval' => 'ग्राहक की कोटेशन मंजूरी बाकी',
    'quote_approved' => 'कोटेशन मंजूर',
    'quote_rejected' => 'ग्राहक ने कोटेशन में बदलाव माँगा',
    'in_progress' => 'काम जारी',
    'completed' => 'काम पूरा',
    _ => status ?? 'स्थिति उपलब्ध नहीं',
  };

  Future<void> respondToOffer(Map<String, dynamic> offer, String response) async {
    final accept = response == 'accepted';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accept ? 'बुकिंग ऑफर स्वीकार करें?' : 'बुकिंग ऑफर मना करें?'),
        content: Text(accept
          ? 'स्वीकार करते ही यह बुकिंग आपके नाम नियुक्त हो जाएगी। दूसरे इलेक्ट्रिशियन के ऑफर बंद हो जाएँगे।'
          : 'यह ऑफर आपकी सूची से हट जाएगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('वापस')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(accept ? 'स्वीकार करें' : 'मना करें')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await client.rpc('srk_respond_to_offer', params: {
        'p_offer_id': offer['offer_id'], 'p_response': response,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? 'बुकिंग आपके नाम नियुक्त हो गई।' : 'ऑफर मना कर दिया गया।')));
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ऑफर अपडेट नहीं हुआ। संभव है बुकिंग किसी दूसरे इलेक्ट्रिशियन को मिल गई हो।')));
      await load();
    }
  }

  Future<void> updateWorkStatus(String bookingId, String nextStatus, String label) async {
    try {
      await client.rpc('srk_update_booking_work_status', params: {
        'p_booking_id': bookingId, 'p_status': nextStatus,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('बुकिंग की स्थिति अपडेट नहीं हुई। पहले ग्राहक की कोटेशन मंजूरी जाँचें।')));
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
        IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => client.auth.signOut(), icon: const Icon(Icons.logout)),
      ]),
      body: RefreshIndicator(onRefresh: load, child: loading
        ? ListView(children: const [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
        : ListView(padding: const EdgeInsets.all(16), children: [
          const SrkFounderBanner(),
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
              final suggested = (detail['customer_suggested_amount'] as num?)?.toDouble();
              final service = (detail['service_charge'] as num?)?.toDouble();
              final materials = (detail['materials_amount'] as num?)?.toDouble();
              final kind = detail['electrician_quote_kind']?.toString() ?? 'electrician_quote';
              return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('बुकिंग ' + (detail['booking_id']?.toString() ?? '—'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (suggested != null) Text('ग्राहक की शुरुआती कीमत: ₹' + suggested.toStringAsFixed(2)),
                  if (service != null && materials != null) ...[
                    const Divider(),
                    Text(kind == 'counter_offer' ? 'आपका Counter Offer' : kind == 'matches_suggestion' ? 'ग्राहक की कीमत के अनुसार कोटेशन' : 'आपका कोटेशन'),
                    Text('मेहनताना / सर्विस: ₹' + service.toStringAsFixed(2)),
                    Text('सामान / पार्ट्स: ₹' + materials.toStringAsFixed(2)),
                    Text('कुल: ₹' + (service + materials).toStringAsFixed(2)),
                    Text('स्थिति: ' + (detail['quote_status']?.toString() ?? '—')),
                  ],
                  if ((detail['quote_note'] ?? '').toString().isNotEmpty) Text('नोट: ' + detail['quote_note'].toString()),
                ],
              )));
            }),

            Text('मेरी नियुक्त बुकिंग और कोटेशन', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (bookingDetails.where((b) => ['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed'].contains(b['booking_status'])).isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कोई नियुक्त बुकिंग उपलब्ध नहीं है। नई बुकिंग स्वीकार होने के बाद यहाँ कोटेशन भेज सकेंगे।')))
            else ...bookingDetails.where((b) => ['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed'].contains(b['booking_status'])).map((booking) {
              final status = booking['booking_status']?.toString();
              final canQuote = ['assigned','inspection','quote_rejected'].contains(status);
              final service = (booking['service_charge'] as num?)?.toDouble();
              final materials = (booking['materials_amount'] as num?)?.toDouble();
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
                  if(status=='completed' && (booking['payment_method'] ?? '').toString().toLowerCase()=='cash' && booking['payment_status']!='paid')
                    FilledButton.icon(onPressed:()=>confirmCashPayment(booking),icon:const Icon(Icons.payments),label:Text('नकद भुगतान मिला • ₹${booking['quoted_amount'] ?? 0}')),
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
                  if (service != null) Text('मेहनताना: ₹' + service.toStringAsFixed(2)),
                  if (materials != null) Text('सामान: ₹' + materials.toStringAsFixed(2)),
                  if (total != null) Text('कुल कोटेशन: ₹' + total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if ((booking['quote_note'] ?? '').toString().isNotEmpty) Text('नोट: ' + booking['quote_note'].toString()),
                  if (status == 'assigned')
                    Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
                      onPressed: loading ? null : () => updateWorkStatus(booking['booking_id'].toString(), 'inspection', 'निरीक्षण शुरू हो गया।'),
                      icon: const Icon(Icons.search), label: const Text('निरीक्षण शुरू करें'),
                    )),
                  if (status == 'quote_approved')
                    Align(alignment: Alignment.centerRight, child: FilledButton.icon(
                      onPressed: loading ? null : () => updateWorkStatus(booking['booking_id'].toString(), 'in_progress', 'काम शुरू दर्ज हो गया।'),
                      icon: const Icon(Icons.play_arrow), label: const Text('काम शुरू करें'),
                    )),
                  if (status == 'in_progress')
                    Align(alignment: Alignment.centerRight, child: FilledButton.icon(
                      onPressed: loading ? null : () => updateWorkStatus(booking['booking_id'].toString(), 'completed', 'काम पूरा दर्ज हो गया।'),
                      icon: const Icon(Icons.task_alt), label: const Text('काम पूरा करें'),
                    )),
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
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('ग्राहक का पूरा मोबाइल नंबर केवल आपकी नियुक्त बुकिंग में दिखता है।'))),
          ],
        ]),
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
  final materialsController = TextEditingController(text: '0');
  final noteController = TextEditingController();
  bool saving = false;
  String? formError;

  @override
  void dispose() {
    serviceController.dispose();
    materialsController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final service = double.tryParse(serviceController.text.trim());
    final materials = double.tryParse(materialsController.text.trim());
    if (service == null || service <= 0 || materials == null || materials < 0 ||
        service > 10000000 || materials > 10000000) {
      setState(() => formError =
          'सही रकम भरें। मेहनताना शून्य से अधिक और सामान की रकम शून्य या अधिक होनी चाहिए।');
      return;
    }

    setState(() {
      saving = true;
      formError = null;
    });
    try {
      await widget.client.rpc('srk_submit_booking_quote', params: {
        'p_booking_id': widget.bookingId,
        'p_service_charge': service,
        'p_materials_amount': materials,
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
          const Text('मेहनताना और सामान की कीमत अलग-अलग भरें। कुल रकम ग्राहक की मंजूरी के बाद ही मान्य होगी।'),
          const SizedBox(height: 12),
          TextField(
            controller: serviceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'मेहनताना / सर्विस चार्ज (₹)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: materialsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'सामान / पार्ट्स (₹)'),
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

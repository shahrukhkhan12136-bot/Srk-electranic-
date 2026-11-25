import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'srk_work_confirmation_contract.dart';

enum SrkAppRole { customer, electrician, admin }

String roleTitle(SrkAppRole role) => switch (role) {
      SrkAppRole.customer => 'Customer App',
      SrkAppRole.electrician => 'Electrician App',
      SrkAppRole.admin => 'Admin App',
    };

Future<void> initializeSrkSupabase() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (url.isEmpty || key.isEmpty || url.contains('YOUR_PROJECT')) {
    throw StateError(
      'SUPABASE_URL और SUPABASE_ANON_KEY dart-define से सेट करें।',
    );
  }

  await Supabase.initialize(url: url, anonKey: key);
}

class SrkMobileApp extends StatelessWidget {
  const SrkMobileApp({super.key, required this.role});

  final SrkAppRole role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRK ELECTRONIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E8B)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: SrkLoginPage(role: role),
    );
  }
}

class SrkLoginPage extends StatefulWidget {
  const SrkLoginPage({super.key, required this.role});

  final SrkAppRole role;

  @override
  State<SrkLoginPage> createState() => _SrkLoginPageState();
}

class _SrkLoginPageState extends State<SrkLoginPage> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _message;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _normalizedPhone() {
    final raw = _phone.text.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (raw.startsWith('+') && digits.length >= 10 && digits.length <= 15) {
      return '+$digits';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final phone = _normalizedPhone();
    if (phone == null) {
      setState(() => _message = 'सही मोबाइल नंबर दर्ज करें।');
      return;
    }
    await _run(() async {
      await _client.auth.signInWithOtp(phone: phone);
      if (mounted) setState(() {
        _otpSent = true;
        _message = 'OTP भेजा गया है। SMS से मिला OTP यहाँ दर्ज करें।';
      });
    });
  }

  Future<void> _verifyOtp() async {
    final phone = _normalizedPhone();
    final token = _otp.text.trim();
    if (phone == null || token.isEmpty) {
      setState(() => _message = 'मोबाइल नंबर और OTP दोनों भरें।');
      return;
    }
    await _run(() async {
      await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      if (mounted) setState(() => _message = 'मोबाइल OTP सत्यापित हुआ।');
    });
  }

  Future<void> _adminLogin() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Admin ईमेल और पासवर्ड भरें।');
      return;
    }
    await _run(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
      final allowed = await _client.rpc('is_srk_admin');
      if (allowed != true) {
        await _client.auth.signOut();
        throw StateError('इस खाते को Admin अनुमति नहीं मिली।');
      }
      if (mounted) setState(() => _message = 'Admin सत्यापन सफल हुआ।');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = 'प्रक्रिया पूरी नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await _client.auth.signOut();
    if (mounted) setState(() {
      _otpSent = false;
      _message = 'आप लॉगआउट हो गए हैं।';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    if (user != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SRK ELECTRONIC'),
          actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user, size: 48),
                    const SizedBox(height: 12),
                    Text(roleTitle(widget.role),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('लॉगिन सत्यापित है। अगला चरण मौजूदा SRK backend के सुरक्षित dashboard modules जोड़ना है।',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(user.email ?? user.phone ?? user.id,
                        textAlign: TextAlign.center),
                    if (_message != null) Text(_message!),
                    const SizedBox(height: 12),
                    const Chip(label: Text('Dashboard integration बाकी है')),
                    OutlinedButton(onPressed: _logout, child: const Text('Logout')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isAdmin = widget.role == SrkAppRole.admin;
    return Scaffold(
      appBar: AppBar(title: const Text('SRK ELECTRONIC')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SrkWelcomeHeader(),
                    const SizedBox(height: 10),
                    Text(roleTitle(widget.role),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF073B91),
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 16),
                    if (isAdmin) ...[
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'Admin ईमेल'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'पासवर्ड'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _adminLogin,
                        child: const Text('Admin Login'),
                      ),
                      const Text(
                        'लॉगिन के बाद server-side is_srk_admin() जाँच अनिवार्य है।',
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'रजिस्टर्ड मोबाइल नंबर',
                          hintText: '10 अंकों का मोबाइल नंबर',
                        ),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: const InputDecoration(labelText: 'SMS OTP'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : (_otpSent ? _verifyOtp : _sendOtp),
                        child: Text(_otpSent ? 'OTP सत्यापित करें' : 'OTP भेजें'),
                      ),
                      const Text(
                        'किसी दूसरे फोन पर उपयोग करने पर भी रजिस्टर्ड नंबर का OTP सत्यापन जरूरी होगा।',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_busy) const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Loads the founder artwork from a text-encoded bundled asset.
class _SrkFounderImage extends StatelessWidget {
  const _SrkFounderImage({this.fit = BoxFit.contain, this.alignment = Alignment.center});
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: rootBundle.loadString('packages/srk_mobile_core/assets/founder.webp.b64'),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        try {
          final encoded = snapshot.data!.replaceAll(RegExp(r'\\s+'), '');
          return Image.memory(base64Decode(encoded), fit: fit, alignment: alignment,
            errorBuilder: (_, __, ___) => const _SrkFounderFallback());
        } catch (_) {
          return const _SrkFounderFallback();
        }
      }
      return snapshot.hasError ? const _SrkFounderFallback()
        : const Center(child: CircularProgressIndicator(strokeWidth: 2));
    },
  );
}

class _SrkFounderFallback extends StatelessWidget {
  const _SrkFounderFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFEAF2FF), alignment: Alignment.center,
    child: const Text('SRK ELECTRONIC', style: TextStyle(
      color: Color(0xFF073B91), fontSize: 24, fontWeight: FontWeight.w900)),
  );
}

/// Branded welcome artwork shown before login in both mobile apps.
/// Full-width, uncropped SRK ELECTRONIC welcome poster shared by both mobile apps.
class SrkWelcomeHeader extends StatelessWidget {
  const SrkWelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: 0.8008,
      child: const _SrkFounderImage(
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    ),
  );
}

/// Branded dashboard banner with a compact founder portrait on the left.
class SrkFounderBanner extends StatelessWidget {
  const SrkFounderBanner({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final portraitWidth = compact ? 88.0 : 108.0;
    final portraitHeight = compact ? 92.0 : 116.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: compact ? 112 : 142),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF062B70), Color(0xFF0759C7), Color(0xFF0876E8)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -42,
              child: Icon(Icons.bolt, size: compact ? 128 : 164,
                  color: Colors.white.withValues(alpha: .08)),
            ),
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 9 : 12, compact ? 9 : 12, compact ? 8 : 10,
                    compact ? 9 : 12,
                  ),
                  child: Container(
                    width: portraitWidth,
                    height: portraitHeight,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC928),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: const _SrkFounderImage(
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 5 : 8, compact ? 12 : 16, compact ? 12 : 18,
                      compact ? 12 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, color: Color(0xFFFFD447), size: 20),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'SRK ELECTRONIC',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 15 : 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'आपकी सेवा में हमेशा तैयार...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .96),
                            fontSize: compact ? 12 : 14,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 4,
                          width: compact ? 62 : 82,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC928),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(height: 3, color: const Color(0xFFFFC928)),
            ),
          ],
        ),
      ),
    );
  }
}
export 'srk_service_selection_contract.dart';

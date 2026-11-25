import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerApplicationPage extends StatefulWidget {
  const WorkerApplicationPage({super.key, this.onSubmitted});
  final Future<void> Function()? onSubmitted;
  @override
  State<WorkerApplicationPage> createState() => _WorkerApplicationPageState();
}

class _WorkerApplicationPageState extends State<WorkerApplicationPage> {
  final client = Supabase.instance.client;
  final name = TextEditingController();
  final father = TextEditingController();
  final address = TextEditingController();
  final state = TextEditingController();
  final district = TextEditingController();
  final pincode = TextEditingController();
  final experience = TextEditingController(text: '0');
  final about = TextEditingController();
  late String phone;
  String workerType = 'technician';
  String? categoryId;
  DateTime? dateOfBirth;
  PlatformFile? photo;
  PlatformFile? identity;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> policies = [];
  final Map<String, bool> accepted = {};
  bool loading = true, saving = false;
  String? message, error;

  @override
  void initState() {
    super.initState();
    phone = (client.auth.currentUser?.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('91') && phone.length == 12) phone = phone.substring(2);
    load();
  }

  @override
  void dispose() {
    name.dispose(); father.dispose(); address.dispose(); state.dispose();
    district.dispose(); pincode.dispose(); experience.dispose(); about.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final rows = await client.from('srk_service_categories')
          .select('id,category_name').eq('is_active', true).order('sort_order');
      categories = List<Map<String, dynamic>>.from(rows);
      if (categories.isNotEmpty) categoryId = categories.first['id'].toString();
      await loadPolicies();
    } catch (_) {
      error = 'आवेदन फॉर्म लोड नहीं हुआ। इंटरनेट और Database की जाँच करें।';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadPolicies() async {
    accepted.clear();
    try {
      final result = await client.rpc('srk_get_registration_policy_documents',
          params: {'p_worker_type': workerType, 'p_language_code': 'hi'});
      policies = List<Map<String, dynamic>>.from(result as List);
    } catch (_) {
      policies = [];
    }
    if (mounted) setState(() {});
  }

  Future<PlatformFile?> pickFile({required bool isPhoto}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isPhoto ? ['jpg', 'jpeg', 'png'] : ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final limit = isPhoto ? 10 * 1024 * 1024 : 20 * 1024 * 1024;
    if (file.bytes == null || file.size <= 0 || file.size > limit) {
      throw StateError(isPhoto
          ? 'फोटो 10 MB से कम और JPEG/PNG होना चाहिए।'
          : 'पहचान दस्तावेज़ 20 MB से कम और JPEG/PNG/PDF होना चाहिए।');
    }
    return file;
  }

  Future<String> upload(PlatformFile file, String kind) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Login session समाप्त हो गया।');
    final ext = (file.extension ?? 'jpg').toLowerCase();
    final path = user.id + '/applications/' +
        DateTime.now().microsecondsSinceEpoch.toString() + '_' + kind + '.' + ext;
    final mime = ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
    await client.storage.from('srk-worker-kyc').uploadBinary(
      path, file.bytes!, fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    return path;
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (date != null && mounted) setState(() => dateOfBirth = date);
  }

  bool get hasPolicies => policies.length == 2 &&
      policies.any((p) => p['policy_type'] == 'terms') &&
      policies.any((p) => p['policy_type'] == 'privacy') &&
      policies.every((p) => accepted[p['id'].toString()] == true);

  Future<void> submit() async {
    if (saving) return;
    final user = client.auth.currentUser;
    if (user == null || phone.length != 10) {
      setState(() => error = 'सत्यापित मोबाइल OTP से Login आवश्यक है।');
      return;
    }
    final years = int.tryParse(experience.text.trim());
    if (name.text.trim().length < 2 || father.text.trim().length < 2 ||
        address.text.trim().length < 5 || state.text.trim().isEmpty ||
        district.text.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(pincode.text.trim()) ||
        categoryId == null || dateOfBirth == null || photo == null || identity == null ||
        years == null || years < 0 || years > 60) {
      setState(() => error = 'सभी आवश्यक विवरण, जन्मतिथि, फोटो और Aadhaar/पहचान दस्तावेज़ भरें।');
      return;
    }
    if (!hasPolicies) {
      setState(() => error = 'वर्तमान Hindi Terms और Privacy Policy पढ़कर दोनों की सहमति दें।');
      return;
    }
    setState(() { saving = true; error = null; message = 'आवेदन सुरक्षित किया जा रहा है…'; });
    try {
      for (final policy in policies) {
        await client.rpc('srk_record_registration_policy_consent', params: {
          'p_worker_type': workerType,
          'p_policy_document_id': policy['id'],
          'p_user_agent': 'SRK ELECTRONIC Android App',
        });
      }
      final placeholder = user.id + '/applications/pending_photo_upload';
      final params = <String, dynamic>{
        'p_worker_type': workerType,
        'p_category_id': categoryId,
        'p_full_name': name.text.trim(),
        'p_phone': phone,
        'p_father_name': father.text.trim(),
        'p_date_of_birth': dateOfBirth!.toIso8601String().substring(0, 10),
        'p_photo_path': placeholder,
        'p_address': address.text.trim(),
        'p_state': state.text.trim(),
        'p_district': district.text.trim(),
        'p_pincode': pincode.text.trim(),
        'p_experience_years': years,
        'p_about': about.text.trim(),
      };
      final first = await client.rpc('srk_submit_worker_application', params: params);
      final application = Map<String, dynamic>.from(first as Map);
      final appId = application['id']?.toString();
      if (appId == null || appId.isEmpty) throw StateError('आवेदन ID नहीं मिली।');

      final photoPath = await upload(photo!, 'photo');
      final identityPath = await upload(identity!, 'identity');
      final photoExt = (photo!.extension ?? '').toLowerCase();
      final identityExt = (identity!.extension ?? '').toLowerCase();
      await client.rpc('srk_submit_worker_document', params: {
        'p_document_type': 'photo',
        'p_storage_path': photoPath,
        'p_file_name': photo!.name,
        'p_mime_type': photoExt == 'png' ? 'image/png' : 'image/jpeg',
        'p_file_size_bytes': photo!.size,
        'p_application_id': appId,
      });
      await client.rpc('srk_submit_worker_document', params: {
        'p_document_type': 'identity_proof',
        'p_storage_path': identityPath,
        'p_file_name': identity!.name,
        'p_mime_type': identityExt == 'pdf' ? 'application/pdf' : identityExt == 'png' ? 'image/png' : 'image/jpeg',
        'p_file_size_bytes': identity!.size,
        'p_application_id': appId,
      });
      params['p_photo_path'] = photoPath;
      await client.rpc('srk_submit_worker_application', params: params);
      if (!mounted) return;
      setState(() {
        message = 'आवेदन भेज दिया गया है। Admin द्वारा दस्तावेज़ और Skill सत्यापित होने के बाद ही काम के ऑफर मिलेंगे।';
        photo = null; identity = null;
      });
      await widget.onSubmitted?.call();
    } catch (e) {
      if (mounted) setState(() => error =
          'आवेदन पूरा नहीं हुआ: ' + e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(TextEditingController controller, String label,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller, keyboardType: keyboard, maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Technician / Helper Registration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('एक ही App में Technician और Helper अलग-अलग आवेदन और Permanent Worker ID के साथ जुड़ेंगे।'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: workerType,
            decoration: const InputDecoration(labelText: 'आप किस रूप में जुड़ना चाहते हैं?'),
            items: const [
              DropdownMenuItem(value: 'technician', child: Text('Technician')),
              DropdownMenuItem(value: 'helper', child: Text('Helper')),
            ],
            onChanged: saving ? null : (v) async {
              if (v == null) return;
              setState(() => workerType = v);
              await loadPolicies();
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: categoryId,
            decoration: const InputDecoration(labelText: 'मुख्य Service Category'),
            items: categories.map((c) => DropdownMenuItem(
              value: c['id'].toString(), child: Text(c['category_name'].toString()),
            )).toList(),
            onChanged: saving ? null : (v) => setState(() => categoryId = v),
          ),
          const SizedBox(height: 10),
          field(name, 'पूरा नाम'),
          field(father, 'पिता का नाम'),
          TextFormField(
            initialValue: phone, readOnly: true,
            decoration: const InputDecoration(
              labelText: 'OTP से सत्यापित मोबाइल नंबर',
              helperText: 'यह नंबर आपके Login OTP से लिया गया है।',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : chooseDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(dateOfBirth == null ? 'जन्मतिथि चुनें' :
              'जन्मतिथि: ' + dateOfBirth!.day.toString() + '/' +
              dateOfBirth!.month.toString() + '/' + dateOfBirth!.year.toString()),
          ),
          field(address, 'पूरा पता', maxLines: 2),
          field(state, 'राज्य'),
          field(district, 'जिला'),
          field(pincode, 'PIN Code', keyboard: TextInputType.number),
          field(experience, 'अनुभव (वर्ष)', keyboard: TextInputType.number),
          field(about, 'काम का अनुभव और जानकारी', maxLines: 3),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: saving ? null : () async {
                try { final f = await pickFile(isPhoto: true); if (mounted && f != null) setState(() => photo = f); }
                catch (e) { if (mounted) setState(() => error = e.toString()); }
              },
              icon: const Icon(Icons.photo_camera),
              label: Text(photo == null ? 'फोटो चुनें' : 'फोटो: ' + photo!.name),
            ),
            OutlinedButton.icon(
              onPressed: saving ? null : () async {
                try { final f = await pickFile(isPhoto: false); if (mounted && f != null) setState(() => identity = f); }
                catch (e) { if (mounted) setState(() => error = e.toString()); }
              },
              icon: const Icon(Icons.badge_outlined),
              label: Text(identity == null ? 'Aadhaar / पहचान दस्तावेज़' : 'दस्तावेज़: ' + identity!.name),
            ),
          ]),
          const Divider(height: 28),
          Text('Terms & Privacy Consent', style: Theme.of(context).textTheme.titleMedium),
          if (policies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'इस Worker Role के लिए Main Admin ने अभी Hindi Terms और Privacy Policy प्रकाशित नहीं की हैं। सुरक्षा के लिए आवेदन तब तक Submit नहीं होगा। Admin को दोनों दस्तावेज़ प्रकाशित करने होंगे।',
                style: TextStyle(color: Colors.red),
              ),
            )
          else
            ...policies.map((p) {
              final id = p['id'].toString();
              return ExpansionTile(
                title: Text((p['policy_type'] == 'terms' ? 'Terms & Conditions — ' : 'Privacy Policy — ') + p['version'].toString()),
                children: [
                  Padding(padding: const EdgeInsets.all(12), child: SelectableText(p['body']?.toString() ?? '')),
                  CheckboxListTile(
                    value: accepted[id] == true,
                    onChanged: saving ? null : (v) => setState(() => accepted[id] = v == true),
                    title: const Text('मैंने पूरा दस्तावेज़ पढ़ा और स्वीकार किया है।'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              );
            }),
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
          if (message != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message!, style: const TextStyle(color: Colors.green)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving || !hasPolicies || categories.isEmpty ? null : submit,
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(saving ? 'आवेदन भेजा जा रहा है…' : 'Registration आवेदन Submit करें'),
            ),
          ),
        ]),
      ),
    );
  }
}

class WorkerWorkSessionPanel extends StatefulWidget {
  const WorkerWorkSessionPanel({
    super.key,
    required this.assignmentId,
    required this.pricingUnit,
    required this.onChanged,
    this.onProposeSchedule,
  });
  final String assignmentId;
  final String pricingUnit;
  final Future<void> Function() onChanged;
  final Future<void> Function()? onProposeSchedule;
  @override
  State<WorkerWorkSessionPanel> createState() => _WorkerWorkSessionPanelState();
}

class _WorkerWorkSessionPanelState extends State<WorkerWorkSessionPanel> {
  final client = Supabase.instance.client;
  final completionNote = TextEditingController();
  Map<String, dynamic>? session;
  bool loading = false, busy = false;
  String? error;
  Timer? ticker;
  StreamSubscription<Position>? locationSubscription;
  bool get fixedPrice => widget.pricingUnit == 'per_item' || widget.pricingUnit == 'motor_hp';

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && session?['session_status'] == 'running') setState(() {});
    });
    if (!fixedPrice) openSession();
  }

  @override
  void dispose() {
    ticker?.cancel();
    locationSubscription?.cancel();
    completionNote.dispose();
    super.dispose();
  }

  Future<Position> position() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw StateError('फोन की Location/GPS चालू करें।');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('काम का Timer चलाने के लिए Location अनुमति आवश्यक है।');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
  }

  Future<Map<String, dynamic>> recordLocation() async {
    final id = session?['id']?.toString();
    if (id == null || id.isEmpty) throw StateError('Work Session उपलब्ध नहीं है।');
    final pos = await position();
    final result = await client.rpc('srk_worker_record_session_location', params: {
      'p_session_id': id, 'p_latitude': pos.latitude, 'p_longitude': pos.longitude, 'p_accuracy_m': pos.accuracy,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> openSession() async {
    if (loading || fixedPrice) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await client.rpc('srk_worker_open_work_session', params: {
        'p_booking_worker_id': widget.assignmentId,
      });
      if (mounted) {
        setState(() => session = Map<String, dynamic>.from(result as Map));
        if (session?['session_status'] == 'running' || session?['session_status'] == 'paused') {
          await startLocationTracking();
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(String actionName, {String? reason, String? note}) async {
    final id = session?['id']?.toString();
    if (id == null || id.isEmpty) throw StateError('Work Session उपलब्ध नहीं है।');
    final result = await client.rpc('srk_worker_session_action', params: {
      'p_session_id': id,
      'p_action': actionName,
      'p_pause_reason': reason,
      'p_note': note,
      'p_idempotency_key': 'app:' + id + ':' + actionName + ':' + DateTime.now().microsecondsSinceEpoch.toString(),
    });
    if (mounted) {
      setState(() => session = Map<String, dynamic>.from(result as Map));
      if (session?['session_status'] == 'running' || session?['session_status'] == 'paused') {
        await startLocationTracking();
      } else if (session?['session_status'] == 'completed') {
        await locationSubscription?.cancel();
        locationSubscription = null;
      }
    }
  }

  Future<void> recordPosition(Position pos) async {
    final id = session?['id']?.toString();
    if (id == null || id.isEmpty || !['running','paused'].contains(session?['session_status'])) return;
    await client.rpc('srk_worker_record_session_location', params: {
      'p_session_id': id,
      'p_latitude': pos.latitude,
      'p_longitude': pos.longitude,
      'p_accuracy_m': pos.accuracy,
    });
  }

  Future<void> startLocationTracking() async {
    if (locationSubscription != null || fixedPrice) return;
    try {
      await position();
      locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) async {
        try {
          await recordPosition(pos);
        } catch (e) {
          if (mounted) setState(() => error = 'GPS अपडेट सुरक्षित नहीं हुआ: ' + e.toString());
        }
      }, onError: (Object e) {
        if (mounted) setState(() => error = 'Live GPS अपडेट रुक गया। Location अनुमति और नेटवर्क जाँचें।');
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Live GPS चालू नहीं हुआ। Location अनुमति जाँचें।');
    }
  }

  Future<void> run(Future<void> Function() callback) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      await callback();
      await widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> start() => run(() async {
    await recordLocation();
    await action('start', note: 'Worker App से काम शुरू किया।');
    startLocationTracking();
  });

  Future<void> pause() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pause का कारण चुनें'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('Lunch — न्यूनतम 1 घंटा'), onTap: () => Navigator.pop(ctx, 'lunch')),
          ListTile(title: const Text('Market / अन्य काम — न्यूनतम 2 घंटे'), onTap: () => Navigator.pop(ctx, 'market_other')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस'))],
      ),
    );
    if (reason == null) return;
    await run(() => action('pause', reason: reason, note: 'Pause reason Worker App से चुना गया।'));
  }

  Future<void> resume() => run(() async {
    final result = await recordLocation();
    if (result['auto_resumed'] == true) {
      await openSession();
    } else {
      await action('resume', note: 'GPS सत्यापन के बाद Timer Resume किया।');
    }
  });

  Future<void> completeSession() => run(() => action('complete', note: 'आज का Work Session पूरा किया।'));

  Future<void> completeAssignment() async {
    final note = completionNote.text.trim();
    if (note.length < 5) {
      setState(() => error = 'काम पूरा होने का कम-से-कम 5 अक्षर का विवरण लिखें।');
      return;
    }
    await run(() async {
      await client.rpc('srk_worker_complete_assignment', params: {
        'p_booking_worker_id': widget.assignmentId, 'p_note': note,
      });
    });
  }

  int get elapsedSeconds {
    final recorded = (session?['billable_seconds'] as num?)?.toInt() ?? 0;
    if (session?['session_status'] != 'running') return recorded;
    final resumed = DateTime.tryParse(session?['last_resumed_at']?.toString() ?? '');
    if (resumed == null) return recorded;
    return recorded + DateTime.now().difference(resumed.toLocal()).inSeconds.clamp(0, 86400).toInt();
  }

  String get clock {
    final seconds = elapsedSeconds;
    return (seconds ~/ 3600).toString().padLeft(2, '0') + ':' +
        ((seconds % 3600) ~/ 60).toString().padLeft(2, '0') + ':' +
        (seconds % 60).toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    if (fixedPrice) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('यह Fixed Price Service है — Timer लागू नहीं है।'),
            TextField(controller: completionNote, maxLines: 2,
              decoration: const InputDecoration(labelText: 'काम पूरा होने का विवरण (कम-से-कम 5 अक्षर)')),
            const SizedBox(height: 8),
            FilledButton(onPressed: busy ? null : completeAssignment, child: const Text('काम पूरा होने की सूचना भेजें')),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
      );
    }
    final status = session?['session_status']?.toString() ?? '';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.timer_outlined), const SizedBox(width: 8),
            Text('आज का Work Timer', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(clock, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text('स्थिति: ' + (status == 'running' ? 'काम चल रहा है' :
            status == 'paused' ? 'Pause' : status == 'completed' ? 'आज का Session पूरा' :
            status == 'not_started' ? 'शुरू नहीं हुआ' : loading ? 'लोड हो रहा है' : 'Session उपलब्ध नहीं')),
          if (loading) const LinearProgressIndicator(),
          if (status == 'not_started')
            FilledButton.icon(onPressed: busy || loading ? null : start, icon: const Icon(Icons.play_arrow), label: const Text('GPS के साथ Timer शुरू करें')),
          if (status == 'running')
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: busy ? null : pause, icon: const Icon(Icons.pause), label: const Text('Pause')),
              OutlinedButton.icon(onPressed: busy ? null : completeSession, icon: const Icon(Icons.stop), label: const Text('आज का Session पूरा करें')),
            ]),
          if (status == 'paused')
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: busy ? null : resume, icon: const Icon(Icons.play_arrow), label: const Text('GPS से Resume करें')),
              OutlinedButton.icon(onPressed: busy ? null : completeSession, icon: const Icon(Icons.stop), label: const Text('Session पूरा करें')),
            ]),
          if (status == 'completed') ...[
            const Text('आज का Session बंद है। अगले दिन के लिए नया Work Session बनेगा।'),
            if (widget.onProposeSchedule != null)
              OutlinedButton.icon(onPressed: busy ? null : widget.onProposeSchedule,
                icon: const Icon(Icons.calendar_month), label: const Text('अगले दिन का समय प्रस्तावित करें')),
            TextField(controller: completionNote, maxLines: 2,
              decoration: const InputDecoration(labelText: 'अंतिम काम पूरा होने का विवरण (कम-से-कम 5 अक्षर)')),
            FilledButton(onPressed: busy ? null : completeAssignment, child: const Text('पूरी Booking का काम पूरा करें')),
          ],
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
          if (busy) const LinearProgressIndicator(),
          if (status.isEmpty && !loading)
            OutlinedButton(onPressed: openSession, child: const Text('आज का Session खोलें')),
        ]),
      ),
    );
  }
}

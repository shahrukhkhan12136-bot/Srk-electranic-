import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A booking selection made from the live, RLS-filtered Supabase catalogue.
/// Display labels are informational; only server-issued UUIDs are submitted.
class SrkBackendServiceSelection {
  const SrkBackendServiceSelection({
    required this.categoryId,
    required this.categoryName,
    required this.serviceTypeId,
    required this.serviceName,
    required this.skillId,
    required this.skillName,
    required this.skillLevelId,
    required this.skillLevelName,
    required this.pricingUnit,
    this.helperAvailable = false,
    this.pricingRuleId,
    this.motorHp,
    this.availableMotorHp = const [],
  });

  final String categoryId, categoryName, serviceTypeId, serviceName;
  final String skillId, skillName, skillLevelName;
  final String? skillLevelId;
  final String pricingUnit;
  final bool helperAvailable;
  final String? pricingRuleId;
  final double? motorHp;
  final List<double> availableMotorHp;
}

class SrkServiceCategoryPicker extends StatefulWidget {
  const SrkServiceCategoryPicker({super.key, required this.onSelection, this.initialCategoryCode, this.languageCode = 'hi'});
  final ValueChanged<SrkBackendServiceSelection?> onSelection;
  final String? initialCategoryCode;
  final String languageCode;

  @override
  State<SrkServiceCategoryPicker> createState() => _SrkServiceCategoryPickerState();
}

class _SrkServiceCategoryPickerState extends State<SrkServiceCategoryPicker> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _levels = [];
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _hpTiers = [];
  List<Map<String, dynamic>> _rates = [];
  Map<String, dynamic>? _category, _service, _skill, _level, _rule;
  double? _motorHp;

  @override
  void initState() {
    super.initState();
    _loadCatalogue();
  }

  Future<void> _loadCatalogue() async {
    try {
      final results = await Future.wait<dynamic>([
        _client.from('srk_service_categories').select('id,category_code,category_name,sort_order').eq('is_active', true).order('sort_order'),
        _client.from('srk_service_types').select('id,category_id,service_name,sort_order').eq('is_active', true).order('sort_order'),
        _client.from('srk_service_skills').select('id,service_type_id,skill_name,sort_order').eq('is_active', true).order('sort_order'),
        _client.from('srk_skill_levels').select('id,category_id,level_name,sort_order').eq('is_active', true).order('sort_order'),
        _client.from('srk_service_pricing_rules').select('id,category_id,service_type_id,pricing_unit,technician_rate,helper_rate,effective_from,effective_to'),
        _client.from('srk_service_pricing_hp_tiers').select('pricing_rule_id,motor_hp'),
        _client.from('srk_service_rates').select('category_id,service_type_id,skill_level_id,technician_hourly_rate,helper_hourly_rate,rate_status,effective_from,effective_to').eq('rate_status','approved'),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(results[0] as List);
        _services = List<Map<String, dynamic>>.from(results[1] as List);
        _skills = List<Map<String, dynamic>>.from(results[2] as List);
        _levels = List<Map<String, dynamic>>.from(results[3] as List);
        _rules = List<Map<String, dynamic>>.from(results[4] as List);
        _hpTiers = List<Map<String, dynamic>>.from(results[5] as List);
        _rates = List<Map<String, dynamic>>.from(results[6] as List);
        _loading = false;
        if (widget.initialCategoryCode != null) {
          final matches = _categories.where((x) => x['category_code'] == widget.initialCategoryCode);
          _category = matches.isEmpty ? null : matches.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'लाइव सेवा सूची लोड नहीं हुई। इंटरनेट और Supabase अनुमति जाँचें।'; });
    }
  }


  String _catalogueLabel(String kind, dynamic raw) {
    final source = raw?.toString() ?? '';
    if (widget.languageCode != 'hi') return source;
    const translations = <String, Map<String, String>>{
      'category': {
        'AC + Fridge Technician': 'एसी और फ्रिज तकनीशियन',
        'Cooler Technician': 'कूलर तकनीशियन',
        'Electrician': 'इलेक्ट्रिशियन',
        'Motor & Pump Technician': 'मोटर और पंप तकनीशियन',
        'Painter': 'पेंटर',
        'Plumber': 'प्लंबर',
      },
      'level': {
        'AC Technician': 'एसी तकनीशियन',
        'Basic': 'बेसिक',
        'Expert': 'एक्सपर्ट',
        'Factory/Industrial Wiring Expert': 'फैक्ट्री / औद्योगिक वायरिंग विशेषज्ञ',
        'Master': 'मास्टर',
        'Master Electrician': 'मास्टर इलेक्ट्रिशियन',
        'Master/Industrial': 'मास्टर / औद्योगिक',
        'Residential/Office Wiring': 'घर / कार्यालय वायरिंग',
      },
      'service': {
        'AC Installation': 'एसी लगाना',
        'AC Repair': 'एसी मरम्मत',
        'Basic Electrical Work': 'बिजली के सामान्य काम',
        'Bathroom & Kitchen Plumbing': 'बाथरूम और रसोई की प्लंबिंग',
        'Cooler Motor Repair': 'कूलर मोटर मरम्मत',
        'Cooler Pump Repair': 'कूलर पंप मरम्मत',
        'Cooler Repair': 'कूलर मरम्मत',
        'Cooler Service': 'कूलर सर्विस',
        'Drainage & Blockage Work': 'नाली और जाम की समस्या',
        'Exterior Painting': 'बाहरी पेंटिंग',
        'Factory/Industrial Wiring': 'फैक्ट्री / औद्योगिक वायरिंग',
        'Fridge Repair': 'फ्रिज मरम्मत',
        'Industrial Painting': 'औद्योगिक पेंटिंग',
        'Interior Painting': 'घर के अंदर पेंटिंग',
        'Master Electrician Work': 'मास्टर इलेक्ट्रिशियन का काम',
        'Motor & Pump Installation': 'मोटर और पंप लगाना',
        'Motor Repair': 'मोटर मरम्मत',
        'Motor/Pump Checking': 'मोटर / पंप जाँच',
        'Motor/Pump Fitting': 'मोटर / पंप फिटिंग',
        'Motor/Pump Inspection': 'मोटर / पंप निरीक्षण',
        'Plumbing Repair & Maintenance': 'प्लंबिंग मरम्मत और रखरखाव',
        'Pump Repair': 'पंप मरम्मत',
        'Putty, Primer & Surface Preparation': 'पुट्टी, प्राइमर और सतह की तैयारी',
        'Residential/Office Wiring': 'घर / कार्यालय वायरिंग',
        'Texture, Polish & Special Finish': 'टेक्सचर, पॉलिश और विशेष फिनिश',
        'Water Tank & Pipeline Work': 'पानी की टंकी और पाइपलाइन का काम',
      },
    };
    return translations[kind]?[source] ?? source;
  }

  bool _isCurrent(Map<String, dynamic> row) {
    final now = DateTime.now().toUtc();
    final from = DateTime.tryParse(row['effective_from']?.toString() ?? '');
    final to = DateTime.tryParse(row['effective_to']?.toString() ?? '');
    return (from == null || !from.isAfter(now)) && (to == null || to.isAfter(now));
  }

  List<Map<String, dynamic>> get _availableServices => _services.where((service) {
    if (service['category_id'] != _category?['id']) return false;
    final levelId = _level?['id'];
    final hasApprovedRate = levelId != null && _rates.any((rate) =>
      rate['category_id'] == _category?['id'] &&
      rate['service_type_id'] == service['id'] &&
      rate['skill_level_id'] == levelId &&
      rate['rate_status'] == 'approved' && _isCurrent(rate));
    final hasFixedRule = _rules.any((rule) =>
      rule['category_id'] == _category?['id'] &&
      rule['service_type_id'] == service['id'] &&
      ['per_item', 'motor_hp'].contains(rule['pricing_unit']) && _isCurrent(rule));
    return hasApprovedRate || hasFixedRule;
  }).toList();
  List<Map<String, dynamic>> get _availableSkills =>
      _skills.where((x) => x['service_type_id'] == _service?['id']).toList();
  List<Map<String, dynamic>> get _availableLevels =>
      _levels.where((x) => x['category_id'] == _category?['id']).toList();

  IconData _categoryIcon(String? code) => switch (code) {
    'electrician' => Icons.electrical_services,
    'plumber' => Icons.plumbing,
    'painter' => Icons.format_paint,
    'ac_fridge_technician' => Icons.ac_unit,
    'motor_pump_technician' => Icons.water,
    'cooler_technician' => Icons.air,
    _ => Icons.home_repair_service,
  };

  void _emitSelection() {
    final c = _category, s = _service, k = _skill, l = _level, r = _rule;
    if (c == null || s == null || k == null) {
      widget.onSelection(null); return;
    }
    final isFixedPrice = r != null && ['per_item', 'motor_hp'].contains(r['pricing_unit']);
    if (l == null && !isFixedPrice) {
      widget.onSelection(null); return;
    }
    final now = DateTime.now().toUtc();
    final matchingRates = _rates.where((x) {
      if (x['category_id'] != c['id'] || x['service_type_id'] != s['id'] || x['skill_level_id'] != l?['id']) return false;
      final from = DateTime.tryParse(x['effective_from']?.toString() ?? '');
      final to = DateTime.tryParse(x['effective_to']?.toString() ?? '');
      return (from == null || !from.isAfter(now)) && (to == null || to.isAfter(now));
    }).toList();
    if (r == null && matchingRates.isEmpty) { widget.onSelection(null); return; }
    final unit = r?['pricing_unit']?.toString() ?? 'hour';
    final configuredHelperRate = (r?['helper_rate'] as num?)?.toDouble() ??
        matchingRates.fold<double>(0, (best, rate) {
          final value = (rate['helper_hourly_rate'] as num?)?.toDouble() ?? 0;
          return value > best ? value : best;
        });
    final hp = unit == 'motor_hp' ? _motorHp : null;
    if (unit == 'motor_hp' && hp == null) { widget.onSelection(null); return; }
    widget.onSelection(SrkBackendServiceSelection(
      categoryId: c['id'].toString(), categoryName: _catalogueLabel('category', c['category_name']),
      serviceTypeId: s['id'].toString(), serviceName: _catalogueLabel('service', s['service_name']),
      skillId: k['id'].toString(), skillName: k['skill_name'].toString(),
      skillLevelId: l?['id']?.toString(), skillLevelName: l == null ? 'लागू नहीं' : _catalogueLabel('level', l['level_name']),
      pricingUnit: unit,
      helperAvailable: unit == 'hour' && configuredHelperRate > 0,
      pricingRuleId: r?['id']?.toString(), motorHp: hp,
      availableMotorHp: _hpTiers.where((x) => r != null && x['pricing_rule_id'] == r['id'])
        .map((x) => (x['motor_hp'] as num).toDouble()).toList()..sort(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(
      padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()),
    );
    if (_error != null) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_error!, style: const TextStyle(color: Colors.red)),
      TextButton.icon(onPressed: () { setState(() { _loading = true; _error = null; }); _loadCatalogue(); },
        icon: const Icon(Icons.refresh), label: const Text('दोबारा लोड करें')),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('सेवा की कैटेगरी', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.7),
        itemBuilder: (context, index) {
          final item = _categories[index], selected = _category?['id'] == item['id'];
          return Card(color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
            child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () {
              setState(() { _category = item; _service = null; _skill = null; _level = null; _rule = null; _motorHp = null; });
              widget.onSelection(null);
            }, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
              Icon(_categoryIcon(item['category_code']?.toString()), size: 20),
              const SizedBox(width: 7),
              Expanded(child: Text(_catalogueLabel('category', item['category_name']), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]))));
        },
      ),
      if (_category != null && _availableLevels.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('इस कैटेगरी में किस स्तर का काम चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _availableLevels.map((level) {
          final selected = _level?['id'] == level['id'];
          return ChoiceChip(
            label: Text(_catalogueLabel('level', level['level_name'])),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _level = level;
                _service = null;
                _skill = null;
                _rule = null;
                _motorHp = null;
              });
              widget.onSelection(null);
            },
          );
        }).toList()),
        if (_availableLevels.isEmpty)
          const Text('इस कैटेगरी के लिए स्तर अभी उपलब्ध नहीं है।'),
      ],
      if (_category != null && _availableLevels.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('इस कैटेगरी में Basic/Expert स्तर लागू नहीं है; निर्धारित Fixed Price / HP सेवा चुनें।')),
      if (_category != null && (_level != null || _availableLevels.isEmpty)) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _service?['id']?.toString(), isExpanded: true,
          decoration: const InputDecoration(labelText: 'काम की सर्विस चुनें', border: OutlineInputBorder()),
          items: _availableServices.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(_catalogueLabel('service', x['service_name'])))).toList(),
          onChanged: (id) {
            setState(() {
              _service = _availableServices.firstWhere((x) => x['id'].toString() == id);
              _skill = null;
              final matches = _rules.where((x) => x['service_type_id'] == id && x['category_id'] == _category?['id'] && _isCurrent(x)).toList();
              _rule = matches.isEmpty ? null : matches.first;
              _motorHp = null;
            });
            widget.onSelection(null);
          },
        ),
        if (_availableServices.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('इस स्तर के लिए कोई सक्रिय सर्विस उपलब्ध नहीं है।')),
      ],
      if (_service != null) ...[
        const SizedBox(height: 12),
        Text('इस काम में कौन-कौन से काम आते हैं?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._availableSkills.map((skill) {
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: RadioListTile<String>(
              value: skill['id'].toString(),
              groupValue: _skill?['id']?.toString(),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(skill['skill_name'].toString()),
              onChanged: (selectedId) {
                setState(() => _skill = selectedId == null ? null : skill);
                _emitSelection();
              },
            ),
          );
        }),
        if (_availableSkills.isEmpty)
          const Text('इस सर्विस के लिए कोई सक्रिय काम/Skill सूचीबद्ध नहीं है।'),
      ],
      if (_service != null && _rule == null &&
          !_rates.any((x) => x['category_id'] == _category?['id'] &&
            x['service_type_id'] == _service?['id'] &&
            x['skill_level_id'] == _level?['id'] &&
            x['rate_status'] == 'approved'))
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('इस सेवा की सक्रिय मूल्य-नीति उपलब्ध नहीं है। अभी बुकिंग नहीं भेजी जा सकती।', style: TextStyle(color: Colors.red))),
      if (_rule?['pricing_unit'] == 'motor_hp') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          initialValue: _motorHp, decoration: const InputDecoration(labelText: 'मोटर / पंप HP चुनें', border: OutlineInputBorder()),
          items: _hpTiers.where((x) => x['pricing_rule_id'] == _rule?['id']).map((x) {
            final hp = (x['motor_hp'] as num).toDouble();
            return DropdownMenuItem(value: hp, child: Text('$hp HP'));
          }).toList(),
          onChanged: (hp) { setState(() => _motorHp = hp); _emitSelection(); },
        ),
      ],
      if (_category != null && _availableServices.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('इस कैटेगरी में सक्रिय सेवा उपलब्ध नहीं है।')),
    ]);
  }
}

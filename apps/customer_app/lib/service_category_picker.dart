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
    required this.helperAvailable,
    this.pricingRuleId,
    this.motorHp,
    this.availableMotorHp = const [],
  });

  final String categoryId, categoryName, serviceTypeId, serviceName;
  final String skillId, skillName, skillLevelId, skillLevelName;
  final String pricingUnit;
  final bool helperAvailable;
  final String? pricingRuleId;
  final double? motorHp;
  final List<double> availableMotorHp;
}

class SrkServiceCategoryPicker extends StatefulWidget {
  const SrkServiceCategoryPicker({super.key, required this.onSelection, this.initialCategoryCode});
  final ValueChanged<SrkBackendServiceSelection?> onSelection;
  final String? initialCategoryCode;

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
        _client.from('srk_service_pricing_rules').select('id,category_id,service_type_id,pricing_unit,technician_rate,helper_rate'),
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

  List<Map<String, dynamic>> get _availableServices => _services.where((service) {
    if (service['category_id'] != _category?['id']) return false;
    final levelId = _level?['id'];
    if (levelId == null) return false;
    final hasApprovedRate = _rates.any((rate) =>
      rate['category_id'] == _category?['id'] &&
      rate['service_type_id'] == service['id'] &&
      rate['skill_level_id'] == levelId &&
      rate['rate_status'] == 'approved');
    final hasFixedRule = _rules.any((rule) =>
      rule['category_id'] == _category?['id'] &&
      rule['service_type_id'] == service['id'] &&
      ['per_item', 'motor_hp'].contains(rule['pricing_unit']));
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
    'ac_fridge' => Icons.ac_unit,
    'motor_pump' => Icons.water,
    'cooler' => Icons.air,
    _ => Icons.home_repair_service,
  };

  void _emitSelection() {
    final c = _category, s = _service, k = _skill, l = _level, r = _rule;
    if (c == null || s == null || k == null || l == null) {
      widget.onSelection(null); return;
    }
    final now = DateTime.now().toUtc();
    final matchingRates = _rates.where((x) {
      if (x['category_id'] != c['id'] || x['service_type_id'] != s['id'] || x['skill_level_id'] != l['id']) return false;
      final from = DateTime.tryParse(x['effective_from']?.toString() ?? '');
      final to = DateTime.tryParse(x['effective_to']?.toString() ?? '');
      return (from == null || !from.isAfter(now)) && (to == null || to.isAfter(now));
    }).toList();
    if (r == null && matchingRates.isEmpty) { widget.onSelection(null); return; }
    final unit = r?['pricing_unit']?.toString() ?? 'hour';
    final hp = unit == 'motor_hp' ? _motorHp : null;
    if (unit == 'motor_hp' && hp == null) { widget.onSelection(null); return; }
    widget.onSelection(SrkBackendServiceSelection(
      categoryId: c['id'].toString(), categoryName: c['category_name'].toString(),
      serviceTypeId: s['id'].toString(), serviceName: s['service_name'].toString(),
      skillId: k['id'].toString(), skillName: k['skill_name'].toString(),
      skillLevelId: l['id'].toString(), skillLevelName: l['level_name'].toString(),
      pricingUnit: unit,
      helperAvailable: (unit == 'hour') && ((r?['helper_rate'] as num?) ?? 0) > 0 || matchingRates.any((x) => ((x['helper_hourly_rate'] as num?) ?? 0) > 0),
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
              Expanded(child: Text(item['category_name'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]))));
        },
      ),
      if (_category != null) ...[
        const SizedBox(height: 12),
        Text('इस कैटेगरी में किस स्तर का काम चाहिए?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _availableLevels.map((level) {
          final selected = _level?['id'] == level['id'];
          return ChoiceChip(
            label: Text(level['level_name'].toString()),
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
      if (_level != null) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _service?['id']?.toString(), isExpanded: true,
          decoration: const InputDecoration(labelText: 'काम की सर्विस चुनें', border: OutlineInputBorder()),
          items: _availableServices.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['service_name'].toString()))).toList(),
          onChanged: (id) {
            setState(() {
              _service = _availableServices.firstWhere((x) => x['id'].toString() == id);
              _skill = null;
              final matches = _rules.where((x) => x['service_type_id'] == id && x['category_id'] == _category?['id']).toList();
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
          final selected = _skill?['id'] == skill['id'];
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: CheckboxListTile(
              value: selected,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(skill['skill_name'].toString()),
              onChanged: (checked) {
                setState(() => _skill = checked == true ? skill : null);
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

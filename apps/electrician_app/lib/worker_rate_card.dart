import 'package:flutter/material.dart';

/// Displays only this logged-in worker's own payable share for all six
/// service categories. Company/commission values are deliberately absent.
class WorkerRateCard extends StatelessWidget {
  const WorkerRateCard({super.key, required this.categories});

  final List<Map<String, dynamic>> categories;

  String _money(dynamic raw) {
    final value = (raw as num?)?.toDouble();
    if (value == null) return 'रेट उपलब्ध नहीं';
    final rounded = value.toStringAsFixed(2);
    return rounded.endsWith('.00')
        ? '₹${rounded.substring(0, rounded.length - 3)}'
        : '₹$rounded';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Text('मेरी रेट सूची',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('छहों कैटेगरी में आपकी मिलने वाली मजदूरी।'),
            ),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('रेट सूची अभी उपलब्ध नहीं है। Refresh करके फिर कोशिश करें।'),
              )
            else
              ...categories.map((category) {
                final rates = List<Map<String, dynamic>>.from(
                  category['rates'] as List? ?? const [],
                );
                return ExpansionTile(
                  key: PageStorageKey('worker-rate-${category['category_code']}'),
                  title: Text(category['category_name']?.toString() ?? 'सेवा'),
                  subtitle: Text(rates.isEmpty
                      ? 'रेट उपलब्ध नहीं'
                      : '${rates.length} सेवा दरें'),
                  children: rates.map((rate) {
                    final skill = rate['skill_level_name']?.toString() ?? '';
                    final service = rate['service_name']?.toString() ?? '';
                    final label = rate['rate_label']?.toString() ?? '';
                    final unit = rate['unit_label']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      title: Text(service),
                      subtitle: Text([
                        if (skill.isNotEmpty) skill,
                        if (label.isNotEmpty) label,
                        unit,
                      ].where((part) => part.isNotEmpty).join(' • ')),
                      trailing: Text(
                        _money(rate['worker_rate']),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'srk_verified_service_skill.dart';

/// Read-only presentation. It does not authorize offers or work actions.
class SrkVerifiedServicesPanel extends StatelessWidget {
  const SrkVerifiedServicesPanel({
    super.key,
    required this.skills,
  });

  final List<SrkVerifiedServiceSkill> skills;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'आपकी सत्यापित सेवाएँ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (skills.isEmpty)
              const Text(
                'अभी कोई सत्यापित सेवा उपलब्ध नहीं है। '
                'सेवा सत्यापन पूरा होने पर यहाँ दिखाई देगी।',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map((skill) => Chip(
                          avatar: const Icon(Icons.verified, size: 18),
                          label: Text(skill.displayName),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 4),
            Text(
              'यह सूची केवल जानकारी के लिए है। बुकिंग की पात्रता सर्वर जाँचता है।',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

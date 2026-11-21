import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srk_electrician_app/verified_services/srk_verified_service_skill.dart';
import 'package:srk_electrician_app/verified_services/srk_verified_services_panel.dart';

void main() {
  final now = DateTime.utc(2026, 11, 21, 9);

  Map<String, dynamic> skill({
    String status = 'approved',
    bool active = true,
    String? validUntil,
    String categoryId = 'ac',
    String subcategoryId = 'ac_repair',
  }) => {
        'category_id': categoryId,
        'subcategory_id': subcategoryId,
        'category_label': 'AC',
        'subcategory_label': 'AC Repair',
        'verification_status': status,
        'active': active,
        'verified_at': '2026-11-20T09:00:00Z',
        if (validUntil != null) 'valid_until': validUntil,
      };

  group('SrkVerifiedServiceSkill.fromServerJson', () {
    test('accepts approved active skill with stable IDs', () {
      final parsed = SrkVerifiedServiceSkill.fromServerJson(
        skill(),
        now: now,
      );
      expect(parsed, isNotNull);
      expect(parsed!.categoryId, 'ac');
      expect(parsed.subcategoryId, 'ac_repair');
      expect(parsed.displayName, 'AC • AC Repair');
    });

    test('rejects pending, rejected and inactive skills', () {
      expect(
        SrkVerifiedServiceSkill.fromServerJson(
          skill(status: 'pending'),
          now: now,
        ),
        isNull,
      );
      expect(
        SrkVerifiedServiceSkill.fromServerJson(
          skill(status: 'rejected'),
          now: now,
        ),
        isNull,
      );
      expect(
        SrkVerifiedServiceSkill.fromServerJson(
          skill(active: false),
          now: now,
        ),
        isNull,
      );
    });

    test('rejects expired skill and malformed or missing IDs', () {
      expect(
        SrkVerifiedServiceSkill.fromServerJson(
          skill(validUntil: '2026-11-20T09:00:00Z'),
          now: now,
        ),
        isNull,
      );
      expect(
        SrkVerifiedServiceSkill.fromServerJson(
          {...skill(), 'category_id': ''},
          now: now,
        ),
        isNull,
      );
      expect(
        SrkVerifiedServiceSkill.fromServerJson(
          {...skill(), 'subcategory_id': null},
          now: now,
        ),
        isNull,
      );
    });

    test('keeps AC and Fridge as distinct category IDs', () {
      final ac = SrkVerifiedServiceSkill.fromServerJson(
        skill(categoryId: 'ac'),
        now: now,
      );
      final fridge = SrkVerifiedServiceSkill.fromServerJson(
        {
          ...skill(categoryId: 'fridge', subcategoryId: 'fridge_repair'),
          'category_label': 'Fridge',
          'subcategory_label': 'Fridge Repair',
        },
        now: now,
      );
      expect(ac!.categoryId, isNot(fridge!.categoryId));
    });
  });

  testWidgets('shows verified services panel and server-authority note',
      (tester) async {
    final parsed = SrkVerifiedServiceSkill.fromServerJson(skill(), now: now)!;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SrkVerifiedServicesPanel(skills: [parsed]),
      ),
    ));

    expect(find.text('आपकी सत्यापित सेवाएँ'), findsOneWidget);
    expect(find.text('AC • AC Repair'), findsOneWidget);
    expect(find.textContaining('पात्रता सर्वर जाँचता है'), findsOneWidget);
  });

  testWidgets('shows safe empty state when no verified skill exists',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SrkVerifiedServicesPanel(skills: []),
      ),
    ));

    expect(find.textContaining('कोई सत्यापित सेवा उपलब्ध नहीं है'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:srk_electrician_app/verified_services/srk_verified_service_skill.dart';
import 'package:srk_electrician_app/verified_services/srk_offer_skill_match_preview.dart';

void main() {
  final skill = SrkVerifiedServiceSkill.fromServerJson({
    'category_id': 'ac',
    'subcategory_id': 'ac_repair',
    'category_label': 'AC',
    'subcategory_label': 'AC Repair',
    'task_id': 'general_repair',
    'task_label': 'General Repair',
    'skill_tier_id': 'expert',
    'skill_tier_label': 'Expert',
    'verification_status': 'approved',
    'active': true,
  }, now: DateTime.utc(2026, 11, 21))!;

  test('matches exact canonical category and subcategory', () {
    expect(
      previewOfferSkillMatch(
        offer: {'category_id': 'ac', 'subcategory_id': 'ac_repair'},
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.matched,
    );
  });

  test('does not match another trade or subcategory', () {
    expect(
      previewOfferSkillMatch(
        offer: {'category_id': 'fridge', 'subcategory_id': 'ac_repair'},
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.notMatched,
    );
    expect(
      previewOfferSkillMatch(
        offer: {'category_id': 'ac', 'subcategory_id': 'installation'},
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.notMatched,
    );
  });

  test('requires exact specialist task and skill tier when offer asks', () {
    expect(
      previewOfferSkillMatch(
        offer: {
          'category_id': 'ac',
          'subcategory_id': 'ac_repair',
          'task_id': 'gas_charging',
        },
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.notMatched,
    );
    expect(
      previewOfferSkillMatch(
        offer: {
          'category_id': 'ac',
          'subcategory_id': 'ac_repair',
          'skill_tier_id': 'master',
        },
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.notMatched,
    );
  });

  test('returns unknown when backend has not supplied canonical IDs', () {
    expect(
      previewOfferSkillMatch(
        offer: {'service_type': 'AC Repair'},
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.unknown,
    );
    expect(
      previewOfferSkillMatch(
        offer: {'category_id': 'ac'},
        verifiedSkills: [skill],
      ),
      SrkOfferSkillMatch.unknown,
    );
  });
}

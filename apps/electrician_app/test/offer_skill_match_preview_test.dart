import 'package:flutter_test/flutter_test.dart';
import 'package:srk_mobile_core/srk_service_catalog.dart';
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
  final draftAcSkill = SrkVerifiedServiceSkill.fromDraftCatalogueServerJson({
    'category_id': 'ac_fridge',
    'subcategory_id': 'ac',
    'task_id': 'gas_charging',
    'category_label': 'stale label',
    'subcategory_label': 'stale label',
    'task_label': 'stale label',
    'catalogue_version': srkServiceCatalogDraftVersion,
    'verification_status': 'approved',
    'active': true,
  }, now: DateTime.utc(2026, 11, 21))!;

  group('previewOfferSkillMatchAgainstDraftCatalogue', () {
    test('matches only known IDs and the exact catalogue version', () {
      expect(
        previewOfferSkillMatchAgainstDraftCatalogue(
          offer: {
            'category_id': 'ac_fridge',
            'subcategory_id': 'ac',
            'task_id': 'gas_charging',
            'catalogue_version': srkServiceCatalogDraftVersion,
          },
          verifiedSkills: [draftAcSkill],
        ),
        SrkOfferSkillMatch.matched,
      );
    });

    test('returns unknown when offer version is absent or different', () {
      for (final version in [null, 'old-version']) {
        expect(
          previewOfferSkillMatchAgainstDraftCatalogue(
            offer: {
              'category_id': 'ac_fridge',
              'subcategory_id': 'ac',
              'task_id': 'gas_charging',
              if (version != null) 'catalogue_version': version,
            },
            verifiedSkills: [draftAcSkill],
          ),
          SrkOfferSkillMatch.unknown,
        );
      }
    });

    test('rejects unknown category, subcategory and task IDs', () {
      expect(
        previewOfferSkillMatchAgainstDraftCatalogue(
          offer: {
            'category_id': 'ac',
            'subcategory_id': 'ac',
            'catalogue_version': srkServiceCatalogDraftVersion,
          },
          verifiedSkills: [draftAcSkill],
        ),
        SrkOfferSkillMatch.notMatched,
      );
      expect(
        previewOfferSkillMatchAgainstDraftCatalogue(
          offer: {
            'category_id': 'ac_fridge',
            'subcategory_id': 'fridge',
            'task_id': 'gas_charging',
            'catalogue_version': srkServiceCatalogDraftVersion,
          },
          verifiedSkills: [draftAcSkill],
        ),
        SrkOfferSkillMatch.notMatched,
      );
    });

    test('does not match a valid offer to a skill from another version', () {
      final oldVersionSkill = SrkVerifiedServiceSkill.fromServerJson({
        'category_id': 'ac_fridge',
        'subcategory_id': 'ac',
        'task_id': 'gas_charging',
        'category_label': 'AC + Fridge',
        'subcategory_label': 'AC',
        'verification_status': 'approved',
        'active': true,
        'catalogue_version': 'old-version',
      }, now: DateTime.utc(2026, 11, 21))!;

      expect(
        previewOfferSkillMatchAgainstDraftCatalogue(
          offer: {
            'category_id': 'ac_fridge',
            'subcategory_id': 'ac',
            'task_id': 'gas_charging',
            'catalogue_version': srkServiceCatalogDraftVersion,
          },
          verifiedSkills: [oldVersionSkill],
        ),
        SrkOfferSkillMatch.notMatched,
      );
    });

    test('returns unknown for task taxonomy not yet defined in the draft', () {
      expect(
        previewOfferSkillMatchAgainstDraftCatalogue(
          offer: {
            'category_id': 'electrician',
            'subcategory_id': 'electrical_wiring',
            'task_id': 'rewiring',
            'catalogue_version': srkServiceCatalogDraftVersion,
          },
          verifiedSkills: [],
        ),
        SrkOfferSkillMatch.unknown,
      );
    });
  });

}

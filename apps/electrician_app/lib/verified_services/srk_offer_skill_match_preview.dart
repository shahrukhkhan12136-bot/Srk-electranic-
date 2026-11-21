import 'package:srk_mobile_core/srk_service_catalog.dart' as catalog;

import 'srk_verified_service_skill.dart';

enum SrkOfferSkillMatch { matched, notMatched, unknown }

/// Preview-only matcher for canonical server offer fields.
///
/// Never use this helper to authorize, hide, accept or dispatch an offer.
/// The backend remains the sole authority.
SrkOfferSkillMatch previewOfferSkillMatch({
  required Map<String, dynamic> offer,
  required List<SrkVerifiedServiceSkill> verifiedSkills,
}) {
  final categoryId = _value(offer['category_id']);
  final subcategoryId = _value(offer['subcategory_id']);
  if (categoryId == null || subcategoryId == null) {
    return SrkOfferSkillMatch.unknown;
  }

  final taskId = _value(offer['task_id']);
  final skillTierId = _value(offer['skill_tier_id']);

  for (final skill in verifiedSkills) {
    if (skill.categoryId != categoryId ||
        skill.subcategoryId != subcategoryId) {
      continue;
    }
    if (taskId != null && skill.taskId != taskId) continue;
    if (skillTierId != null && skill.skillTierId != skillTierId) continue;
    return SrkOfferSkillMatch.matched;
  }
  return SrkOfferSkillMatch.notMatched;
}

/// Validates offer identifiers against the shared frontend draft before
/// comparing them with skills parsed against that same draft.
///
/// Returns unknown when the offer lacks the draft version or when the
/// catalogue does not yet define the requested task taxonomy. This remains
/// display-only; never use it to hide/authorize/accept/dispatch an offer.
SrkOfferSkillMatch previewOfferSkillMatchAgainstDraftCatalogue({
  required Map<String, dynamic> offer,
  required List<SrkVerifiedServiceSkill> verifiedSkills,
}) {
  final version = _value(offer['catalogue_version']);
  final categoryId = _value(offer['category_id']);
  final subcategoryId = _value(offer['subcategory_id']);
  if (version != catalog.srkServiceCatalogDraftVersion ||
      categoryId == null ||
      subcategoryId == null) {
    return SrkOfferSkillMatch.unknown;
  }

  final categories = catalog.srkServiceCatalog
      .where((item) => item.id == categoryId)
      .toList();
  if (categories.length != 1) return SrkOfferSkillMatch.notMatched;
  final category = categories.single;

  final subcategories = category.options
      .where((item) => item.id == subcategoryId)
      .toList();
  if (subcategories.length != 1) return SrkOfferSkillMatch.notMatched;
  final subcategory = subcategories.single;

  final taskId = _value(offer['task_id']);
  if (taskId != null) {
    if (subcategory.tasks.isEmpty) return SrkOfferSkillMatch.unknown;
    if (!subcategory.tasks.any((task) => task.id == taskId)) {
      return SrkOfferSkillMatch.notMatched;
    }
  }

  final tierId = _value(offer['skill_tier_id']);
  final draftSkills = verifiedSkills
      .where((skill) =>
          skill.catalogueVersion == catalog.srkServiceCatalogDraftVersion)
      .toList();

  for (final skill in draftSkills) {
    if (skill.categoryId != categoryId ||
        skill.subcategoryId != subcategoryId) {
      continue;
    }
    if (taskId != null && skill.taskId != taskId) continue;
    if (tierId != null && skill.skillTierId != tierId) continue;
    return SrkOfferSkillMatch.matched;
  }
  return SrkOfferSkillMatch.notMatched;
}

String? _value(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

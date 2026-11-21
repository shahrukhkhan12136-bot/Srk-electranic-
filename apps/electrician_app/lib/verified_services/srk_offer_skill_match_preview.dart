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

String? _value(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

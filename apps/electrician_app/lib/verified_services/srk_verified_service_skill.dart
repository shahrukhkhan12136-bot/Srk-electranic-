import 'package:flutter/foundation.dart';

/// Read-only, server-authored skill data for the Technician app.
///
/// This model is intentionally not wired to a Supabase query until the
/// backend publishes the exact deployed response contract.
@immutable
class SrkVerifiedServiceSkill {
  const SrkVerifiedServiceSkill({
    required this.categoryId,
    required this.subcategoryId,
    required this.categoryLabel,
    required this.subcategoryLabel,
    this.taskId,
    this.taskLabel,
    this.skillTierId,
    this.skillTierLabel,
    this.catalogueVersion,
    this.verifiedAt,
    this.validUntil,
  });

  final String categoryId;
  final String subcategoryId;
  final String categoryLabel;
  final String subcategoryLabel;
  final String? taskId;
  final String? taskLabel;
  final String? skillTierId;
  final String? skillTierLabel;
  final String? catalogueVersion;
  final DateTime? verifiedAt;
  final DateTime? validUntil;

  /// Parses only an explicitly approved, active and non-expired skill.
  /// Missing IDs/labels or unknown status fail closed and return null.
  static SrkVerifiedServiceSkill? fromServerJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final categoryId = _nonEmpty(json['category_id']);
    final subcategoryId = _nonEmpty(json['subcategory_id']);
    final categoryLabel = _nonEmpty(json['category_label']);
    final subcategoryLabel = _nonEmpty(json['subcategory_label']);
    final status = _nonEmpty(json['verification_status'])?.toLowerCase();
    final active = json['active'] == true;
    final validUntil = _date(json['valid_until']);
    final currentTime = now ?? DateTime.now();

    if (categoryId == null ||
        subcategoryId == null ||
        categoryLabel == null ||
        subcategoryLabel == null ||
        status != 'approved' ||
        !active ||
        (validUntil != null && !validUntil.isAfter(currentTime))) {
      return null;
    }

    return SrkVerifiedServiceSkill(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      categoryLabel: categoryLabel,
      subcategoryLabel: subcategoryLabel,
      taskId: _nonEmpty(json['task_id']),
      taskLabel: _nonEmpty(json['task_label']),
      skillTierId: _nonEmpty(json['skill_tier_id']),
      skillTierLabel: _nonEmpty(json['skill_tier_label']),
      catalogueVersion: _nonEmpty(json['catalogue_version']),
      verifiedAt: _date(json['verified_at']),
      validUntil: validUntil,
    );
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String get displayName => [
        categoryLabel,
        subcategoryLabel,
        if (taskLabel != null) taskLabel!,
        if (skillTierLabel != null) skillTierLabel!,
      ].join(' • ');
}

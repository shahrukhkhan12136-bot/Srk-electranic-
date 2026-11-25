import 'srk_service_catalog.dart';

/// Shared Customer -> booking -> Technician offer service identity.
///
/// IDs and version are the cross-app contract. Labels are display-only and
/// are intentionally omitted from [toJson] so the server resolves canonical
/// labels from its own catalogue.
class SrkServiceSelection {
  const SrkServiceSelection._({
    required this.catalogueVersion,
    required this.categoryId,
    required this.categoryLabel,
    this.subcategoryId,
    this.subcategoryLabel,
    this.taskId,
    this.taskLabel,
  });

  final String catalogueVersion;
  final String categoryId;
  final String categoryLabel;
  final String? subcategoryId;
  final String? subcategoryLabel;
  final String? taskId;
  final String? taskLabel;

  /// Creates a selection only when every supplied ID belongs to the shared
  /// draft catalogue. A task must belong to the selected subcategory.
  static SrkServiceSelection? create({
    required String categoryId,
    String? subcategoryId,
    String? taskId,
  }) {
    final categories =
        srkServiceCatalog.where((item) => item.id == categoryId).toList();
    if (categories.length != 1) return null;
    final category = categories.single;

    if (subcategoryId == null) {
      if (category.options.isNotEmpty || taskId != null) return null;
      return SrkServiceSelection._(
        catalogueVersion: srkServiceCatalogDraftVersion,
        categoryId: category.id,
        categoryLabel: category.displayName,
      );
    }

    final subcategories =
        category.options.where((item) => item.id == subcategoryId).toList();
    if (subcategories.length != 1) return null;
    final subcategory = subcategories.single;

    if (taskId == null && subcategory.tasks.isNotEmpty) return null;
    SrkServiceTask? task;
    if (taskId != null) {
      final tasks =
          subcategory.tasks.where((item) => item.id == taskId).toList();
      if (tasks.length != 1) return null;
      task = tasks.single;
    }

    return SrkServiceSelection._(
      catalogueVersion: srkServiceCatalogDraftVersion,
      categoryId: category.id,
      categoryLabel: category.displayName,
      subcategoryId: subcategory.id!,
      subcategoryLabel: subcategory.displayName ?? subcategory.name,
      taskId: task?.id,
      taskLabel: task?.name,
    );
  }

  /// Stable, versioned identity to be included in a future backend booking
  /// request. Do not send display labels as authoritative service identifiers.
  Map<String, dynamic> toJson() => {
        'catalogue_version': catalogueVersion,
        'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        if (taskId != null) 'task_id': taskId,
      };

  String get displayName => [
        categoryLabel,
        if (subcategoryLabel != null) subcategoryLabel!,
        if (taskLabel != null) taskLabel!,
      ].join(' • ');
}

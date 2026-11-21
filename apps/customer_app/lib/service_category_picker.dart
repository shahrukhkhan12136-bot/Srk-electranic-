import 'package:flutter/material.dart';
import 'package:srk_mobile_core/srk_service_catalog.dart' as catalog;
import 'package:srk_mobile_core/srk_service_selection_contract.dart';

/// Customer-facing service catalogue prototype.
///
/// This widget is intentionally isolated: it does not submit bookings, calculate
/// prices, or call Supabase. Connect it to the existing booking form only after
/// the backend category/verified-skill dispatch contract is available.
class SrkServiceCategory {
  const SrkServiceCategory({
    required this.id,
    required this.title,
    required this.icon,
    this.subcategories = const [],
  });

  final String id;
  final String title;
  final IconData icon;
  final List<SrkServiceSubcategory> subcategories;
}

class SrkServiceSubcategory {
  const SrkServiceSubcategory({
    required this.id,
    required this.title,
    this.children = const [],
  });

  final String id;
  final String title;
  final List<String> children;
}

IconData _iconForService(String key) => switch (key) {
      'electrical_services' => Icons.electrical_services,
      'plumbing' => Icons.plumbing,
      'format_paint' => Icons.format_paint,
      'ac_unit' => Icons.ac_unit,
      'water' => Icons.water,
      'mode_fan' => Icons.mode_fan,
      _ => Icons.miscellaneous_services,
    };

/// Customer picker is a presentation adapter over the shared core catalogue.
/// It does not submit a booking or authorize technician eligibility.
final List<SrkServiceCategory> srkServiceCategories =
    catalog.srkServiceCatalog.map((category) {
  return SrkServiceCategory(
    id: category.id,
    title: category.displayName,
    icon: _iconForService(category.iconKey),
    subcategories: category.options
        .where((option) => option.id != null)
        .map((option) => SrkServiceSubcategory(
              id: option.id!,
              title: option.displayName ?? option.name,
              children: option.tasks.map((task) => task.name).toList(),
            ))
        .toList(),
  );
}).toList();

class SrkServiceCategoryPicker extends StatefulWidget {
  const SrkServiceCategoryPicker({
    super.key,
    required this.onSelection,
  });

  /// Emits a versioned shared selection; still preview-only.
  final void Function(SrkServiceSelection selection) onSelection;

  @override
  State<SrkServiceCategoryPicker> createState() =>
      _SrkServiceCategoryPickerState();
}

class _SrkServiceCategoryPickerState extends State<SrkServiceCategoryPicker> {
  SrkServiceCategory? _category;
  SrkServiceSubcategory? _subcategory;

  void _selectCategory(SrkServiceCategory category) {
    setState(() {
      _category = category;
      _subcategory = null;
    });
    if (category.subcategories.isEmpty) {
      final selection = SrkServiceSelection.create(categoryId: category.id);
      if (selection != null) widget.onSelection(selection);
    }
  }

  void _selectSubcategory(SrkServiceSubcategory subcategory) {
    final category = _category;
    if (category == null) return;
    setState(() => _subcategory = subcategory);
    if (subcategory.children.isEmpty) {
      final selection = SrkServiceSelection.create(
        categoryId: category.id,
        subcategoryId: subcategory.id,
      );
      if (selection != null) widget.onSelection(selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final subcategory = _subcategory;
    final tasks = subcategory?.children ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('अपनी सेवा चुनें', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: srkServiceCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
          ),
          itemBuilder: (context, index) {
            final item = srkServiceCategories[index];
            final selected = category?.id == item.id;
            return Card(
              margin: EdgeInsets.zero,
              color: selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectCategory(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (category != null && category.subcategories.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(category.id == 'ac_fridge' ? 'AC या फ्रिज चुनें' : 'काम चुनें',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.subcategories.map((item) {
              return ChoiceChip(
                label: Text(item.title),
                selected: subcategory?.id == item.id,
                onSelected: (_) => _selectSubcategory(item),
              );
            }).toList(),
          ),
        ],
        if (subcategory != null && tasks.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('काम का प्रकार', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tasks.map((task) {
              return ActionChip(
                label: Text(task),
                onPressed: () {
                  final selectedCategory = category;
                  if (selectedCategory == null) return;
                  final sourceCategory = catalog.srkServiceCatalog
                      .singleWhere((item) => item.id == selectedCategory.id);
                  final sourceSubcategory = sourceCategory.options
                      .singleWhere((item) => item.id == subcategory.id);
                  final sourceTask = sourceSubcategory.tasks
                      .singleWhere((item) => item.name == task);
                  final selection = SrkServiceSelection.create(
                    categoryId: selectedCategory.id,
                    subcategoryId: subcategory.id,
                    taskId: sourceTask.id,
                  );
                  if (selection != null) widget.onSelection(selection);
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'यह सेवा चयन का प्रारूप है। अभी इससे बुकिंग जमा नहीं होती और कीमत नहीं निकाली जाती।',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

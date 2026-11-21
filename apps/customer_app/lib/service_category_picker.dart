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
    this.skillLevels = const [],
  });

  final String id;
  final String title;
  final IconData icon;
  final List<SrkServiceSubcategory> subcategories;
  final List<catalog.SrkServiceOption> skillLevels;
}

class SrkServiceSubcategory {
  const SrkServiceSubcategory({
    required this.id,
    required this.title,
    this.children = const [],
    this.childOptions = const [],
  });

  final String id;
  final String title;
  final List<String> children;
  final List<catalog.SrkServiceOption> childOptions;
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
              childOptions: option.children,
            ))
        .toList(),
    skillLevels: category.skillLevels,
  );
}).toList();

class SrkServiceCategoryPicker extends StatefulWidget {
  const SrkServiceCategoryPicker({
    super.key,
    required this.onSelection,
  });

  /// Emits a versioned shared selection; still preview-only.
  final void Function(SrkServiceSelection? selection) onSelection;

  @override
  State<SrkServiceCategoryPicker> createState() =>
      _SrkServiceCategoryPickerState();
}

class _SrkServiceCategoryPickerState extends State<SrkServiceCategoryPicker> {
  SrkServiceCategory? _category;
  SrkServiceSubcategory? _subcategory;
  String? _selectedTaskId;
  catalog.SrkServiceOption? _selectedChildOption;
  catalog.SrkServiceOption? _selectedSkillLevel;
  String? _selectedSkillTaskId;

  void _selectCategory(SrkServiceCategory category) {
    widget.onSelection(null);
    setState(() {
      _category = category;
      _subcategory = null;
      _selectedTaskId = null;
      _selectedChildOption = null;
      _selectedSkillLevel = null;
      _selectedSkillTaskId = null;
    });
    if (category.subcategories.isEmpty && category.skillLevels.isEmpty) {
      final selection = SrkServiceSelection.create(categoryId: category.id);
      if (selection != null) widget.onSelection(selection);
    }
  }

  void _selectSubcategory(SrkServiceSubcategory subcategory) {
    final category = _category;
    if (category == null) return;
    widget.onSelection(null);
    setState(() {
      _subcategory = subcategory;
      _selectedTaskId = null;
      _selectedChildOption = null;
    });
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
    final selectedSkillLevel = _selectedSkillLevel;

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
        if (category != null && category.skillLevels.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('कारीगर का स्तर चुनें',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.skillLevels.map((level) {
              return ChoiceChip(
                label: Text(level.name),
                selected: selectedSkillLevel?.name == level.name,
                onSelected: (_) {
                  widget.onSelection(null);
                  setState(() {
                    _selectedSkillLevel = level;
                    _selectedSkillTaskId = null;
                  });
                },
              );
            }).toList(),
          ),
          if (selectedSkillLevel != null &&
              selectedSkillLevel.rates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('मजदूरी की दर (सामग्री अलग)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...selectedSkillLevel.rates.map((rate) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${rate.label}: ${rate.amount} / ${rate.unit}'
                    '${rate.helperAmount == null ? '' : ' • ${rate.helperAmount}'}'
                    '${rate.note == null ? '' : ' • ${rate.note}'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )),
            if (selectedSkillLevel.rates.any((rate) => rate.helperAmount != null))
              const Text(
                'Helper वैकल्पिक है; चुनने पर ही अतिरिक्त शुल्क लगेगा।',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
          if (selectedSkillLevel != null &&
              selectedSkillLevel.tasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('इस स्तर के काम / क्षमताएँ',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSkillLevel.tasks.map((task) {
                return FilterChip(
                  label: Text(task.name),
                  selected: _selectedSkillTaskId == task.id,
                  onSelected: (_) {
                    widget.onSelection(null);
                    setState(() => _selectedSkillTaskId = task.id);
                  },
                );
              }).toList(),
            ),
          ],
        ],
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
        if (subcategory != null && subcategory.childOptions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('काम का विकल्प चुनें',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subcategory.childOptions.map((option) {
              final selected = _selectedChildOption?.id == option.id;
              return ChoiceChip(
                label: Text(option.displayName ?? option.name),
                selected: selected,
                onSelected: (_) {
                  widget.onSelection(null);
                  setState(() => _selectedChildOption = option);
                },
              );
            }).toList(),
          ),
          if (_selectedChildOption != null &&
              _selectedChildOption!.rates.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._selectedChildOption!.rates.map((rate) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${rate.label}: ${rate.amount} / ${rate.unit}'
                '${rate.helperAmount == null ? '' : ' • ${rate.helperAmount}'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )),
          ],
        ],
        if (subcategory != null && tasks.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('काम का प्रकार', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tasks.map((task) {
              final selectedCategory = category;
              if (selectedCategory == null) return const SizedBox.shrink();
              final sourceCategory = catalog.srkServiceCatalog
                  .singleWhere((item) => item.id == selectedCategory.id);
              final sourceSubcategory = sourceCategory.options
                  .singleWhere((item) => item.id == subcategory.id);
              final sourceTask = sourceSubcategory.tasks
                  .singleWhere((item) => item.name == task);
              return FilterChip(
                label: Text(task),
                selected: _selectedTaskId == sourceTask.id,
                onSelected: (_) {
                  final selection = SrkServiceSelection.create(
                    categoryId: selectedCategory.id,
                    subcategoryId: subcategory.id,
                    taskId: sourceTask.id,
                  );
                  if (selection == null) return;
                  setState(() => _selectedTaskId = sourceTask.id);
                  widget.onSelection(selection);
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

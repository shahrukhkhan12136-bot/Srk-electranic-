import 'package:flutter/material.dart';

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

const List<SrkServiceCategory> srkServiceCategories = [
  SrkServiceCategory(
    id: 'electrician',
    title: 'इलेक्ट्रीशियन',
    icon: Icons.electrical_services,
    subcategories: [
      SrkServiceSubcategory(id: 'electrical_wiring', title: 'इलेक्ट्रिकल वायरिंग'),
      SrkServiceSubcategory(id: 'fan_install_repair', title: 'पंखा लगाना / मरम्मत'),
      SrkServiceSubcategory(id: 'switch_socket', title: 'स्विच और सॉकेट मरम्मत'),
      SrkServiceSubcategory(id: 'light_install', title: 'लाइट लगाना'),
      SrkServiceSubcategory(id: 'mcb_distribution', title: 'MCB / डिस्ट्रीब्यूशन बोर्ड'),
      SrkServiceSubcategory(id: 'inverter_battery', title: 'इन्वर्टर / बैटरी'),
      SrkServiceSubcategory(id: 'appliance_electrical', title: 'इलेक्ट्रिकल उपकरण की मरम्मत'),
      SrkServiceSubcategory(id: 'other_electrical', title: 'अन्य इलेक्ट्रिकल काम'),
    ],
  ),
  SrkServiceCategory(
    id: 'plumber',
    title: 'प्लंबर',
    icon: Icons.plumbing,
  ),
  SrkServiceCategory(
    id: 'painter',
    title: 'पेंटर',
    icon: Icons.format_paint,
  ),
  SrkServiceCategory(
    id: 'ac_fridge',
    title: 'AC + फ्रिज',
    icon: Icons.ac_unit,
    subcategories: [
      SrkServiceSubcategory(
        id: 'ac',
        title: 'AC',
        children: [
          'AC रिपेयर',
          'इंस्टॉलेशन',
          'अनइंस्टॉलेशन',
          'सर्विसिंग',
          'गैस चार्जिंग',
          'लीकेज जाँच',
          'कंप्रेसर',
          'PCB',
        ],
      ),
      SrkServiceSubcategory(
        id: 'fridge',
        title: 'फ्रिज',
        children: [
          'फ्रिज रिपेयर',
          'कूलिंग समस्या',
          'कंप्रेसर',
          'गैस / लीकेज',
          'PCB और अन्य मरम्मत',
        ],
      ),
    ],
  ),
  SrkServiceCategory(
    id: 'motor_pump',
    title: 'मोटर और पंप',
    icon: Icons.water,
    subcategories: [
      SrkServiceSubcategory(id: 'tullu_pump', title: 'घरेलू टुल्लू पंप'),
      SrkServiceSubcategory(id: 'pump_repair', title: 'पंप रिपेयर'),
      SrkServiceSubcategory(id: 'submersible', title: 'सबमर्सिबल पंप'),
      SrkServiceSubcategory(id: 'winding', title: 'वाइंडिंग'),
      SrkServiceSubcategory(id: 'capacitor', title: 'कैपेसिटर'),
      SrkServiceSubcategory(id: 'starter', title: 'स्टार्टर'),
      SrkServiceSubcategory(id: 'installation_removal', title: 'इंस्टॉलेशन / हटाना'),
    ],
  ),
  SrkServiceCategory(
    id: 'cooler',
    title: 'कूलर',
    icon: Icons.mode_fan,
    subcategories: [
      SrkServiceSubcategory(id: 'cooler_repair', title: 'कूलर रिपेयर'),
    ],
  ),
];

class SrkServiceCategoryPicker extends StatefulWidget {
  const SrkServiceCategoryPicker({
    super.key,
    required this.onSelection,
  });

  /// Emits stable catalogue IDs and display labels only.
  /// It deliberately does not create or submit a booking.
  final void Function({
    required String categoryId,
    required String categoryTitle,
    String? subcategoryId,
    String? subcategoryTitle,
    String? taskTitle,
  }) onSelection;

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
      widget.onSelection(
        categoryId: category.id,
        categoryTitle: category.title,
      );
    }
  }

  void _selectSubcategory(SrkServiceSubcategory subcategory) {
    final category = _category;
    if (category == null) return;
    setState(() => _subcategory = subcategory);
    if (subcategory.children.isEmpty) {
      widget.onSelection(
        categoryId: category.id,
        categoryTitle: category.title,
        subcategoryId: subcategory.id,
        subcategoryTitle: subcategory.title,
      );
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
                onPressed: () => widget.onSelection(
                  categoryId: category!.id,
                  categoryTitle: category.title,
                  subcategoryId: subcategory.id,
                  subcategoryTitle: subcategory.title,
                  taskTitle: task,
                ),
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

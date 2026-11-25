import 'package:flutter_test/flutter_test.dart';
import '../lib/srk_service_catalog.dart';
import '../lib/srk_service_selection_contract.dart';

void main() {
  group('Shared Customer-Technician service selection', () {
    test('emits exact versioned AC task identifiers', () {
      final selection = SrkServiceSelection.create(
        categoryId: 'ac_fridge',
        subcategoryId: 'ac',
        taskId: 'gas_charging',
      )!;

      expect(selection.catalogueVersion, srkServiceCatalogDraftVersion);
      expect(selection.displayName, 'AC + फ्रिज • AC • गैस चार्जिंग');
      expect(selection.toJson(), {
        'catalogue_version': srkServiceCatalogDraftVersion,
        'category_id': 'ac_fridge',
        'subcategory_id': 'ac',
        'task_id': 'gas_charging',
      });
    });

    test('keeps Fridge task IDs separate from AC task IDs', () {
      expect(
        SrkServiceSelection.create(
          categoryId: 'ac_fridge',
          subcategoryId: 'fridge',
          taskId: 'gas_charging',
        ),
        isNull,
      );
      expect(
        SrkServiceSelection.create(
          categoryId: 'ac_fridge',
          subcategoryId: 'fridge',
          taskId: 'fridge_repair',
        )!.toJson()['task_id'],
        'fridge_repair',
      );
    });

    test('rejects unknown or mismatched category hierarchy', () {
      expect(
        SrkServiceSelection.create(
          categoryId: 'unknown',
          subcategoryId: 'ac',
        ),
        isNull,
      );
      expect(
        SrkServiceSelection.create(
          categoryId: 'ac_fridge',
          subcategoryId: 'cooler_repair',
        ),
        isNull,
      );
    });

    test('requires task selection when the chosen subcategory defines tasks', () {
      expect(
        SrkServiceSelection.create(
          categoryId: 'ac_fridge',
          subcategoryId: 'ac',
        ),
        isNull,
      );
    });

    test('allows only category-level selection for unfinished categories', () {
      expect(
        SrkServiceSelection.create(categoryId: 'plumber')!.toJson(),
        {
          'catalogue_version': srkServiceCatalogDraftVersion,
          'category_id': 'plumber',
        },
      );
    });
  });
}

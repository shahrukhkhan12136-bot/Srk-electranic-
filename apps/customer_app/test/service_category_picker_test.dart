import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srk_customer_app/service_category_picker.dart';
import 'package:srk_mobile_core/srk_service_catalog.dart' as catalog;

void main() {
  group('SRK service category picker', () {
    test('exposes the six approved top-level categories in order', () {
      expect(
        srkServiceCategories.map((category) => category.id).toList(),
        [
          'electrician',
          'plumber',
          'painter',
          'ac_fridge',
          'motor_pump',
          'cooler',
        ],
      );
    });

    test('picker category groups stay aligned with shared rate catalogue', () {
      const categoryToCatalogName = {
        'electrician': 'Electrician',
        'plumber': 'Plumber',
        'painter': 'Painter',
        'ac_fridge': 'AC + Fridge',
        'motor_pump': 'Motor & Pump',
        'cooler': 'Cooler',
      };

      for (final pickerCategory in srkServiceCategories) {
        final catalogName = categoryToCatalogName[pickerCategory.id];
        expect(catalogName, isNotNull);
        final catalogCategory = catalog.srkServiceCatalog.singleWhere(
          (item) => item.name == catalogName,
        );
        expect(
          pickerCategory.subcategories.length,
          catalogCategory.options.length,
          reason: 'Picker and shared catalogue differ for ${pickerCategory.id}',
        );
      }
      expect(categoryToCatalogName.length, srkServiceCategories.length);
    });

    test('picker labels, IDs and task lists come from the shared catalogue', () {
      for (var i = 0; i < catalog.srkServiceCatalog.length; i++) {
        final source = catalog.srkServiceCatalog[i];
        final picker = srkServiceCategories[i];
        expect(picker.id, source.id);
        expect(picker.title, source.displayName);
        expect(
          picker.subcategories.map((item) => item.id).toList(),
          source.options.map((item) => item.id).whereType<String>().toList(),
        );
        for (var j = 0; j < picker.subcategories.length; j++) {
          expect(
            picker.subcategories[j].title,
            source.options[j].displayName ?? source.options[j].name,
          );
          expect(
            picker.subcategories[j].children,
            source.options[j].tasks.map((task) => task.name).toList(),
          );
        }
      }
    });

    testWidgets('AC and Fridge show separate task lists', (tester) async {
      Map<String, String?>? selected;
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SrkServiceCategoryPicker(
              onSelection: (selection) {
                selected = selection == null ? null : {
                  'category': selection.categoryId,
                  'subcategory': selection.subcategoryId,
                  'task': selection.taskId,
                };
              },
            ),
          ),
        ),
      ));

      await tester.tap(find.text('AC + फ्रिज'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AC').first);
      await tester.pumpAndSettle();
      expect(find.text('AC रिपेयर'), findsOneWidget);
      expect(find.text('फ्रिज रिपेयर'), findsNothing);

      await tester.tap(find.text('फ्रिज').first);
      await tester.pumpAndSettle();
      expect(find.text('फ्रिज रिपेयर'), findsOneWidget);
      expect(find.text('AC रिपेयर'), findsNothing);

      await tester.tap(find.text('फ्रिज रिपेयर'));
      await tester.pump();
      expect(selected, {
        'category': 'ac_fridge',
        'subcategory': 'fridge',
        'task': 'fridge_repair',
      });
    });

    testWidgets('changing parent choice clears previous completed selection', (tester) async {
      Map<String, String?>? selected;
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SrkServiceCategoryPicker(
              onSelection: (selection) {
                selected = selection == null ? null : {
                  'category': selection.categoryId,
                  'subcategory': selection.subcategoryId,
                  'task': selection.taskId,
                };
              },
            ),
          ),
        ),
      ));

      await tester.tap(find.text('कूलर'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('कूलर रिपेयर'));
      await tester.pump();
      expect(selected?['category'], 'cooler');

      await tester.tap(find.text('AC + फ्रिज'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('कूलर रिपेयर'), findsNothing);
    });

    testWidgets('Cooler selection exposes Cooler Repair only', (tester) async {
      Map<String, String?>? selected;
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SrkServiceCategoryPicker(
              onSelection: (selection) {
                selected = selection == null ? null : {
                  'category': selection.categoryId,
                  'subcategory': selection.subcategoryId,
                  'task': selection.taskId,
                };
              },
            ),
          ),
        ),
      ));

      await tester.tap(find.text('कूलर'));
      await tester.pumpAndSettle();
      expect(find.text('कूलर रिपेयर'), findsOneWidget);
      expect(find.text('वाइंडिंग'), findsNothing);
      await tester.tap(find.text('कूलर रिपेयर'));
      await tester.pump();
      expect(selected, {
        'category': 'cooler',
        'subcategory': 'cooler_repair',
        'task': null,
      });
    });
  });
}

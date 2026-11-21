import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srk_customer_app/service_category_picker.dart';

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
              onSelection: ({
                required String categoryId,
                required String categoryTitle,
                String? subcategoryId,
                String? subcategoryTitle,
                String? taskTitle,
              }) {
                selected = {
                  'category': categoryId,
                  'subcategory': subcategoryId,
                  'task': taskTitle,
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
        'task': 'फ्रिज रिपेयर',
      });
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
              onSelection: ({
                required String categoryId,
                required String categoryTitle,
                String? subcategoryId,
                String? subcategoryTitle,
                String? taskTitle,
              }) {
                selected = {
                  'category': categoryId,
                  'subcategory': subcategoryId,
                  'task': taskTitle,
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

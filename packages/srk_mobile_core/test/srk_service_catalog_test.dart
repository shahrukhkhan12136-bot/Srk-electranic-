import 'package:flutter_test/flutter_test.dart';
import '../lib/srk_service_catalog.dart';

void main() {
  group('SRK service catalogue draft', () {
    test('contains six top-level categories in approved order', () {
      expect(
        srkServiceCatalog.map((category) => category.name).toList(),
        [
          'Electrician',
          'Plumber',
          'Painter',
          'AC + Fridge',
          'Motor & Pump',
          'Cooler',
        ],
      );
    });

    test('keeps AC and Fridge as separate second-level options', () {
      final category = srkServiceCatalog.singleWhere(
        (item) => item.name == 'AC + Fridge',
      );
      expect(category.options.map((item) => item.name).toList(), ['AC', 'Fridge']);
      expect(category.options.first.note, contains('Gas Charging'));
      expect(category.options.first.note, contains('PCB'));
      expect(category.options.last.note, contains('अंतिम दर की पुष्टि बाकी'));
    });

    test('does not invent unconfirmed Plumber and Painter task lists', () {
      final plumber = srkServiceCatalog.singleWhere((item) => item.name == 'Plumber');
      final painter = srkServiceCatalog.singleWhere((item) => item.name == 'Painter');
      expect(plumber.options, isEmpty);
      expect(painter.options, isEmpty);
      expect(plumber.skillLevels, isNotEmpty);
      expect(painter.skillLevels, isNotEmpty);
    });

    test('keeps Motor & Pump winding as fixed HP rates', () {
      final motor = srkServiceCatalog.singleWhere((item) => item.name == 'Motor & Pump');
      final winding = motor.options.singleWhere((item) => item.name == 'Winding');
      expect(winding.rates.map((rate) => rate.label).toList(), [
        '0.5 HP', '1 HP', '1.5 HP', '2 HP', '3 HP', '5 HP',
        '7.5 HP', '10 HP', '15 HP', '20 HP',
      ]);
      expect(winding.rates.first.unit, 'फिक्स');
      expect(winding.note, contains('hourly overtime लागू नहीं'));
    });

    test('keeps Cooler repair fixed at ₹500 with separate parts', () {
      final cooler = srkServiceCatalog.singleWhere((item) => item.name == 'Cooler');
      final repair = cooler.options.single;
      expect(repair.name, 'Cooler Repair');
      expect(repair.rates.single.amount, '₹500');
      expect(repair.rates.single.unit, 'प्रति कूलर फिक्स');
      expect(repair.note, contains('पार्ट्स अलग'));
      expect(repair.note, contains('Motor winding'));
    });
  });
}

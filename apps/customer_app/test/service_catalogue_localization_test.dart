import 'package:flutter_test/flutter_test.dart';
import 'package:srk_customer_app/service_catalogue_localization.dart';

void main() {
  group('SRK customer catalogue Hindi labels', () {
    test('covers every active category, service and distinct skill label', () {
      expect(srkCatalogueHindiTranslations['category']!.length, 6);
      expect(srkCatalogueHindiTranslations['service']!.length, 26);
      expect(srkCatalogueHindiTranslations['skill']!.length, 89);
      expect(srkCatalogueHindiTranslations['level']!.length, 8);
      for (final labels in srkCatalogueHindiTranslations.values) {
        expect(labels.values.every((label) => label.trim().isNotEmpty), isTrue);
      }
    });

    test('shows Hindi labels for known service catalogue names', () {
      expect(srkCatalogueLabel('category', 'Electrician', 'hi'), 'इलेक्ट्रिशियन');
      expect(srkCatalogueLabel('service', 'AC Installation', 'hi'), 'एसी लगाना');
      expect(srkCatalogueLabel('skill', 'Motor/Pump Checking', 'hi'), 'मोटर / पंप की जाँच');
      expect(srkCatalogueLabel('level', 'Expert', 'hi'), 'एक्सपर्ट');
    });

    test('keeps canonical English labels and unknown future labels as fallback', () {
      expect(srkCatalogueLabel('skill', 'AC Compressor Diagnosis', 'en'), 'AC Compressor Diagnosis');
      expect(srkCatalogueLabel('skill', 'New Future Skill', 'hi'), 'New Future Skill');
    });
  });
}

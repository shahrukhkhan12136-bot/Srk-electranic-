import 'package:flutter_test/flutter_test.dart';
import 'package:srk_customer_app/service_category_picker.dart';

void main() {
  group('Live SRK service selection contract', () {
    test('selection carries backend UUIDs rather than draft catalogue labels', () {
      const selection = SrkBackendServiceSelection(
        categoryId: 'category-uuid',
        categoryName: 'Electrician',
        serviceTypeId: 'service-uuid',
        serviceName: 'Residential Wiring',
        skillId: 'skill-uuid',
        skillName: 'New Wiring',
        skillLevelId: 'level-uuid',
        skillLevelName: 'Expert',
        pricingUnit: 'hour',
      );
      expect(selection.categoryId, 'category-uuid');
      expect(selection.serviceTypeId, 'service-uuid');
      expect(selection.skillId, 'skill-uuid');
      expect(selection.skillLevelId, 'level-uuid');
      expect(selection.pricingUnit, 'hour');
    });

    test('fixed-price Motor/Pump selection retains selected HP and server HP choices', () {
      const selection = SrkBackendServiceSelection(
        categoryId: 'motor-category',
        categoryName: 'Motor & Pump',
        serviceTypeId: 'motor-service',
        serviceName: 'Motor/Pump Checking',
        skillId: 'motor-skill',
        skillName: 'Motor Checking',
        skillLevelId: 'motor-level',
        skillLevelName: 'Technician',
        pricingUnit: 'motor_hp',
        pricingRuleId: 'rule-uuid',
        motorHp: 2,
        availableMotorHp: [0.5, 1, 1.5, 2, 3],
      );
      expect(selection.motorHp, 2);
      expect(selection.availableMotorHp, contains(2));
      expect(selection.pricingRuleId, 'rule-uuid');
    });

    test('per-item services retain unit pricing semantics', () {
      const selection = SrkBackendServiceSelection(
        categoryId: 'cooler-category',
        categoryName: 'Cooler Technician',
        serviceTypeId: 'cooler-service',
        serviceName: 'Cooler Repair',
        skillId: 'cooler-skill',
        skillName: 'Cooler Repair',
        skillLevelId: 'cooler-level',
        skillLevelName: 'Basic',
        pricingUnit: 'per_item',
      );
      expect(selection.pricingUnit, 'per_item');
      expect(selection.motorHp, isNull);
    });
  });
}

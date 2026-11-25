import 'package:flutter_test/flutter_test.dart';
import 'package:srk_mobile_core/srk_work_confirmation_contract.dart';

void main() {
  group('Shared work confirmation contract (preview only)', () {
    test('timer needs confirmed state and both server timestamps', () {
      final value = SrkWorkConfirmationContract.fromJson({
        'booking_id': 'b1',
        'request_id': 'r1',
        'requester_role': 'customer',
        'requested_action': 'confirm_start',
        'state': 'start_confirmed',
        'version': 2,
        'server_confirmed_at': '2026-11-21T08:00:00Z',
        'server_started_at': '2026-11-21T08:00:01Z',
      });
      expect(value.timerMayBeShownAsActive, isTrue);
    });

    test('missing server start timestamp never activates timer', () {
      final value = SrkWorkConfirmationContract.fromJson({
        'booking_id': 'b1',
        'request_id': 'r1',
        'requester_role': 'customer',
        'requested_action': 'confirm_start',
        'state': 'start_confirmed',
        'version': 2,
        'server_confirmed_at': '2026-11-21T08:00:00Z',
      });
      expect(value.timerMayBeShownAsActive, isFalse);
    });

    test('completed or unknown state fails closed', () {
      final completed = SrkWorkConfirmationContract.fromJson({
        'booking_id': 'b1',
        'request_id': 'r2',
        'requester_role': 'customer',
        'requested_action': 'confirm_completion',
        'state': 'completion_confirmed',
        'version': 3,
        'server_confirmed_at': '2026-11-21T08:10:00Z',
        'server_started_at': '2026-11-21T08:00:00Z',
        'server_completed_at': '2026-11-21T08:10:00Z',
      });
      final unknown = SrkWorkConfirmationContract.fromJson({});
      expect(completed.timerMayBeShownAsActive, isFalse);
      expect(unknown.state, SrkWorkState.unknown);
      expect(unknown.actor, SrkWorkActor.unknown);
      expect(unknown.action, SrkWorkAction.unknown);
      expect(unknown.version, -1);
    });

    test('server timestamps normalize to UTC', () {
      final value = SrkWorkConfirmationContract.fromJson({
        'booking_id': 'b1',
        'request_id': 'r1',
        'requester_role': 'technician',
        'requested_action': 'request_start',
        'state': 'start_requested',
        'version': 1,
        'server_requested_at': '2026-11-21T13:30:00+05:30',
      });
      expect(value.serverRequestedAt!.isUtc, isTrue);
    });
  });

  group('Shared final bill contract (preview only)', () {
    test('accepts exact non-negative paise breakdown', () {
      final bill = SrkFinalBillContract.fromJson({
        'labour_amount_paise': 10000,
        'approved_materials_amount_paise': 2500,
        'other_charges_amount_paise': 500,
        'total_amount_paise': 13000,
        'currency': 'INR',
        'payment_status': 'unpaid',
        'payment_method': 'online',
        'payment_eligibility': true,
      });
      expect(bill.amountsAreValid, isTrue);
      expect(bill.paymentEligibility, isTrue);
    });

    test('rejects mismatch, missing or negative amounts', () {
      final mismatch = SrkFinalBillContract.fromJson({
        'labour_amount_paise': 10000,
        'approved_materials_amount_paise': 2500,
        'other_charges_amount_paise': 500,
        'total_amount_paise': 12000,
        'currency': 'INR',
        'payment_status': 'unpaid',
        'payment_method': 'cash',
        'payment_eligibility': false,
      });
      final missing = SrkFinalBillContract.fromJson({});
      final negative = SrkFinalBillContract.fromJson({
        'labour_amount_paise': -1,
        'approved_materials_amount_paise': 0,
        'other_charges_amount_paise': 0,
        'total_amount_paise': -1,
      });
      expect(mismatch.amountsAreValid, isFalse);
      expect(missing.amountsAreValid, isFalse);
      expect(negative.amountsAreValid, isFalse);
    });
  });
}

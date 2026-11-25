import 'package:flutter_test/flutter_test.dart';
import 'package:srk_customer_app/customer_confirmation/srk_customer_confirmation_preview.dart';

void main() {
  test('only explicit customer-pending states request attention', () {
    final start = SrkCustomerWorkConfirmationCardPreview.fromProposedJson({
      'state': 'start_confirmation_pending',
      'request_id': 'req-1',
    });
    expect(start.needsCustomerAttention, isTrue);
    expect(start.label, 'काम शुरू करने की पुष्टि बाकी');

    final complete =
        SrkCustomerWorkConfirmationCardPreview.fromProposedJson({
      'state': 'completion_confirmation_pending',
    });
    expect(complete.needsCustomerAttention, isTrue);

    final unknown =
        SrkCustomerWorkConfirmationCardPreview.fromProposedJson({});
    expect(unknown.phase, SrkCustomerConfirmationPhase.unknown);
    expect(unknown.needsCustomerAttention, isFalse);
  });

  test('confirmation preview parses server timestamps as UTC', () {
    final preview =
        SrkCustomerWorkConfirmationCardPreview.fromProposedJson({
      'state': 'start_confirmed',
      'server_requested_at': '2026-11-21T08:00:00+05:30',
      'server_confirmed_at': '2026-11-21T08:02:00+05:30',
    });
    expect(preview.serverRequestedAt!.isUtc, isTrue);
    expect(preview.serverConfirmedAt!.isUtc, isTrue);
  });

  test('bill validates server amount breakdown without recalculating it', () {
    final bill = SrkCustomerFinalBillPreview.fromProposedJson({
      'labour_amount_paise': 50000,
      'total_amount_paise': 50000,
      'currency': 'INR',
      'payment_status': 'unpaid',
      'payment_method': 'online',
      'payment_eligibility': true,
      'receipt_id': 'receipt-1',
    });
    expect(bill.hasValidNonNegativeAmounts, isTrue);
    expect(bill.isBreakdownConsistent, isTrue);
    expect(bill.serverReportsPaymentEligible, isTrue);
    expect(bill.totalAmountPaise, 50000);
  });

  test('bill mismatch or missing/negative amounts fails closed', () {
    final mismatch = SrkCustomerFinalBillPreview.fromProposedJson({
      'labour_amount_paise': 50000,
      'total_amount_paise': 70000,
    });
    expect(mismatch.hasValidNonNegativeAmounts, isTrue);
    expect(mismatch.isBreakdownConsistent, isFalse);

    final invalid = SrkCustomerFinalBillPreview.fromProposedJson({
      'labour_amount_paise': -1,
      'payment_eligibility': 'yes',
    });
    expect(invalid.hasValidNonNegativeAmounts, isFalse);
    expect(invalid.isBreakdownConsistent, isFalse);
    expect(invalid.serverReportsPaymentEligible, isFalse);
  });

  test('server payment eligibility is informational and unknown by default', () {
    final unknown =
        SrkCustomerFinalBillPreview.fromProposedJson({});
    expect(unknown.paymentEligibility, isNull);
    expect(unknown.serverReportsPaymentEligible, isFalse);
  });
}

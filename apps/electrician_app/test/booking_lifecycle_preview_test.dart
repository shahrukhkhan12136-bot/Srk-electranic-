import 'package:flutter_test/flutter_test.dart';
import 'package:srk_electrician_app/verified_services/srk_booking_lifecycle_preview.dart';

void main() {
  test('maps existing non-quote booking states without changing them', () {
    final assigned = SrkTechnicianBookingLifecyclePreview.fromStatus('assigned');
    expect(assigned.phase, SrkTechnicianBookingPhase.assigned);
    expect(assigned.isLegacyQuoteState, isFalse);
    expect(assigned.isTerminal, isFalse);

    final active = SrkTechnicianBookingLifecyclePreview.fromStatus('in_progress');
    expect(active.phase, SrkTechnicianBookingPhase.inProgress);

    final completed = SrkTechnicianBookingLifecyclePreview.fromStatus('completed');
    expect(completed.phase, SrkTechnicianBookingPhase.completed);
    expect(completed.isTerminal, isTrue);
  });

  test('marks all current quote-dependent states as legacy', () {
    for (final status in [
      'awaiting_quote_approval',
      'quote_approved',
      'quote_rejected',
    ]) {
      final view = SrkTechnicianBookingLifecyclePreview.fromStatus(status);
      expect(view.isLegacyQuoteState, isTrue, reason: status);
      expect(view.isTerminal, isFalse, reason: status);
    }
  });

  test('unknown or missing status fails closed to an informational phase', () {
    expect(
      SrkTechnicianBookingLifecyclePreview.fromStatus('future_status').phase,
      SrkTechnicianBookingPhase.unknown,
    );
    expect(
      SrkTechnicianBookingLifecyclePreview.fromStatus(null).phase,
      SrkTechnicianBookingPhase.unknown,
    );
  });
}

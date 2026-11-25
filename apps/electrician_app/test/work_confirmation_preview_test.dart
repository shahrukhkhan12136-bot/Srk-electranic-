import 'package:flutter_test/flutter_test.dart';
import 'package:srk_electrician_app/verified_services/srk_work_confirmation_preview.dart';

void main() {
  Map<String, dynamic> payload({
    String state = 'start_confirmed',
    String? confirmedAt = '2026-11-21T08:00:00Z',
    String? startedAt = '2026-11-21T08:00:01Z',
    String? completedAt,
    String action = 'start_work',
    String bookingId = 'booking-1',
    String requestId = 'request-1',
  }) => {
        'booking_id': bookingId,
        'request_id': requestId,
        'requester_role': 'technician',
        'requested_action': action,
        'state': state,
        'server_requested_at': '2026-11-21T07:59:00Z',
        'server_confirmed_at': confirmedAt,
        'server_started_at': startedAt,
        'server_completed_at': completedAt,
        'version': 2,
        'idempotency_key': 'idem-1',
      };

  test('timer stays inactive until server confirmation and start times exist', () {
    final noConfirmation = SrkWorkConfirmationPreview.fromProposedJson(
      payload(confirmedAt: null),
    );
    expect(noConfirmation.mayDisplayServerTimerAsActive, isFalse);

    final noServerStart = SrkWorkConfirmationPreview.fromProposedJson(
      payload(startedAt: null),
    );
    expect(noServerStart.mayDisplayServerTimerAsActive, isFalse);

    final confirmed = SrkWorkConfirmationPreview.fromProposedJson(payload());
    expect(confirmed.mayDisplayServerTimerAsActive, isTrue);
  });

  test('completion timestamp stops timer even if state is stale', () {
    final preview = SrkWorkConfirmationPreview.fromProposedJson(
      payload(completedAt: '2026-11-21T09:00:00Z'),
    );
    expect(preview.mayDisplayServerTimerAsActive, isFalse);
  });

  test('unknown or missing proposed states fail closed', () {
    expect(
      SrkWorkConfirmationPreview.fromProposedJson(
        payload(state: 'future_backend_state'),
      ).state,
      SrkWorkConfirmationState.unknown,
    );
    expect(
      SrkWorkConfirmationPreview.fromProposedJson({}).state,
      SrkWorkConfirmationState.unknown,
    );
    expect(
      SrkWorkConfirmationPreview.fromProposedJson({}).requestedAction,
      SrkWorkRequestedAction.unknown,
    );
  });

  test('recognizes the same request to support duplicate-safe UI handling', () {
    final first = SrkWorkConfirmationPreview.fromProposedJson(payload());
    final retry = SrkWorkConfirmationPreview.fromProposedJson(payload());
    final another = SrkWorkConfirmationPreview.fromProposedJson(
      payload(requestId: 'request-2'),
    );
    expect(first.isSameRequestAs(retry), isTrue);
    expect(first.isSameRequestAs(another), isFalse);
    expect(
      SrkWorkConfirmationPreview.fromProposedJson(
        payload(bookingId: '', requestId: ''),
      ).isSameRequestAs(
        SrkWorkConfirmationPreview.fromProposedJson(
          payload(bookingId: '', requestId: ''),
        ),
      ),
      isFalse,
    );
  });

  test('parses server timestamps as UTC and validates version', () {
    final preview = SrkWorkConfirmationPreview.fromProposedJson(payload());
    expect(preview.serverConfirmedAt!.isUtc, isTrue);
    expect(preview.version, 2);
    expect(
      SrkWorkConfirmationPreview.fromProposedJson({'version': -1}).version,
      isNull,
    );
  });
}

/// Proposed, read-only contract preview for Customer ↔ Technician work
/// confirmation. These names are NOT deployed backend statuses or RPC fields.
///
/// This DTO never reads the device clock, starts/stops a timer, authorizes a
/// transition, or sends a request. The backend must publish the exact contract
/// before either app can connect to it.
enum SrkWorkConfirmationState {
  startRequested,
  startConfirmationPending,
  startConfirmed,
  completionRequested,
  completionConfirmationPending,
  completionConfirmed,
  disputed,
  unknown,
}

enum SrkWorkRequestedAction {
  startWork,
  completeWork,
  unknown,
}

class SrkWorkConfirmationPreview {
  const SrkWorkConfirmationPreview({
    required this.bookingId,
    required this.requestId,
    required this.requesterRole,
    required this.requestedAction,
    required this.state,
    required this.serverRequestedAt,
    required this.serverConfirmedAt,
    required this.serverStartedAt,
    required this.serverCompletedAt,
    required this.version,
    required this.idempotencyKey,
  });

  final String? bookingId;
  final String? requestId;
  final String? requesterRole;
  final SrkWorkRequestedAction requestedAction;
  final SrkWorkConfirmationState state;
  final DateTime? serverRequestedAt;
  final DateTime? serverConfirmedAt;
  final DateTime? serverStartedAt;
  final DateTime? serverCompletedAt;
  final int? version;
  final String? idempotencyKey;

  /// A timer may be displayed as active only when the server has supplied
  /// both confirmation and start timestamps and has not supplied completion.
  /// No elapsed duration is calculated on the client.
  bool get mayDisplayServerTimerAsActive {
    final timerState = state == SrkWorkConfirmationState.startConfirmed ||
        state == SrkWorkConfirmationState.completionRequested ||
        state == SrkWorkConfirmationState.completionConfirmationPending;
    return timerState &&
        serverConfirmedAt != null &&
        serverStartedAt != null &&
        serverCompletedAt == null;
  }

  /// Duplicate recognition only: this does not submit, retry, or authorize
  /// requests. Both IDs must be present to avoid accidental empty-ID matches.
  bool isSameRequestAs(SrkWorkConfirmationPreview other) {
    final currentBooking = bookingId?.trim();
    final otherBooking = other.bookingId?.trim();
    final currentRequest = requestId?.trim();
    final otherRequest = other.requestId?.trim();
    return currentBooking != null &&
        currentBooking.isNotEmpty &&
        otherBooking == currentBooking &&
        currentRequest != null &&
        currentRequest.isNotEmpty &&
        otherRequest == currentRequest;
  }

  factory SrkWorkConfirmationPreview.fromProposedJson(
    Map<String, dynamic> json,
  ) {
    String? readString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    }

    DateTime? readServerTime(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value.trim())?.toUtc();
    }

    final rawAction = readString('requested_action');
    final rawState = readString('state');

    return SrkWorkConfirmationPreview(
      bookingId: readString('booking_id'),
      requestId: readString('request_id'),
      requesterRole: readString('requester_role'),
      requestedAction: switch (rawAction) {
        'start_work' => SrkWorkRequestedAction.startWork,
        'complete_work' => SrkWorkRequestedAction.completeWork,
        _ => SrkWorkRequestedAction.unknown,
      },
      state: switch (rawState) {
        'start_requested' => SrkWorkConfirmationState.startRequested,
        'start_confirmation_pending' =>
          SrkWorkConfirmationState.startConfirmationPending,
        'start_confirmed' => SrkWorkConfirmationState.startConfirmed,
        'completion_requested' =>
          SrkWorkConfirmationState.completionRequested,
        'completion_confirmation_pending' =>
          SrkWorkConfirmationState.completionConfirmationPending,
        'completion_confirmed' =>
          SrkWorkConfirmationState.completionConfirmed,
        'disputed' => SrkWorkConfirmationState.disputed,
        _ => SrkWorkConfirmationState.unknown,
      },
      serverRequestedAt: readServerTime('server_requested_at'),
      serverConfirmedAt: readServerTime('server_confirmed_at'),
      serverStartedAt: readServerTime('server_started_at'),
      serverCompletedAt: readServerTime('server_completed_at'),
      version: json['version'] is int && (json['version'] as int) >= 0
          ? json['version'] as int
          : null,
      idempotencyKey: readString('idempotency_key'),
    );
  }
}

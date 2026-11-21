/// Shared, preview-only contract for Customer <-> Technician work confirmation.
///
/// IMPORTANT:
/// These names are a proposed frontend DTO, NOT a deployed backend API.
/// Do not wire to Supabase or live booking actions until the backend publishes
/// and deploys the exact schema, enum values, authorization and idempotency rules.
enum SrkWorkActor { customer, technician, admin, unknown }

enum SrkWorkAction { requestStart, confirmStart, requestCompletion, confirmCompletion, dispute, unknown }

enum SrkWorkState {
  startRequested,
  startConfirmationPending,
  startConfirmed,
  completionRequested,
  completionConfirmationPending,
  completionConfirmed,
  disputed,
  other,
  unknown,
}

class SrkWorkConfirmationContract {
  const SrkWorkConfirmationContract({
    required this.bookingId,
    required this.requestId,
    required this.actor,
    required this.action,
    required this.state,
    required this.version,
    this.idempotencyKey,
    this.serverRequestedAt,
    this.serverConfirmedAt,
    this.serverStartedAt,
    this.serverCompletedAt,
  });

  final String bookingId;
  final String requestId;
  final SrkWorkActor actor;
  final SrkWorkAction action;
  final SrkWorkState state;
  final int version;
  final String? idempotencyKey;
  final DateTime? serverRequestedAt;
  final DateTime? serverConfirmedAt;
  final DateTime? serverStartedAt;
  final DateTime? serverCompletedAt;

  /// Presentation-only. This does not authorize work or start a server timer.
  bool get timerMayBeShownAsActive =>
      state == SrkWorkState.startConfirmed &&
      serverConfirmedAt != null &&
      serverStartedAt != null &&
      serverCompletedAt == null;

  factory SrkWorkConfirmationContract.fromJson(Map<String, Object?> json) {
    String readString(String key) => json[key] is String ? json[key] as String : '';
    int readVersion() => json['version'] is int ? json['version'] as int : -1;
    DateTime? readDate(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toUtc();
    }

    return SrkWorkConfirmationContract(
      bookingId: readString('booking_id'),
      requestId: readString('request_id'),
      actor: _actorFrom(readString('requester_role')),
      action: _actionFrom(readString('requested_action')),
      state: _stateFrom(readString('state')),
      version: readVersion(),
      idempotencyKey: json['idempotency_key'] is String
          ? json['idempotency_key'] as String
          : null,
      serverRequestedAt: readDate('server_requested_at'),
      serverConfirmedAt: readDate('server_confirmed_at'),
      serverStartedAt: readDate('server_started_at'),
      serverCompletedAt: readDate('server_completed_at'),
    );
  }

  static SrkWorkActor _actorFrom(String value) => switch (value) {
        'customer' => SrkWorkActor.customer,
        'technician' => SrkWorkActor.technician,
        'admin' => SrkWorkActor.admin,
        _ => SrkWorkActor.unknown,
      };

  static SrkWorkAction _actionFrom(String value) => switch (value) {
        'request_start' => SrkWorkAction.requestStart,
        'confirm_start' => SrkWorkAction.confirmStart,
        'request_completion' => SrkWorkAction.requestCompletion,
        'confirm_completion' => SrkWorkAction.confirmCompletion,
        'dispute' => SrkWorkAction.dispute,
        _ => SrkWorkAction.unknown,
      };

  static SrkWorkState _stateFrom(String value) => switch (value) {
        'start_requested' => SrkWorkState.startRequested,
        'start_confirmation_pending' => SrkWorkState.startConfirmationPending,
        'start_confirmed' => SrkWorkState.startConfirmed,
        'completion_requested' => SrkWorkState.completionRequested,
        'completion_confirmation_pending' => SrkWorkState.completionConfirmationPending,
        'completion_confirmed' => SrkWorkState.completionConfirmed,
        'disputed' => SrkWorkState.disputed,
        'other' => SrkWorkState.other,
        _ => SrkWorkState.unknown,
      };
}

/// Server-calculated final bill preview. All amounts are integer paise.
class SrkFinalBillContract {
  const SrkFinalBillContract({
    required this.labourAmountPaise,
    required this.approvedMaterialsAmountPaise,
    required this.otherChargesAmountPaise,
    required this.totalAmountPaise,
    required this.currency,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentEligibility,
    this.receiptId,
  });

  final int labourAmountPaise;
  final int approvedMaterialsAmountPaise;
  final int otherChargesAmountPaise;
  final int totalAmountPaise;
  final String currency;
  final String paymentStatus;
  final String paymentMethod;
  final bool paymentEligibility;
  final String? receiptId;

  bool get amountsAreValid =>
      labourAmountPaise >= 0 &&
      approvedMaterialsAmountPaise >= 0 &&
      otherChargesAmountPaise >= 0 &&
      totalAmountPaise >= 0 &&
      labourAmountPaise + approvedMaterialsAmountPaise + otherChargesAmountPaise ==
          totalAmountPaise;

  factory SrkFinalBillContract.fromJson(Map<String, Object?> json) {
    int readAmount(String key) => json[key] is int ? json[key] as int : -1;
    return SrkFinalBillContract(
      labourAmountPaise: readAmount('labour_amount_paise'),
      approvedMaterialsAmountPaise: readAmount('approved_materials_amount_paise'),
      otherChargesAmountPaise: readAmount('other_charges_amount_paise'),
      totalAmountPaise: readAmount('total_amount_paise'),
      currency: json['currency'] is String ? json['currency'] as String : '',
      paymentStatus: json['payment_status'] is String ? json['payment_status'] as String : '',
      paymentMethod: json['payment_method'] is String ? json['payment_method'] as String : '',
      paymentEligibility: json['payment_eligibility'] == true,
      receiptId: json['receipt_id'] is String ? json['receipt_id'] as String : null,
    );
  }
}

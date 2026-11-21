/// Read-only Customer presentation previews for a proposed quote-free flow.
///
/// Field names and states are illustrative, not a deployed backend contract.
/// This model cannot confirm work, authorize payment, or alter a booking.
enum SrkCustomerConfirmationPhase {
  startConfirmationPending,
  completionConfirmationPending,
  startConfirmed,
  completionConfirmed,
  disputed,
  other,
  unknown,
}

class SrkCustomerWorkConfirmationCardPreview {
  const SrkCustomerWorkConfirmationCardPreview({
    required this.phase,
    required this.label,
    required this.requestId,
    required this.serverRequestedAt,
    required this.serverConfirmedAt,
  });

  final SrkCustomerConfirmationPhase phase;
  final String label;
  final String? requestId;
  final DateTime? serverRequestedAt;
  final DateTime? serverConfirmedAt;

  /// Presentation hint only. It must never enable an action or replace
  /// server-side ownership/authorization checks.
  bool get needsCustomerAttention =>
      phase == SrkCustomerConfirmationPhase.startConfirmationPending ||
      phase == SrkCustomerConfirmationPhase.completionConfirmationPending;

  factory SrkCustomerWorkConfirmationCardPreview.fromProposedJson(
    Map<String, dynamic> json,
  ) {
    String? readString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    }

    DateTime? readTime(String key) {
      final raw = readString(key);
      return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    }

    final rawState = readString('state');
    final phase = switch (rawState) {
      'start_confirmation_pending' =>
        SrkCustomerConfirmationPhase.startConfirmationPending,
      'completion_confirmation_pending' =>
        SrkCustomerConfirmationPhase.completionConfirmationPending,
      'start_confirmed' => SrkCustomerConfirmationPhase.startConfirmed,
      'completion_confirmed' =>
        SrkCustomerConfirmationPhase.completionConfirmed,
      'disputed' => SrkCustomerConfirmationPhase.disputed,
      'start_requested' || 'completion_requested' =>
        SrkCustomerConfirmationPhase.other,
      _ => SrkCustomerConfirmationPhase.unknown,
    };

    final label = switch (phase) {
      SrkCustomerConfirmationPhase.startConfirmationPending =>
        'काम शुरू करने की पुष्टि बाकी',
      SrkCustomerConfirmationPhase.completionConfirmationPending =>
        'काम पूरा होने की पुष्टि बाकी',
      SrkCustomerConfirmationPhase.startConfirmed => 'काम शुरू होने की पुष्टि हो गई',
      SrkCustomerConfirmationPhase.completionConfirmed =>
        'काम पूरा होने की पुष्टि हो गई',
      SrkCustomerConfirmationPhase.disputed => 'जाँच / विवाद की स्थिति',
      SrkCustomerConfirmationPhase.other => 'काम की प्रक्रिया जारी',
      SrkCustomerConfirmationPhase.unknown => 'पुष्टि की स्थिति उपलब्ध नहीं',
    };

    return SrkCustomerWorkConfirmationCardPreview(
      phase: phase,
      label: label,
      requestId: readString('request_id'),
      serverRequestedAt: readTime('server_requested_at'),
      serverConfirmedAt: readTime('server_confirmed_at'),
    );
  }
}

/// Final bill amounts are represented in integer paise to avoid floating
/// point rounding. These are server-returned values, never client-calculated
/// charges. This preview is read-only and does not authorize payment.
class SrkCustomerFinalBillPreview {
  const SrkCustomerFinalBillPreview({
    required this.labourAmountPaise,
    required this.approvedMaterialsAmountPaise,
    required this.otherChargesAmountPaise,
    required this.totalAmountPaise,
    required this.currency,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentEligibility,
    required this.receiptId,
  });

  final int? labourAmountPaise;
  final int? approvedMaterialsAmountPaise;
  final int? otherChargesAmountPaise;
  final int? totalAmountPaise;
  final String? currency;
  final String? paymentStatus;
  final String? paymentMethod;
  final bool? paymentEligibility;
  final String? receiptId;

  bool get hasValidNonNegativeAmounts {
    final values = [
      labourAmountPaise,
      approvedMaterialsAmountPaise,
      otherChargesAmountPaise,
      totalAmountPaise,
    ];
    return values.every((value) => value != null && value >= 0);
  }

  /// A consistency warning only. Server total remains authoritative; a
  /// mismatch must be shown as needing refresh/review, not silently fixed.
  bool get isBreakdownConsistent =>
      hasValidNonNegativeAmounts &&
      labourAmountPaise! +
              approvedMaterialsAmountPaise! +
              otherChargesAmountPaise! ==
          totalAmountPaise;

  /// Informational server flag only. Do not use this getter to call a payment
  /// API: backend must revalidate eligibility on every payment request.
  bool get serverReportsPaymentEligible => paymentEligibility == true;

  factory SrkCustomerFinalBillPreview.fromProposedJson(
    Map<String, dynamic> json,
  ) {
    int? readPaise(String key) {
      final value = json[key];
      if (value is int && value >= 0) return value;
      return null;
    }

    String? readString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    }

    return SrkCustomerFinalBillPreview(
      labourAmountPaise: readPaise('labour_amount_paise'),
      approvedMaterialsAmountPaise:
          readPaise('approved_materials_amount_paise'),
      otherChargesAmountPaise: readPaise('other_charges_amount_paise'),
      totalAmountPaise: readPaise('total_amount_paise'),
      currency: readString('currency'),
      paymentStatus: readString('payment_status'),
      paymentMethod: readString('payment_method'),
      paymentEligibility: json['payment_eligibility'] is bool
          ? json['payment_eligibility'] as bool
          : null,
      receiptId: readString('receipt_id'),
    );
  }
}

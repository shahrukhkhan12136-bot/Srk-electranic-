/// Read-only presentation mapping for the currently deployed booking states.
///
/// This does not define or authorize transitions. Quote-related states are
/// explicitly marked legacy because the current backend still requires them.
enum SrkTechnicianBookingPhase {
  assigned,
  inspection,
  waitingForLegacyQuoteApproval,
  legacyQuoteApproved,
  legacyQuoteRejected,
  inProgress,
  completed,
  unknown,
}

class SrkTechnicianBookingLifecyclePreview {
  const SrkTechnicianBookingLifecyclePreview({
    required this.phase,
    required this.label,
    required this.isLegacyQuoteState,
    required this.isTerminal,
  });

  final SrkTechnicianBookingPhase phase;
  final String label;
  final bool isLegacyQuoteState;
  final bool isTerminal;

  static SrkTechnicianBookingLifecyclePreview fromStatus(String? rawStatus) {
    final status = rawStatus?.trim();
    switch (status) {
      case 'assigned':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.assigned,
          label: 'इलेक्ट्रिशियन नियुक्त',
          isLegacyQuoteState: false,
          isTerminal: false,
        );
      case 'inspection':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.inspection,
          label: 'जाँच / निरीक्षण',
          isLegacyQuoteState: false,
          isTerminal: false,
        );
      case 'awaiting_quote_approval':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.waitingForLegacyQuoteApproval,
          label: 'पुराने सिस्टम में ग्राहक की कोटेशन मंजूरी बाकी',
          isLegacyQuoteState: true,
          isTerminal: false,
        );
      case 'quote_approved':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.legacyQuoteApproved,
          label: 'पुराने सिस्टम में कोटेशन मंजूर',
          isLegacyQuoteState: true,
          isTerminal: false,
        );
      case 'quote_rejected':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.legacyQuoteRejected,
          label: 'पुराने सिस्टम में कोटेशन बदलाव बाकी',
          isLegacyQuoteState: true,
          isTerminal: false,
        );
      case 'in_progress':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.inProgress,
          label: 'काम जारी',
          isLegacyQuoteState: false,
          isTerminal: false,
        );
      case 'completed':
        return const SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.completed,
          label: 'काम पूरा',
          isLegacyQuoteState: false,
          isTerminal: true,
        );
      default:
        return SrkTechnicianBookingLifecyclePreview(
          phase: SrkTechnicianBookingPhase.unknown,
          label: status == null || status.isEmpty
              ? 'स्थिति उपलब्ध नहीं'
              : status,
          isLegacyQuoteState: false,
          isTerminal: false,
        );
    }
  }
}

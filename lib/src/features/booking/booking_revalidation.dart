// lib/src/features/booking/booking_revalidation.dart — the result of a
// pre-payment revalidation of the booking draft. Dart port of the RN app's
// `revalidateDraft` outcome.
//
// Before charging, the app re-checks the draft against the LIVE catalog
// (README Module 13): is the service still active, is the chosen option still
// offered, is the slot still open, and has the price drifted? Those three
// answers collapse into one outcome the Review screen acts on:
//   • ok          → nothing changed; proceed to checkout.
//   • priceUpdated → the unit price drifted; the draft was auto-corrected and an
//                    INFO banner explains the new total (the user re-confirms).
//   • blocked     → the service/option/slot is gone; a BLOCKING banner stops the
//                    flow until the user fixes the draft (edit a step).
// The controller ([BookingDraftController.revalidate]) produces this; the screen
// only renders it.

enum RevalidationKind { ok, priceUpdated, blocked }

class RevalidationOutcome {
  final RevalidationKind kind;

  /// The banner text for [priceUpdated] / [blocked]; null for [ok].
  final String? message;

  const RevalidationOutcome._(this.kind, this.message);

  const RevalidationOutcome.ok() : this._(RevalidationKind.ok, null);
  const RevalidationOutcome.priceUpdated(String message)
      : this._(RevalidationKind.priceUpdated, message);
  const RevalidationOutcome.blocked(String message)
      : this._(RevalidationKind.blocked, message);

  /// The draft is fine as-is — safe to continue to payment.
  bool get canProceed => kind == RevalidationKind.ok;

  /// Something is gone — the user must fix the draft before paying.
  bool get isBlocked => kind == RevalidationKind.blocked;
}

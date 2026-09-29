// lib/src/features/booking — the booking-flow feature's PUBLIC API (barrel).
// The Dart analog of the RN app's booking store + `src/features/booking`.
//
// Built so far:
//   Module 11 — the booking DRAFT store: the in-memory single-service draft
//               (BookingDraft + its derived reads / buildCartItem) and the
//               Riverpod controller/provider that mutates it. Used first by the
//               Service Detail screen (which STARTS the draft) and then by the
//               Location / Schedule / Review steps.
// Coming: Location + Schedule (Module 12), Review + cart (Module 13).

export 'booking_controller.dart' show BookingDraftController, bookingDraftProvider;
export 'booking_draft.dart' show BookingDraft;

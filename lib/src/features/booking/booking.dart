// lib/src/features/booking — the booking-flow feature's PUBLIC API (barrel).
// The Dart analog of the RN app's booking store + `src/features/booking`.
//
// Built so far:
//   Module 11 — the booking DRAFT store: the in-memory single-service draft
//               (BookingDraft + its derived reads / buildCartItem) and the
//               Riverpod controller/provider that mutates it. Used first by the
//               Service Detail screen (which STARTS the draft) and then by the
//               Location / Schedule / Review steps.
//   Module 12 — Location + Schedule: the mock LocationPicker + preset Dubai areas,
//               the client-side availability source ([daySlotsProvider]) and its
//               Calendar + TimeSlots pickers. (Screens are imported directly by the
//               router, like the catalog screens — not part of this barrel.)
//   Module 13 — Review: the pre-payment revalidation ([BookingDraftController.revalidate]
//               + [RevalidationOutcome]) that reconciles the draft against the live
//               catalog before checkout. (The Review screen is imported directly by
//               the router; the cart lives in features/cart.)

export 'availability_providers.dart'
    show availabilityRepositoryProvider, daySlotsProvider, kAvailabilityStaleTime;
export 'availability_repository.dart' show AvailabilityRepository;
export 'booking_controller.dart' show BookingDraftController, bookingDraftProvider;
export 'booking_draft.dart' show BookingDraft;
export 'booking_revalidation.dart' show RevalidationOutcome, RevalidationKind;
export 'data/dubai_areas.dart' show DubaiArea, kDubaiAreas;

// lib/src/features/booking/booking_controller.dart — the booking DRAFT store.
// The Riverpod analog of the RN app's `useBookingStore` (zustand). Holds the
// in-progress [BookingDraft] in memory and exposes the same mutations.
//
// Riverpod's Notifier IS the store: `state` is the current draft, reassigning it
// notifies listeners (the zustand `set` equivalent). The provider is kept alive
// for the app's lifetime (a normal, non-autoDispose NotifierProvider) so the
// draft survives navigating between the flow's steps — but it's never persisted
// to disk (see booking_draft.dart for why); `reset()` clears it after a booking
// is placed, or on logout.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'booking_draft.dart';

class BookingDraftController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => BookingDraft.empty;

  /// Begin configuring a service — sets service/option and clears everything else
  /// (a fresh flow). Mirrors RN `start`.
  void start(Service service, [ServiceOption? option]) {
    state = BookingDraft(service: service, option: option);
  }

  /// Change (or clear, with null) the chosen option, keeping the rest.
  void setOption(ServiceOption? option) {
    state = BookingDraft(
      service: state.service,
      option: option,
      addons: state.addons,
      location: state.location,
      slot: state.slot,
      notes: state.notes,
    );
  }

  /// Toggle a single add-on on/off (matched by id).
  void toggleAddon(ServiceAddon addon) {
    final on = state.addons.any((a) => a.id == addon.id);
    final next = on
        ? state.addons.where((a) => a.id != addon.id).toList()
        : [...state.addons, addon];
    setAddons(next);
  }

  /// Replace the whole set of selected add-ons at once (detail-screen Continue).
  void setAddons(List<ServiceAddon> addons) {
    state = BookingDraft(
      service: state.service,
      option: state.option,
      addons: addons,
      location: state.location,
      slot: state.slot,
      notes: state.notes,
    );
  }

  /// Set (or clear) the booking location (Location step, Module 12).
  void setLocation(BookingLocation? location) {
    state = BookingDraft(
      service: state.service,
      option: state.option,
      addons: state.addons,
      location: location,
      slot: state.slot,
      notes: state.notes,
    );
  }

  /// Set (or clear) the chosen slot (Schedule step, Module 12).
  void setSlot(TimeSlot? slot) {
    state = BookingDraft(
      service: state.service,
      option: state.option,
      addons: state.addons,
      location: state.location,
      slot: slot,
      notes: state.notes,
    );
  }

  /// Update the notes field (Review step, Module 13).
  void setNotes(String notes) {
    state = BookingDraft(
      service: state.service,
      option: state.option,
      addons: state.addons,
      location: state.location,
      slot: state.slot,
      notes: notes,
    );
  }

  /// Overwrite the base unit price with a freshly-fetched live value
  /// (pre-checkout revalidation, Module 13) — applied to the chosen option, or the
  /// service's base price when there's no option. Only the price changes. No-op
  /// when nothing is configured. Mirrors RN `applyLiveUnitPrice`.
  void applyLiveUnitPrice(Money price) {
    final s = state.service;
    if (s == null) return;
    if (state.option != null) {
      setOption(state.option!.copyWith(price: price));
    } else {
      state = BookingDraft(
        service: s.copyWith(basePrice: price),
        option: null,
        addons: state.addons,
        location: state.location,
        slot: state.slot,
        notes: state.notes,
      );
    }
  }

  /// Clear the draft — after a booking is added/placed, or on logout.
  void reset() => state = BookingDraft.empty;
}

/// The in-memory booking draft. Read the whole draft, or a `.select`ed field, and
/// call the controller's methods to mutate it.
final bookingDraftProvider =
    NotifierProvider<BookingDraftController, BookingDraft>(
  BookingDraftController.new,
);

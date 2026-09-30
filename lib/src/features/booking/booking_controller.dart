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

import '../../core/format/date_time.dart';
import '../../models/models.dart';
import '../services/catalog_repository.dart';
import 'availability_providers.dart';
import 'booking_draft.dart';
import 'booking_revalidation.dart';

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

  /// Pre-payment revalidation (Module 13). Re-check the draft against the LIVE
  /// catalog just before charging, and reconcile what safely can be:
  ///   • service removed / inactive        → blocked.
  ///   • chosen option no longer offered    → blocked.
  ///   • chosen slot taken / past / gone    → blocked.
  ///   • unit price drifted                 → auto-apply the live price + inform.
  ///   • nothing changed                    → ok.
  /// Mirrors RN's `revalidateDraft`. The Review screen renders the [RevalidationOutcome]
  /// (info banner + updated total, or a blocking banner) and only proceeds on [ok].
  Future<RevalidationOutcome> revalidate() async {
    final draft = state;
    final service = draft.service;
    if (service == null) {
      return const RevalidationOutcome.blocked('Nothing to book.');
    }

    // Fetch the live service. A 404 (or inactive) means it's gone from the catalog.
    final Service live;
    try {
      live = await ref.read(catalogRepositoryProvider).getServiceById(service.id);
    } on ServiceNotFoundError {
      return const RevalidationOutcome.blocked(
          'This service is no longer available. Please start a new booking.');
    }
    if (!live.active) {
      return const RevalidationOutcome.blocked(
          'This service is no longer available. Please start a new booking.');
    }

    // Resolve the live unit price: the chosen option's (must still exist), else base.
    final Money livePrice;
    final draftOption = draft.option;
    if (draftOption != null) {
      final liveOption = _optionById(live, draftOption.id);
      if (liveOption == null) {
        return const RevalidationOutcome.blocked(
            'The option you chose is no longer offered. Please review your selection.');
      }
      livePrice = liveOption.price;
    } else {
      livePrice = live.basePrice;
    }

    // Is the chosen slot still open? Re-generate the day's slots (client-side, the
    // same source the Schedule step used) and confirm ours is present + available.
    final slot = draft.slot;
    if (slot != null) {
      final date = toLocalIsoDate(slot.start);
      final liveSlots =
          ref.read(availabilityRepositoryProvider).buildSlots(date);
      final liveSlot = _slotById(liveSlots, slot.id);
      if (liveSlot == null || !liveSlot.isAvailable) {
        return const RevalidationOutcome.blocked(
            'That time slot is no longer available. Please pick another time.');
      }
    }

    // Price drift → auto-apply the live price and tell the user (they re-confirm).
    final current = draft.unitPrice;
    if (current != null && current != livePrice) {
      applyLiveUnitPrice(livePrice);
      return RevalidationOutcome.priceUpdated(
        'The price changed from ${current.format()} to ${livePrice.format()}. '
        "We've updated your total — please review and confirm.",
      );
    }

    return const RevalidationOutcome.ok();
  }

  static ServiceOption? _optionById(Service service, String id) {
    for (final o in service.options) {
      if (o.id == id) return o;
    }
    return null;
  }

  static TimeSlot? _slotById(List<TimeSlot> slots, String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// The in-memory booking draft. Read the whole draft, or a `.select`ed field, and
/// call the controller's methods to mutate it.
final bookingDraftProvider =
    NotifierProvider<BookingDraftController, BookingDraft>(
  BookingDraftController.new,
);

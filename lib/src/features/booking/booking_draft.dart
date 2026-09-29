// lib/src/features/booking/booking_draft.dart — the single-service booking DRAFT
// (immutable value) + its derived reads. Dart port of the RN app's BookingDraft
// type (`src/types/booking.ts`) and the pure selectors from `useBookingStore`
// (selectDraftUnitPrice / selectDraftSubtotal / selectDraftDuration /
// buildCartItem).
//
// The in-progress booking the user assembles across ONE service's flow:
//   service detail (option + add-ons) → location → schedule → review.
// Everything past the service is optional/in-progress. The controller
// (booking_controller.dart) holds this in memory and mutates it; the review /
// checkout screens turn a complete draft into a CartItem via [buildCartItem].
//
// Kept as a plain immutable model (not a Freezed/JSON type) because — unlike the
// cart (Module 13) — the draft is TRANSIENT and never persisted: a saved slot
// would be stale on reopen, and availability is refetched each session anyway.

import 'dart:math';

import '../../models/models.dart';

class BookingDraft {
  /// The service being configured — null before the flow starts.
  final Service? service;

  /// The chosen sub-service, when the service has options.
  final ServiceOption? option;

  /// The selected extras (multi-select). Empty until any are ticked.
  final List<ServiceAddon> addons;

  /// Where the visit happens, set on the Location step (Module 12).
  final BookingLocation? location;

  /// The chosen slot, set on the Schedule step (Module 12).
  final TimeSlot? slot;

  /// Free-text instructions for the provider, entered on Review (Module 13).
  /// Kept as a plain string ('' = none); normalized to null at the edges.
  final String notes;

  const BookingDraft({
    this.service,
    this.option,
    this.addons = const [],
    this.location,
    this.slot,
    this.notes = '',
  });

  /// The empty draft — no service configured yet. The controller's initial state
  /// and what `reset()` returns.
  static const BookingDraft empty = BookingDraft();

  /// Whether a service has been chosen — the booking-flow guard's gate for the
  /// Location step.
  bool get hasService => service != null;

  /// The base unit price in effect: the chosen option's, else the service's base.
  /// Null before a service is configured.
  Money? get unitPrice {
    final s = service;
    if (s == null) return null;
    return option?.price ?? s.basePrice;
  }

  /// The subtotal = base unit price + every selected add-on's price (same
  /// currency). Null before a service is configured.
  Money? get subtotal {
    final base = unitPrice;
    if (base == null) return null;
    return addons.fold<Money>(base, (sum, a) => sum + a.price);
  }

  /// Total visit duration in minutes: base (option's, else service's) + every
  /// selected add-on's extra time. Null before a service is configured.
  int? get duration {
    final s = service;
    if (s == null) return null;
    final base = option?.duration ?? s.duration;
    return addons.fold<int>(base, (sum, a) => sum + (a.duration ?? 0));
  }

  /// The notes, normalized: blank/whitespace → null (matches RN's
  /// `useBookingDraft` and the optional field on the confirmed booking).
  String? get normalizedNotes => notes.trim().isEmpty ? null : notes;

  /// Turn a complete draft into a [CartItem] — the snapshot the cart and checkout
  /// read. Returns null when there's no service (callers guard before offering
  /// Add-to-cart / Pay-now, so this is a type-safety net). Mirrors RN's
  /// `buildCartItem`.
  CartItem? buildCartItem() {
    final s = service;
    if (s == null) return null;
    final unit = option?.price ?? s.basePrice;
    return CartItem(
      id: _makeLineId(s.id),
      serviceId: s.id,
      optionId: option?.id,
      quantity: 1,
      serviceName: s.name,
      optionName: option?.name,
      unitPrice: unit,
      addons: addons
          .map((a) => CartAddon(id: a.id, name: a.name, price: a.price))
          .toList(),
      location: location,
      slot: slot,
      notes: normalizedNotes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BookingDraft &&
      other.service?.id == service?.id &&
      other.option?.id == option?.id &&
      _sameAddonIds(other.addons, addons) &&
      other.location == location &&
      other.slot?.id == slot?.id &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
        service?.id,
        option?.id,
        Object.hashAll(addons.map((a) => a.id)),
        location,
        slot?.id,
        notes,
      );

  static bool _sameAddonIds(List<ServiceAddon> a, List<ServiceAddon> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

final _rng = Random();

/// A small, collision-resistant line id so each configured booking is its own
/// cart line. Mirrors RN's `makeLineId` (timestamp + short random suffix).
String _makeLineId(String serviceId) {
  final rand = _rng.nextInt(1 << 32).toRadixString(36);
  return '${serviceId}__${DateTime.now().millisecondsSinceEpoch}__$rand';
}

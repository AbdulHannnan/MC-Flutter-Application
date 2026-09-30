// lib/src/models/cart.dart — the user's selection / cart line. Dart port of the
// RN app's `src/types/cart.ts`.
//
// A [CartItem] is one line in the cart: a FULLY CONFIGURED booking — the service
// (optionally a specific sub-service), the chosen add-ons, WHERE it happens
// (location) and WHEN (slot), plus notes. This is CLIENT STATE THE APP OWNS: it
// lives in the cart store and is persisted across restarts (Module 13), so it
// carries full `toJson`/`fromJson`.
//
// SNAPSHOT vs REFERENCE: each line keeps the ids (source of truth for what was
// picked) AND a small snapshot of display fields (names, unit price) so the cart
// renders instantly and offline. A pre-checkout re-validation (Module 13)
// reconciles the price against the live catalog before payment, so a stale
// snapshot can never become a wrong charge.

import 'common.dart';
import 'location.dart';
import 'money.dart';
import 'time_slot.dart';

/// A selected add-on, snapshotted onto the cart line (id + display name + price).
class CartAddon {
  final Id id;
  final String name;
  final Money price;

  const CartAddon({required this.id, required this.name, required this.price});

  factory CartAddon.fromJson(Map<String, dynamic> json) => CartAddon(
        id: json['id'] as String,
        name: json['name'] as String,
        price: Money.fromJson(json['price'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is CartAddon &&
      other.id == id &&
      other.name == name &&
      other.price == price;

  @override
  int get hashCode => Object.hash(id, name, price);
}

class CartItem {
  /// Stable, UNIQUE line id — each configured booking is its own line, so this
  /// is generated per add, not derived from the selection.
  final Id id;

  /// What was picked.
  final Id serviceId;

  /// Which sub-service, when the service has options.
  final Id? optionId;

  /// How many of this line.
  final int quantity;

  // ── Display snapshot ──
  final String serviceName;
  final String? optionName;

  /// Base price per unit (the option's or the service's) at add time. Add-on
  /// prices are held separately in [addons].
  final Money unitPrice;

  // ── The rest of the configured booking ──
  /// Chosen extras (each adds its price to the line total).
  final List<CartAddon> addons;

  /// Where the visit happens.
  final BookingLocation? location;

  /// When the visit happens.
  final TimeSlot? slot;

  /// Free-text instructions for the provider.
  final String? notes;

  const CartItem({
    required this.id,
    required this.serviceId,
    required this.quantity,
    required this.serviceName,
    required this.unitPrice,
    this.optionId,
    this.optionName,
    this.addons = const [],
    this.location,
    this.slot,
    this.notes,
  });

  /// The per-unit price INCLUDING the selected add-ons: base unit price + every
  /// add-on's price (same currency). The price of one of this line. Mirrors the
  /// RN cart's `selectLineUnitPrice` and matches [BookingDraft.subtotal].
  Money get lineUnitPrice =>
      addons.fold<Money>(unitPrice, (sum, a) => sum + a.price);

  /// The line total: the add-on-inclusive unit price × quantity. What this line
  /// contributes to the cart subtotal. Mirrors RN `selectLineTotal`.
  Money get lineTotal => lineUnitPrice * quantity;

  CartItem copyWith({
    int? quantity,
    List<CartAddon>? addons,
    BookingLocation? location,
    TimeSlot? slot,
    String? notes,
  }) =>
      CartItem(
        id: id,
        serviceId: serviceId,
        optionId: optionId,
        quantity: quantity ?? this.quantity,
        serviceName: serviceName,
        optionName: optionName,
        unitPrice: unitPrice,
        addons: addons ?? this.addons,
        location: location ?? this.location,
        slot: slot ?? this.slot,
        notes: notes ?? this.notes,
      );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        optionId: json['optionId'] as String?,
        quantity: (json['quantity'] as num).toInt(),
        serviceName: json['serviceName'] as String,
        optionName: json['optionName'] as String?,
        unitPrice: Money.fromJson(json['unitPrice'] as Map<String, dynamic>),
        addons: (json['addons'] as List<dynamic>? ?? [])
            .map((e) => CartAddon.fromJson(e as Map<String, dynamic>))
            .toList(),
        location: json['location'] == null
            ? null
            : BookingLocation.fromJson(json['location'] as Map<String, dynamic>),
        slot: json['slot'] == null
            ? null
            : TimeSlot.fromJson(json['slot'] as Map<String, dynamic>),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        if (optionId != null) 'optionId': optionId,
        'quantity': quantity,
        'serviceName': serviceName,
        if (optionName != null) 'optionName': optionName,
        'unitPrice': unitPrice.toJson(),
        'addons': addons.map((a) => a.toJson()).toList(),
        if (location != null) 'location': location!.toJson(),
        if (slot != null) 'slot': slot!.toJson(),
        if (notes != null) 'notes': notes,
      };
}

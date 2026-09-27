// lib/src/models/booking.dart — the confirmed booking record. Dart port of the
// RN app's `Booking` / `BookingStatus` (src/types/booking.ts).
//
// The RN file models TWO shapes: a BookingDraft (client state the user assembles)
// and a Booking (the confirmed, persisted record). Only [Booking] belongs to this
// module (README Module 4); the in-progress DRAFT is client state that lives in
// the booking store and lands with the booking flow (later modules). Modelling
// them apart keeps "is the slot maybe null?" ambiguity out of screens that show a
// finalized booking.
//
// In this rebuild, order history is LOCAL storage (README §MOCK), so [Booking]
// carries full `toJson`/`fromJson` for persistence.

import 'cart.dart';
import 'common.dart';
import 'location.dart';
import 'money.dart';
import 'time_slot.dart';

/// Lifecycle of a confirmed booking.
enum BookingStatus {
  pending, // created, awaiting payment confirmation
  confirmed, // paid and scheduled
  completed, // service delivered
  cancelled; // called off by user or provider

  /// Parse a status string, defaulting to [pending] for anything unrecognised.
  static BookingStatus fromName(String value) => BookingStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => BookingStatus.pending,
      );
}

/// The finalized, locally-persisted booking (the receipt's backing record).
class Booking {
  final Id id;

  /// Human-friendly code shown to the user, e.g. "MC-2K4F9".
  final String reference;

  /// The (local mock) auth user id this booking belongs to.
  final Id userId;
  final BookingStatus status;
  final List<CartItem> items;
  final TimeSlot slot;

  /// Where the visit happens.
  final BookingLocation? location;

  /// Sum of line prices before any fees/taxes.
  final Money subtotal;

  /// Final amount charged.
  final Money total;
  final String? notes;

  /// ISO-8601 creation timestamp.
  final String createdAt;

  /// Links to the Payment that settled it (payments arrive in Module 14).
  final Id? paymentId;

  const Booking({
    required this.id,
    required this.reference,
    required this.userId,
    required this.status,
    required this.items,
    required this.slot,
    required this.subtotal,
    required this.total,
    required this.createdAt,
    this.location,
    this.notes,
    this.paymentId,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        reference: json['reference'] as String,
        userId: json['userId'] as String,
        status: BookingStatus.fromName(json['status'] as String),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        slot: TimeSlot.fromJson(json['slot'] as Map<String, dynamic>),
        location: json['location'] == null
            ? null
            : BookingLocation.fromJson(json['location'] as Map<String, dynamic>),
        subtotal: Money.fromJson(json['subtotal'] as Map<String, dynamic>),
        total: Money.fromJson(json['total'] as Map<String, dynamic>),
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as String,
        paymentId: json['paymentId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'userId': userId,
        'status': status.name,
        'items': items.map((i) => i.toJson()).toList(),
        'slot': slot.toJson(),
        if (location != null) 'location': location!.toJson(),
        'subtotal': subtotal.toJson(),
        'total': total.toJson(),
        if (notes != null) 'notes': notes,
        'createdAt': createdAt,
        if (paymentId != null) 'paymentId': paymentId,
      };
}

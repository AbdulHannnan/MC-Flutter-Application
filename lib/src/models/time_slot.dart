// lib/src/models/time_slot.dart — a bookable time window. Dart port of the RN
// app's `TimeSlot` (src/types/availability.ts).
//
// In this app the day's slots are GENERATED CLIENT-SIDE (hourly 09:00–16:00,
// Dubai wall-clock — Module 12), not fetched: there is no availability endpoint.
// The only slot the app keeps in its own state is the ONE the user selects, which
// rides along on the booking draft and is snapshotted onto the cart line.
//
// Dates/times are ISO-8601 strings (not `DateTime`), matching the RN model — they
// serialise cleanly into storage and are parsed to `DateTime` only at the edge
// where they are formatted or compared.

import 'common.dart';

class TimeSlot {
  final Id id;

  /// Slot start as an ISO-8601 string, e.g. "2026-09-01T14:00:00.000Z".
  final String start;

  /// Slot end as an ISO-8601 string.
  final String end;

  /// False when already taken — shown disabled rather than hidden.
  final bool isAvailable;

  const TimeSlot({
    required this.id,
    required this.start,
    required this.end,
    this.isAvailable = true,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        id: json['id'] as String,
        start: json['start'] as String,
        end: json['end'] as String,
        isAvailable: json['isAvailable'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'isAvailable': isAvailable,
      };

  @override
  bool operator ==(Object other) =>
      other is TimeSlot &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.isAvailable == isAvailable;

  @override
  int get hashCode => Object.hash(id, start, end, isAvailable);
}

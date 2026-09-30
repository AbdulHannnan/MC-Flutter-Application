// lib/src/features/booking/availability_repository.dart — the availability data
// source. Dart port of the RN app's `src/features/booking/availabilityApi.ts`.
//
// IMPORTANT REALITY (README §Schedule): there is NO availability/scheduling API on
// the backend, and there isn't meant to be. Time slots are FIXED, generated on the
// frontend; the backend neither supplies nor validates them. So this is not a "mock
// waiting to be swapped for api.get" like the catalog was — it is the app's OWN
// client-side slot source, hourly 09:00–16:00 in Dubai wall-clock.
//
// WHAT A BOOKING STORES: the backend keeps `scheduledDate` (ISO datetime) and
// `scheduledTime` (a free-text label like "10:00 AM"), derived from the chosen slot
// at booking-write time (Module 14). So the slot hours here must match the web app's
// fixed slots so both channels produce the same labels.
//
// AVAILABILITY LOGIC: the real system marks nothing as taken — every FUTURE slot is
// bookable (only past times on today are disabled). We reproduce exactly that. In
// mock/demo mode (CATALOG_MODE=mock) we additionally grey out a deterministic slice
// so the picker's disabled state is visible while developing.
//
// THE SEAM: screens never touch this directly — they read [daySlotsProvider]
// (availability_providers.dart), which drops into the shared QueryBoundary for
// loading / error / empty, exactly like the catalog providers.

import '../../config/app_config.dart';
import '../../core/format/date_time.dart';
import '../../models/models.dart';

/// Slot window — hourly starts from 09:00 to 16:00 (the last ends at 17:00). These
/// MUST match the web app's fixed slot buttons so both channels send the same
/// `scheduledTime` labels.
const int kFirstStartHour = 9; // 09:00 is the earliest slot start
const int kLastStartHour = 16; // 16:00 is the latest (ends 17:00)
const int kSlotMinutes = 60;

/// A short cosmetic delay so the picker's loading state is visible; availability is
/// local and instant. Mirrors the RN `MOCK_LATENCY_MS`.
const Duration kAvailabilityLatency = Duration(milliseconds: 250);

class AvailabilityRepository {
  /// The cosmetic latency to simulate (overridable to [Duration.zero] in tests).
  final Duration latency;

  /// Whether demo "taken" slots are greyed out (defaults to CATALOG_MODE=mock, like
  /// RN's `isMockCatalog`). The real system has no taken slots; this only makes the
  /// disabled state demonstrable while on seed data.
  final bool demoTaken;

  AvailabilityRepository({
    this.latency = kAvailabilityLatency,
    bool? demoTaken,
  }) : demoTaken = demoTaken ?? config.isMockCatalog;

  /// One calendar day's slots ("YYYY-MM-DD"), in start-time order. Client-side by
  /// design — there is no backend availability endpoint. If one is ever added, this
  /// method is the single seam to swap.
  Future<List<TimeSlot>> getDaySlots(String date) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return buildSlots(date);
  }

  /// Build one day's slots. Times are LOCAL wall-clock instants stored as ISO
  /// strings, so [formatTime] renders them back to the same clock time. A slot is
  /// unavailable only when it is already in the PAST (possible only when the day is
  /// today), or — in demo mode — it falls in a deterministic "taken" slice.
  List<TimeSlot> buildSlots(String date) {
    final parts = date.split('-').map(int.parse).toList();
    final year = parts[0], month = parts[1], day = parts[2];
    final now = DateTime.now();

    final slots = <TimeSlot>[];
    for (var hour = kFirstStartHour; hour <= kLastStartHour; hour++) {
      final start = DateTime(year, month, day, hour);
      final end = start.add(const Duration(minutes: kSlotMinutes));

      final isPast = !start.isAfter(now); // start <= now
      final takenForDemo = demoTaken && (day + hour) % 3 == 0;

      slots.add(TimeSlot(
        id: 'slot_${date}_${hour.toString().padLeft(2, '0')}',
        start: start.toIso8601String(),
        end: end.toIso8601String(),
        isAvailable: !isPast && !takenForDemo,
      ));
    }
    return slots;
  }
}

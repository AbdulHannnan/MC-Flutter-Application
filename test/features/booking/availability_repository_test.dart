// The client-side availability source (Module 12): hourly 09:00–16:00 slots, past
// times disabled, and the demo-only "taken" slice. There is no backend endpoint —
// this generates the fixed slots, so both channels produce the same labels.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/format/date_time.dart';
import 'package:microcare/src/features/booking/availability_repository.dart';

void main() {
  final repo = AvailabilityRepository(latency: Duration.zero, demoTaken: false);

  test('builds 8 hourly slots, 09:00–16:00, in order', () {
    final slots = repo.buildSlots('2030-06-15');
    expect(slots.length, 8);
    expect(slots.first.id, 'slot_2030-06-15_09');
    expect(slots.last.id, 'slot_2030-06-15_16');
    // Start times render back to the wall-clock hours.
    expect(formatTime(slots.first.start), '9:00 AM');
    expect(formatTime(slots.last.start), '4:00 PM');
    // End is one hour after start.
    expect(formatTime(slots.last.end), '5:00 PM');
  });

  test('every future slot is available', () {
    final slots = repo.buildSlots('2030-06-15');
    expect(slots.every((s) => s.isAvailable), isTrue);
  });

  test('a fully past day has no available slots', () {
    final slots = repo.buildSlots('2020-01-01');
    expect(slots.any((s) => s.isAvailable), isFalse);
  });

  test('demo mode greys out the deterministic (day+hour)%3==0 slice', () {
    final demo = AvailabilityRepository(latency: Duration.zero, demoTaken: true);
    final byHour = {
      for (final s in demo.buildSlots('2030-06-15'))
        int.parse(s.id.split('_').last): s.isAvailable,
    };
    // day 15: 15+9, 15+12, 15+15 are divisible by 3 → taken.
    expect(byHour[9], isFalse);
    expect(byHour[12], isFalse);
    expect(byHour[15], isFalse);
    // 15+10 = 25 → available.
    expect(byHour[10], isTrue);
  });

  test('getDaySlots awaits and returns the built slots', () async {
    final slots = await repo.getDaySlots('2030-06-15');
    expect(slots.map((s) => s.id), repo.buildSlots('2030-06-15').map((s) => s.id));
  });
}

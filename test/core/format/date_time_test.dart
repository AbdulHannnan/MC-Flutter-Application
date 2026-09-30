// Date/time formatters (Module 12): hand-rolled ports of RN's formatFullDate,
// formatTime, toLocalIsoDate + the calendar's month label. Time values use
// zone-less ISO strings so the local-time assertions hold on any machine.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/format/date_time.dart';

void main() {
  group('formatFullDate', () {
    test('weekday, month, day — parsed in local time', () {
      expect(formatFullDate('2026-09-01'), 'Tuesday, September 1');
      expect(formatFullDate('2026-01-01'), 'Thursday, January 1');
    });
  });

  group('formatMonthLabel', () {
    test('month name + year', () {
      expect(formatMonthLabel(DateTime(2026, 9, 15)), 'September 2026');
      expect(formatMonthLabel(DateTime(2026, 1, 1)), 'January 2026');
    });
  });

  group('formatTime', () {
    test('12-hour clock with AM/PM and 2-digit minutes', () {
      expect(formatTime('2026-09-01T09:00:00.000'), '9:00 AM');
      expect(formatTime('2026-09-01T14:00:00.000'), '2:00 PM');
      expect(formatTime('2026-09-01T13:30:00.000'), '1:30 PM');
    });

    test('midnight and noon read as 12', () {
      expect(formatTime('2026-09-01T00:05:00.000'), '12:05 AM');
      expect(formatTime('2026-09-01T12:00:00.000'), '12:00 PM');
    });
  });

  group('toLocalIsoDate / isoDateToString', () {
    test('the local calendar day of an instant', () {
      expect(toLocalIsoDate('2026-09-01T09:00:00.000'), '2026-09-01');
      // An evening slot still lands on its own day.
      expect(toLocalIsoDate('2026-09-01T23:30:00.000'), '2026-09-01');
    });

    test('isoDateToString pads to YYYY-MM-DD', () {
      expect(isoDateToString(DateTime(2026, 9, 1)), '2026-09-01');
      expect(isoDateToString(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}

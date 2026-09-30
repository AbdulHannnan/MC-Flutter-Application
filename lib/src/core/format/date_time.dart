// lib/src/core/format/date_time.dart — calendar-date & clock-time formatters.
// Hand-rolled Dart ports of the RN app's `formatFullDate`, `formatTime` and
// `toLocalIsoDate` (src/utils/index.ts), plus the calendar's month label.
//
// RN used `Intl.DateTimeFormat('en-US', …)`; Flutter has no Intl built in and the
// project is deliberately dependency-light (every formatter so far — formatDuration,
// Money.format — was hand-ported), so we spell the en-US weekday/month tables out
// here. Small, pure, and unit-testable.
//
// TIMEZONE: like RN, everything works in the device's LOCAL wall-clock. A day is a
// plain "YYYY-MM-DD" string; a slot instant is an ISO datetime. We build the local
// [DateTime] ourselves from the parts (never `DateTime.parse('2026-09-01')`, which
// is UTC midnight and can shift the weekday across the date line).

const List<String> _weekdaysLong = [
  'Monday', // DateTime.weekday == 1
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday', // == 7
];

const List<String> _monthsLong = [
  'January', // month == 1
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A full, human-readable date from a "YYYY-MM-DD" string, e.g. "Monday,
/// September 1". Parsed in LOCAL time so the weekday never shifts across the date
/// line. Mirrors RN `formatFullDate`.
String formatFullDate(String isoDate) {
  final parts = isoDate.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1], parts[2]);
  return '${_weekdaysLong[date.weekday - 1]}, '
      '${_monthsLong[date.month - 1]} ${date.day}';
}

/// The calendar header label from any day in a month, e.g. "September 2026".
/// Mirrors the RN Calendar's `Intl.DateTimeFormat({ month: 'long', year: 'numeric' })`.
String formatMonthLabel(DateTime month) =>
    '${_monthsLong[month.month - 1]} ${month.year}';

/// The clock time from an ISO datetime, e.g. "2026-09-01T14:00:00.000" -> "2:00 PM".
/// Rendered in the device's LOCAL timezone — the same wall-clock the user picked.
/// Mirrors RN `formatTime`. Used on the time-slot chips and the booking summary.
String formatTime(String isoDateTime) {
  final dt = DateTime.parse(isoDateTime).toLocal();
  final period = dt.hour < 12 ? 'AM' : 'PM';
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// The LOCAL calendar date ("YYYY-MM-DD") of an ISO datetime — the inverse of
/// [formatTime]: given a slot's `start`, which day does it fall on for the user?
/// Computed in local time (not a UTC `.slice(0,10)`) so an evening slot never lands
/// on the wrong day. Mirrors RN `toLocalIsoDate`; used to restore the calendar to a
/// draft's chosen day.
String toLocalIsoDate(String isoDateTime) => isoDateToString(
      DateTime.parse(isoDateTime).toLocal(),
    );

/// A [DateTime] rendered as a local "YYYY-MM-DD" string (no UTC shift). The shared
/// helper the calendar grid and [toLocalIsoDate] both build day strings with.
String isoDateToString(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

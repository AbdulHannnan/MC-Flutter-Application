// lib/src/core/format/duration.dart — human-readable durations. Dart port of the
// RN app's `formatDuration` (src/utils).
//
// Whole minutes → a short label: "45 min", "1 hr", "1 hr 30 min". Used on service
// cards and summaries. A 0 (the live backend supplies no durations) is hidden by
// the caller, not formatted here.

String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

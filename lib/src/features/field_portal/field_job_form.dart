// lib/src/features/field_portal/field_job_form.dart — the Field Job Portal form's
// pure value types + the live "Generated Job Number" builder.
//
// TEMPORARY FEATURE (see FIELD_PORTAL_REMOVAL.md). Deliberately self-contained:
// everything the field portal needs lives under this one folder. No network, no
// providers here — just the enums the dropdowns use and the pure number builder, so
// the format has ONE source of truth on the client and is unit-testable. The server
// recomputes the same value on submit (never trusting this), so the two must agree.

/// The month dropdown options (January–December). [number] is 1–12; [twoDigit] is
/// the zero-padded form used in the generated number.
enum FieldMonth {
  january,
  february,
  march,
  april,
  may,
  june,
  july,
  august,
  september,
  october,
  november,
  december;

  /// 1-based month number (January = 1).
  int get number => index + 1;

  /// Zero-padded two-digit month, e.g. "01", "11".
  String get twoDigit => number.toString().padLeft(2, '0');

  /// Capitalised display label, e.g. "November".
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

/// The team dropdown options (Team A–E).
enum FieldTeam {
  a,
  b,
  c,
  d,
  e;

  /// Uppercase team letter, e.g. "B".
  String get letter => name.toUpperCase();

  /// Display label, e.g. "Team B".
  String get label => 'Team $letter';
}

/// Build the live "Generated Job Number" — `MC-<MM>-<Team letter>-<3-digit seq>`,
/// e.g. `MC-11-B-005`. Any missing part shows a placeholder so the preview updates
/// live as the three fields are filled; once all are present this exactly matches
/// the server-recomputed `generated_number`.
String buildGeneratedJobNumber({
  FieldMonth? month,
  FieldTeam? team,
  int? sequence,
}) {
  final mm = month?.twoDigit ?? '--';
  final t = team?.letter ?? '-';
  final seq = (sequence != null && sequence > 0)
      ? sequence.toString().padLeft(3, '0')
      : '---';
  return 'MC-$mm-$t-$seq';
}

/// Whether all three parts that make up the generated number are present (the
/// minimum for a complete number; photos are optional). Technician name is checked
/// by the screen separately.
bool isGeneratedNumberComplete({
  FieldMonth? month,
  FieldTeam? team,
  int? sequence,
}) =>
    month != null && team != null && sequence != null && sequence > 0;

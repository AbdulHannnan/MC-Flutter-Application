// lib/src/core/theme/spacing.dart — the SPACING layer. Dart port of the RN app's
// `src/constants/spacing.ts`.
//
// One 4px-based scale drives ALL gaps in the app (padding, margin, list gaps),
// so the whole UI shares a rhythm and nothing is ever "3px off". The small,
// memorable set of steps is a feature: it forces consistency. Reaching for a
// value not on the scale usually means the layout needs rethinking, not the scale.

abstract final class AppSpacing {
  static const double none = 0;
  static const double xs = 4; // hairline gaps: icon↔text, tight insets
  static const double sm = 8; // between closely-related items
  static const double md = 16; // default padding inside cards/screens
  static const double lg = 24; // section spacing, comfortable screen padding
  static const double xl = 32; // large separation between major blocks
  static const double xxl = 48; // hero spacing, empty-state breathing room

  /// The raw unit, for the rare computed multiple (e.g. `unit * 5`).
  static const double unit = 4;
}

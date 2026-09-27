// lib/src/core/theme/radii.dart — the CORNER RADIUS layer. Dart port of the RN
// app's `src/constants/radii.ts`.
//
// Pinning radii to a scale keeps buttons, cards, inputs and images feeling like
// one family. Exposed both as raw doubles (for `Radius.circular`) and as ready
// `BorderRadius` values for the common all-corners case.

import 'package:flutter/widgets.dart';

abstract final class AppRadii {
  static const double none = 0;
  static const double sm = 6; // inputs, small chips, subtle rounding
  static const double md = 10; // buttons, cards — the default
  static const double lg = 16; // large cards, bottom sheets, modals
  static const double xl = 24; // prominent hero surfaces
  static const double pill = 999; // fully-rounded: pills, tags, avatars

  // All-corners BorderRadius shortcuts for the values above.
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

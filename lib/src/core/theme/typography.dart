// lib/src/core/theme/typography.dart — the TYPE layer. Dart port of the RN app's
// `src/constants/typography.ts`.
//
// Split into primitive scales (SIZE, WEIGHT, LINE HEIGHT) and ready-made TEXT
// VARIANTS that combine them into named roles (h1…caption). The `AppText` widget
// takes a variant so screens never re-specify font sizes by hand.
//
// LINE HEIGHT: RN expresses it in absolute px; Flutter's `TextStyle.height` is a
// MULTIPLE of the font size. Each variant below therefore carries `height =
// lineHeightPx / fontSize`, written as that division so the RN source value is
// still visible. Variants are colour-AGNOSTIC — colour is applied by `AppText`
// (or an ambient `DefaultTextStyle`), matching how RN keeps size/weight separate
// from the semantic colour token.

import 'package:flutter/widgets.dart';

/// The font-size ramp (logical pixels), matching RN `TYPOGRAPHY`.
abstract final class AppFontSizes {
  static const double caption = 13; // fine print, metadata, timestamps
  static const double body = 16; // default paragraph / control text
  static const double subheading = 18; // emphasised body, list titles
  static const double heading = 20; // section headings (h3)
  static const double title = 28; // screen titles (h2)
  static const double display = 34; // hero numbers, onboarding (h1)
}

/// Font weights, matching RN `FONT_WEIGHTS` (400/500/600/700).
abstract final class AppFontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

/// Composed, drop-in text styles — one per semantic role. This is the surface
/// most feature code uses (through the `AppText` widget). Colour is intentionally
/// unset here.
abstract final class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: AppFontSizes.display,
    height: 40 / AppFontSizes.display,
    fontWeight: AppFontWeights.bold,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: AppFontSizes.title,
    height: 34 / AppFontSizes.title,
    fontWeight: AppFontWeights.bold,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: AppFontSizes.heading,
    height: 28 / AppFontSizes.heading,
    fontWeight: AppFontWeights.semibold,
  );
  static const TextStyle subheading = TextStyle(
    fontSize: AppFontSizes.subheading,
    height: 26 / AppFontSizes.subheading,
    fontWeight: AppFontWeights.semibold,
  );
  static const TextStyle body = TextStyle(
    fontSize: AppFontSizes.body,
    height: 24 / AppFontSizes.body,
    fontWeight: AppFontWeights.regular,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontSize: AppFontSizes.body,
    height: 24 / AppFontSizes.body,
    fontWeight: AppFontWeights.semibold,
  );
  static const TextStyle caption = TextStyle(
    fontSize: AppFontSizes.caption,
    height: 18 / AppFontSizes.caption,
    fontWeight: AppFontWeights.regular,
  );
}

/// Every type-ramp role — the enum the `AppText` widget's `variant` accepts.
enum AppTextVariant { h1, h2, h3, subheading, body, bodyStrong, caption }

extension AppTextVariantStyle on AppTextVariant {
  /// The [TextStyle] (colour-agnostic) for this variant.
  TextStyle get style => switch (this) {
        AppTextVariant.h1 => AppTextStyles.h1,
        AppTextVariant.h2 => AppTextStyles.h2,
        AppTextVariant.h3 => AppTextStyles.h3,
        AppTextVariant.subheading => AppTextStyles.subheading,
        AppTextVariant.body => AppTextStyles.body,
        AppTextVariant.bodyStrong => AppTextStyles.bodyStrong,
        AppTextVariant.caption => AppTextStyles.caption,
      };
}

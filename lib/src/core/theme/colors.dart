// lib/src/core/theme/colors.dart — the COLOR layer of the design system. Dart
// port of the RN app's `src/constants/colors.ts`.
//
// TWO LAYERS OF COLOR:
//   1. PRIMITIVES ([AppPalette]) — the raw named swatches (blue600, gray100…).
//      They describe WHAT a colour is, never WHERE it's used. Widgets should
//      almost never touch these directly.
//   2. SEMANTIC TOKENS ([AppColors]) — roles in the UI (background, text,
//      primary, border, danger). They describe INTENT, each pointing at a
//      primitive. Widgets use ONLY these.
//
// Repoint one semantic token and the whole app follows — no hunting for hex codes.
// The RN app has no dark mode ("a future ThemeProvider…"), so these are a single
// light set; a dark scheme would add a parallel token set later.

import 'package:flutter/material.dart';

/// Raw named swatches (primitives). Each scale runs light (50) → dark (900).
abstract final class AppPalette {
  // Brand blue — primary actions, links, focus.
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB); // historical primary — brand anchor
  static const blue700 = Color(0xFF1D4ED8);

  // Neutral grays — text, surfaces, borders.
  static const white = Color(0xFFFFFFFF);
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray700 = Color(0xFF374151);
  static const gray900 = Color(0xFF111827);
  static const black = Color(0xFF000000);

  // Status colours — one mid + one tint each.
  static const green50 = Color(0xFFECFDF5);
  static const green600 = Color(0xFF059669);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber500 = Color(0xFFF59E0B);
  static const red50 = Color(0xFFFEF2F2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
}

/// Semantic tokens — the surface widgets import. Every colour should resolve to
/// one of these. Names mirror the RN `COLORS` map exactly.
abstract final class AppColors {
  // Surfaces — back-most to front-most.
  static const background = AppPalette.white; // app background
  static const surface = AppPalette.white; // cards, sheets, inputs
  static const surfaceAlt = AppPalette.gray50; // raised/zebra areas, sections

  // Text — by emphasis.
  static const text = AppPalette.gray900; // primary body & headings
  static const muted = AppPalette.gray500; // secondary/supporting text
  static const textMuted = AppPalette.gray500;
  static const textSubtle = AppPalette.gray400; // hints, placeholders, disabled
  static const textInverse = AppPalette.white; // text on a coloured/dark surface

  // Primary brand action.
  static const primary = AppPalette.blue600;
  static const primaryHover = AppPalette.blue700; // pressed/active
  static const primarySoft = AppPalette.blue50; // tinted selected/primary chips
  static const primaryText = AppPalette.white; // text/icon ON a primary surface

  // Lines & separators.
  static const border = AppPalette.gray200;
  static const borderStrong = AppPalette.gray300;

  // Status — each pairs a strong colour with a soft tint for backgrounds.
  static const success = AppPalette.green600;
  static const successSoft = AppPalette.green50;
  static const warning = AppPalette.amber500;
  static const warningSoft = AppPalette.amber50;
  static const danger = AppPalette.red600;
  static const dangerSoft = AppPalette.red50;

  // Utility.
  static const overlay = Color(0x80111827); // gray900 @ ~50% — behind modals
  static const transparent = Color(0x00000000);
}

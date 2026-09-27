// lib/src/core/theme/app_theme.dart — the composed Flutter ThemeData.
//
// Analog of the RN app's `src/constants/theme.ts`, but wired the idiomatic
// Flutter way: the design tokens (colours, type ramp) are mapped onto a Material
// `ThemeData` so stock Material widgets (AppBar, Scaffold, dialogs, default Text)
// pick up the brand automatically. Our own primitives (`AppButton`, `AppCard`,
// `AppText`, chips, pills) read the tokens directly for pixel-faithful control.
//
// The RN app is light-only ("a future ThemeProvider when we add dark mode"), so
// there is a single light theme here; a dark theme would map a parallel token set.

import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

abstract final class AppTheme {
  /// The single light theme the app runs on.
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryText,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.primaryText,
      outline: AppColors.border,
    );

    // Map the type ramp onto Material's text slots (with the primary text colour)
    // so default Text and Material widgets are on-brand.
    const textColor = TextStyle(color: AppColors.text);
    final textTheme = TextTheme(
      displayMedium: AppTextStyles.h1.merge(textColor),
      headlineMedium: AppTextStyles.h2.merge(textColor),
      titleLarge: AppTextStyles.h3.merge(textColor),
      titleMedium: AppTextStyles.subheading.merge(textColor),
      bodyLarge: AppTextStyles.body.merge(textColor),
      bodyMedium: AppTextStyles.body.merge(textColor),
      bodySmall: AppTextStyles.caption.merge(textColor),
      labelLarge: AppTextStyles.bodyStrong.merge(textColor),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      dividerColor: AppColors.border,
      iconTheme: const IconThemeData(color: AppColors.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}

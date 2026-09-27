// lib/src/core/widgets/app_text.dart — the typographic primitive. Dart port of
// the RN app's `src/components/Text.tsx`.
//
// Every piece of text should render through AppText instead of a raw `Text`,
// because it bakes the design system in:
//   - `variant` picks a role from the type ramp (h1…caption) — one value sets
//     size + weight + line-height together.
//   - `color` picks a semantic text-colour token (no stray hex).
//   - `style` stays open for one-off tweaks, merged last so it wins.

import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Semantic text colours, mirroring the RN `TextColor` set.
enum AppTextColor { normal, muted, subtle, primary, inverse, success, danger }

extension _AppTextColorValue on AppTextColor {
  Color get color => switch (this) {
        AppTextColor.normal => AppColors.text,
        AppTextColor.muted => AppColors.muted,
        AppTextColor.subtle => AppColors.textSubtle,
        AppTextColor.primary => AppColors.primary,
        AppTextColor.inverse => AppColors.textInverse,
        AppTextColor.success => AppColors.success,
        AppTextColor.danger => AppColors.danger,
      };
}

class AppText extends StatelessWidget {
  final String data;

  /// Type-ramp role: sets size + weight + line-height. Defaults to [AppTextVariant.body].
  final AppTextVariant variant;

  /// Semantic text colour. Defaults to [AppTextColor.normal] (primary foreground).
  final AppTextColor color;

  /// Extra style overrides, merged last so they win over the variant/colour.
  final TextStyle? style;

  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppText(
    this.data, {
    super.key,
    this.variant = AppTextVariant.body,
    this.color = AppTextColor.normal,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = variant.style.copyWith(color: color.color).merge(style);
    return Text(
      data,
      style: resolved,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
    );
  }
}

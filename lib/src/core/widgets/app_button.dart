// lib/src/core/widgets/app_button.dart — the pressable action primitive. Dart
// port of the RN app's `src/components/Button.tsx`.
//
// One button covering the app's actions, with the same knobs as RN:
//   - variant  : primary | secondary | outline | ghost | danger  (look/intent)
//   - size     : sm | md | lg                                     (padding/text)
//   - loading  : shows a spinner and blocks presses
//   - onPressed : null disables the button (dimmed, non-interactive)
//   - fullWidth : stretch to the container width
//
// The pressed look mirrors RN's `active:` styles by swapping the background on
// tap-down (no Material ripple), so the feel matches the prototype.

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Resolved colours for a variant (container, pressed container, border, label,
/// spinner) — mirrors the three RN lookup maps.
class _VariantColors {
  final Color background;
  final Color pressed;
  final Color border;
  final Color label;
  const _VariantColors({
    required this.background,
    required this.pressed,
    required this.border,
    required this.label,
  });
}

const Map<AppButtonVariant, _VariantColors> _variantColors = {
  AppButtonVariant.primary: _VariantColors(
    background: AppColors.primary,
    pressed: AppColors.primaryHover,
    border: AppColors.primary,
    label: AppColors.primaryText,
  ),
  AppButtonVariant.secondary: _VariantColors(
    background: AppColors.surfaceAlt,
    pressed: AppColors.border,
    border: AppColors.border,
    label: AppColors.text,
  ),
  AppButtonVariant.outline: _VariantColors(
    background: AppColors.transparent,
    pressed: AppColors.surfaceAlt,
    border: AppColors.borderStrong,
    label: AppColors.text,
  ),
  AppButtonVariant.ghost: _VariantColors(
    background: AppColors.transparent,
    pressed: AppColors.surfaceAlt,
    border: AppColors.transparent,
    label: AppColors.primary,
  ),
  AppButtonVariant.danger: _VariantColors(
    background: AppColors.danger,
    // RN uses active:opacity-90 on the red fill; ~90% alpha over the white
    // surface reads the same.
    pressed: Color(0xE5DC2626),
    border: AppColors.danger,
    label: AppColors.primaryText,
  ),
};

class _SizeSpec {
  final double paddingX;
  final double paddingY;
  final double minHeight;
  final AppTextVariant labelVariant;
  const _SizeSpec(this.paddingX, this.paddingY, this.minHeight, this.labelVariant);
}

const Map<AppButtonSize, _SizeSpec> _sizeSpecs = {
  AppButtonSize.sm: _SizeSpec(AppSpacing.md, AppSpacing.xs, 36, AppTextVariant.caption),
  AppButtonSize.md: _SizeSpec(AppSpacing.lg, AppSpacing.sm, 44, AppTextVariant.body),
  AppButtonSize.lg: _SizeSpec(AppSpacing.xl, AppSpacing.md, 52, AppTextVariant.subheading),
};

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.loading = false,
    this.fullWidth = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Loading implies non-interactive, as in RN.
    final bool isDisabled = widget.onPressed == null || widget.loading;
    final colors = _variantColors[widget.variant]!;
    final spec = _sizeSpecs[widget.size]!;

    final background = _pressed && !isDisabled ? colors.pressed : colors.background;

    final Widget content = widget.loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.label),
          )
        : Text(
            widget.label,
            style: spec.labelVariant.style.copyWith(
              color: colors.label,
              fontWeight: AppFontWeights.semibold,
            ),
          );

    final button = Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTap: isDisabled ? null : widget.onPressed,
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
        child: Container(
          constraints: BoxConstraints(minHeight: spec.minHeight),
          padding: EdgeInsets.symmetric(
            horizontal: spec.paddingX,
            vertical: spec.paddingY,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    final sized = widget.fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;

    // Dim (not remove) when disabled, matching RN's opacity-50.
    return Opacity(opacity: isDisabled ? 0.5 : 1, child: sized);
  }
}

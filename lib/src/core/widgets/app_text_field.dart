// lib/src/core/widgets/app_text_field.dart — the labelled text input primitive.
// The Flutter analog of the RN app's shared `Input` component (`@/components`).
//
// A vertical stack: an optional label, the field itself, and an optional error
// message below it (which also recolours the border). Presentational only — it
// owns no value; the parent passes `controller`/`onChanged` and an `errorText`.
// Built on the Module 5 tokens so every form field across auth, booking and
// checkout looks the same.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_text.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Error message shown below the field; also recolours the border. Null = valid.
  final String? errorText;

  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;

  /// A trailing widget inside the field, e.g. a show/hide-password toggle.
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.onChanged,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled = true,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final borderColor = hasError ? AppColors.danger : AppColors.border;
    final focusedBorderColor = hasError ? AppColors.danger : AppColors.primary;

    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          AppText(label!, variant: AppTextVariant.caption),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofocus: autofocus,
          enabled: enabled,
          style: AppTextStyles.body,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            hintText: hintText,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSubtle),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            suffixIcon: suffix,
            enabledBorder: border(borderColor),
            focusedBorder: border(focusedBorderColor, width: 1.5),
            disabledBorder: border(AppColors.border),
            border: border(borderColor),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          AppText(errorText!,
              variant: AppTextVariant.caption, color: AppTextColor.danger),
        ],
      ],
    );
  }
}

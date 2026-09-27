// lib/src/features/auth/widgets/form_error_banner.dart — a top-of-form error
// banner. Dart port of the RN app's `FormError` component.
//
// Shared by the login / signup / reset screens so every auth error (a wrong
// password, a taken email) looks the same. Presentational only: give it a message,
// it shows the banner.

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

class FormErrorBanner extends StatelessWidget {
  final String message;
  const FormErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.danger),
      ),
      child: AppText(message,
          variant: AppTextVariant.caption, color: AppTextColor.danger),
    );
  }
}

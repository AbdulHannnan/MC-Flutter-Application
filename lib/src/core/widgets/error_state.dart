// lib/src/core/widgets/error_state.dart — the "fetch failed" primitive. Dart port
// of the RN app's `ErrorState`.
//
// For an EXPECTED failure — a query that errored — with two looks:
//   • default  → centred heading + description + "Try again" (a screen whose one
//                main fetch failed).
//   • compact  → left-aligned small caption + small button (a failure inside a
//                list/section — the QueryBoundary case).
// Omit [onRetry] to hide the retry button (a non-retriable error).

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_button.dart';
import 'app_text.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final String? description;
  final String retryLabel;

  /// Omit to hide the retry button.
  final VoidCallback? onRetry;

  /// The small, left-aligned, in-list look instead of the centred full state.
  final bool compact;

  const ErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.description,
    this.retryLabel = 'Try again',
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              description ?? '$title. Please try again.',
              variant: AppTextVariant.caption,
              color: AppTextColor.danger,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: retryLabel,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(title, variant: AppTextVariant.h3, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppText(description!,
                  color: AppTextColor.muted, textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: retryLabel,
                variant: AppButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

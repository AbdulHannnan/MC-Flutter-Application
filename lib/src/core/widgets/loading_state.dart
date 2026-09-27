// lib/src/core/widgets/loading_state.dart — the loading primitive. Dart port of
// the RN app's `LoadingState`.
//
// One shape for "we're fetching", written once so every screen looks identical:
//   • default  → fills its parent, centred (a screen's first paint).
//   • compact  → un-stretched, just padding around the spinner (a section inside a
//                list — the QueryBoundary case).
//   • label    → an optional caption under the spinner.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_text.dart';

class LoadingState extends StatelessWidget {
  /// The small, un-stretched, in-list look instead of filling the parent.
  final bool compact;

  /// Optional caption under the spinner (e.g. what's loading).
  final String? label;

  const LoadingState({super.key, this.compact = false, this.label});

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppText(label!, variant: AppTextVariant.caption, color: AppTextColor.muted),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(child: column),
      );
    }
    return Center(child: column);
  }
}

// lib/src/core/widgets/app_card.dart — the surface/container primitive. Dart
// port of the RN app's `src/components/Card.tsx`.
//
// A Card groups related content on a raised surface (a service in a list, a
// booking summary, a receipt row) with the standard look: surface background,
// large radius, default md padding. `elevated` swaps the flat border for a soft
// shadow, for cards that should float above the page.

import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  /// Use a soft drop shadow instead of a flat border (floating cards).
  final bool elevated;

  /// Inner padding. Defaults to `md` (16); pass [EdgeInsets.zero] for edge-to-edge
  /// content such as a cover image (see [CategoryChip]).
  final EdgeInsetsGeometry padding;

  /// Clip content to the rounded corners (needed when a child image bleeds to
  /// the card edge).
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.elevated = false,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgAll,
        border: elevated ? null : Border.all(color: AppColors.border),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x1A000000), // black @ ~10%
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

// lib/src/app/screens/placeholder_screen.dart — a stub for routes whose real
// screen arrives in a later module.
//
// Module 8 registers the FULL route tree so the navigator + guards are complete;
// the screens that don't exist yet render this placeholder. It sits in a Scaffold
// with an AppBar, so the back button (pop) is visibly working. Each later module
// replaces the route's builder with its real screen.

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  /// e.g. "Module 9" — which module fills this route in.
  final String arrivesIn;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.arrivesIn,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48, color: AppColors.muted),
              const SizedBox(height: AppSpacing.md),
              AppText(title, variant: AppTextVariant.h2),
              const SizedBox(height: AppSpacing.xs),
              AppText('Arrives in $arrivesIn.',
                  variant: AppTextVariant.body, color: AppTextColor.muted),
            ],
          ),
        ),
      ),
    );
  }
}

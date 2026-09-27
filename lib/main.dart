// Microcare — Flutter rebuild of the React Native (Expo) customer booking app.
//
// Entry point. Wraps the app in a Riverpod `ProviderScope` so any provider
// (state stores, API layers, catalog cache) is reachable from anywhere in the
// tree — the idiomatic Flutter equivalent of the RN app's zustand stores +
// react-query providers mounted at the root.
//
// Module 5 scope: the design system (colours, type ramp, spacing, radii) is wired
// into the app's `ThemeData` (AppTheme.light) and the boot screen is restyled with
// the new primitives (AppText, AppCard, AppButton, StatusPill) to prove the theme
// and widgets render. Real screens and routing land in later modules.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/config/app_config.dart';
import 'src/core/theme/theme.dart';
import 'src/core/widgets/widgets.dart';
import 'src/models/models.dart';

void main() {
  // Log the resolved config once at startup — a fast way to confirm which
  // API URL and flags this build actually loaded.
  if (kDebugMode) {
    debugPrint('[config] resolved:\n${config.describe()}');
    if (!isApiBaseUrlValid) {
      debugPrint('[config] WARNING: API_BASE_URL is empty. '
          'Pass --dart-define-from-file=config/dev.json');
    }
  }
  runApp(const ProviderScope(child: MicrocareApp()));
}

/// Root application widget. A single `MaterialApp` — the RN app is a
/// stack-based navigator (no tabs, no drawer); the real routing arrives in
/// Module 8. For now it just shows the placeholder home.
class MicrocareApp extends StatelessWidget {
  const MicrocareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microcare',
      debugShowCheckedModeBanner: false,
      // The Module 5 design system, extracted from the RN src/constants/*.
      theme: AppTheme.light,
      home: const _PlaceholderHomeScreen(),
    );
  }
}

/// Temporary landing screen — now a design-system PROOF for Module 5: it renders
/// the new primitives (AppText, AppCard, AppButton, StatusPill) so the theme and
/// widgets are visibly working. Replaced by the real Home / dashboard in Module 9.
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.ac_unit, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              const AppText('Microcare', variant: AppTextVariant.h1),
              const SizedBox(height: AppSpacing.xs),
              const AppText(
                'AC servicing & booking — Dubai',
                variant: AppTextVariant.body,
                color: AppTextColor.muted,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppText('Module 5 ✓  Design system',
                  variant: AppTextVariant.h3),
              const SizedBox(height: AppSpacing.md),

              // Buttons sampler.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton(label: 'Primary', onPressed: () {}),
                  AppButton(
                      label: 'Outline',
                      variant: AppButtonVariant.outline,
                      onPressed: () {}),
                  AppButton(
                      label: 'Ghost',
                      variant: AppButtonVariant.ghost,
                      onPressed: () {}),
                  AppButton(
                      label: 'Danger',
                      variant: AppButtonVariant.danger,
                      onPressed: () {}),
                  const AppButton(label: 'Disabled'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Status pills sampler.
              const Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusPill(status: BookingStatus.pending),
                  StatusPill(status: BookingStatus.confirmed),
                  StatusPill(status: BookingStatus.completed),
                  StatusPill(status: BookingStatus.cancelled),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Loaded config — proof the build read its config (from Module 2).
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Loaded config',
                        variant: AppTextVariant.bodyStrong),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      config.describe(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

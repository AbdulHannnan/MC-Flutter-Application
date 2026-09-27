// Microcare — Flutter rebuild of the React Native (Expo) customer booking app.
//
// Entry point. Wraps the app in a Riverpod `ProviderScope` so any provider
// (state stores, API layers, catalog cache) is reachable from anywhere in the
// tree — the idiomatic Flutter equivalent of the RN app's zustand stores +
// react-query providers mounted at the root.
//
// Module 6 scope: the catalog DATA LAYER — a data source (CatalogRepository, live
// GET /api/services + /api/addons adapters, plus an offline mock seed) and the
// react-query-equivalent Riverpod caching providers. The boot screen now fetches
// the catalog through those providers as a live proof (loading / error / empty /
// data states). Real screens and routing land in later modules.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/config/app_config.dart';
import 'src/core/network/api_exception.dart';
import 'src/core/theme/theme.dart';
import 'src/core/widgets/widgets.dart';
import 'src/features/services/services.dart';

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

/// Temporary landing screen — now a data-layer PROOF for Module 6: it reads the
/// catalog through [servicesProvider] (the react-query-equivalent caching layer)
/// and renders every AsyncValue state, so the data source, adapters and cache are
/// visibly working end-to-end. Replaced by the real Home / dashboard in Module 9.
class _PlaceholderHomeScreen extends ConsumerWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const AppText('Module 6 ✓  Catalog data layer',
                  variant: AppTextVariant.h3),
              const SizedBox(height: AppSpacing.xs),
              AppText(
                config.isMockCatalog
                    ? 'Source: local mock seed (CATALOG_MODE=mock)'
                    : 'Source: live backend — GET /api/services',
                variant: AppTextVariant.caption,
                color: AppTextColor.muted,
              ),
              const SizedBox(height: AppSpacing.md),

              // The live catalog proof — the star of this module.
              _CatalogProofCard(),
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

/// Reads the whole active catalog and renders each AsyncValue state — loading,
/// error (with a working "Try again" that invalidates the cache to refetch),
/// empty, and data (a count plus the first few service names and "from" prices).
class _CatalogProofCard extends ConsumerWidget {
  static const _query = ServiceQuery.all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider(_query));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Catalog', variant: AppTextVariant.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          servicesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  AppText('Loading services…',
                      variant: AppTextVariant.body, color: AppTextColor.muted),
                ],
              ),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _describeError(error),
                  variant: AppTextVariant.body,
                  color: AppTextColor.danger,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  // Invalidate → the provider refetches on the next read (the
                  // Riverpod equivalent of React Query's refetch()).
                  onPressed: () => ref.invalidate(servicesProvider(_query)),
                ),
              ],
            ),
            data: (services) => services.isEmpty
                ? const AppText('No services found.',
                    variant: AppTextVariant.body, color: AppTextColor.muted)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('${services.length} services loaded',
                          variant: AppTextVariant.caption,
                          color: AppTextColor.muted),
                      const SizedBox(height: AppSpacing.sm),
                      for (final s in services.take(6))
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: AppText(s.name, variant: AppTextVariant.body),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppText('from ${s.basePrice.format()}',
                                  variant: AppTextVariant.bodyStrong),
                            ],
                          ),
                        ),
                      if (services.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: AppText('+ ${services.length - 6} more',
                              variant: AppTextVariant.caption,
                              color: AppTextColor.muted),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      if (error.isTimeout) return 'Request timed out. Check the backend is running.';
      if (error.isNetwork) {
        return 'Network error. Is the backend reachable at '
            '${config.apiBaseUrl}?';
      }
      return error.message;
    }
    return 'Could not load the catalog: $error';
  }
}

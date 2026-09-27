// Microcare — Flutter rebuild of the React Native (Expo) customer booking app.
//
// Entry point. Wraps the app in a Riverpod `ProviderScope` so any provider
// (state stores, API layers, catalog cache) is reachable from anywhere in the
// tree — the idiomatic Flutter equivalent of the RN app's zustand stores +
// react-query providers mounted at the root.
//
// Module 7 scope: MOCK AUTH. The boot screen is now an auth GATE that reads
// [sessionProvider]: it shows a splash while the saved session restores, the
// signed-out AuthFlow (Login / Sign up / Forgot-password) when nobody is signed in,
// and a signed-in placeholder (greeting + Log out, plus the Module 6 catalog proof)
// once authenticated. Real route guards / splash / route-set swapping land in
// Module 8 — this gate is the lightweight stand-in that proves the flow.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/config/app_config.dart';
import 'src/core/network/api_exception.dart';
import 'src/core/theme/theme.dart';
import 'src/core/widgets/widgets.dart';
import 'src/features/auth/auth.dart';
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

/// Root application widget. A single `MaterialApp` — the RN app is a stack-based
/// navigator (no tabs, no drawer); the real routing arrives in Module 8. Its home
/// is the auth [_AppGate].
class MicrocareApp extends StatelessWidget {
  const MicrocareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microcare',
      debugShowCheckedModeBanner: false,
      // The Module 5 design system, extracted from the RN src/constants/*.
      theme: AppTheme.light,
      home: const _AppGate(),
    );
  }
}

/// The lightweight auth gate (Module 7): splash while the session restores, the
/// signed-out [AuthFlow], or the signed-in home. Module 8 replaces this with real
/// route guards + route-set swapping; the three states here mirror what it will do.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    if (session.isRestoring) return const _SplashScreen();
    final user = session.user;
    if (user != null) return _SignedInHome(user: user);
    return const AuthFlow();
  }
}

/// Shown only during cold-start session restore — a returning user never flashes
/// the login screen. (Module 8 makes this the real splash.)
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit, size: 56, color: AppColors.primary),
            SizedBox(height: AppSpacing.lg),
            CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

/// The signed-in placeholder — proves mock auth end-to-end (greeting + Log out)
/// while keeping the Module 6 catalog proof visible as the "protected app".
/// Replaced by the real Home / dashboard in Module 9.
class _SignedInHome extends ConsumerWidget {
  final AuthUser user;
  const _SignedInHome({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.ac_unit, size: 40, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText('Microcare', variant: AppTextVariant.h2),
                        AppText('Signed in as ${user.email ?? user.displayName}',
                            variant: AppTextVariant.caption,
                            color: AppTextColor.muted),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'Log out',
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.sm,
                    onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppText('Module 7 ✓  Mock auth', variant: AppTextVariant.h3),
              const SizedBox(height: AppSpacing.xs),
              const AppText(
                'You are signed in via the local persisted mock backend.',
                variant: AppTextVariant.caption,
                color: AppTextColor.muted,
              ),
              const SizedBox(height: AppSpacing.md),

              // The live catalog proof carried over from Module 6.
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

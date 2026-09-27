// lib/src/app/screens/home_screen.dart — the "/" route, a STUB for Module 8.
//
// The real Home / dashboard (greeting, categories strip, popular services, cart
// badge) arrives in Module 9. For now this proves the routing skeleton: it greets
// the signed-in user, logs out (which the auth guard turns into a bounce to the
// login screen), pushes each protected route to show the stack navigator working,
// and keeps the Module 6 live catalog proof visible.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../features/auth/auth.dart';
import '../../features/services/services.dart';
import '../app_routes.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

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
                        AppText('Hi ${user?.displayName ?? 'there'} 👋',
                            variant: AppTextVariant.h2),
                        const AppText(
                          'Book AC cleaning, repair & maintenance across Dubai.',
                          variant: AppTextVariant.caption,
                          color: AppTextColor.muted,
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'Log out',
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.sm,
                    onPressed: () =>
                        ref.read(sessionProvider.notifier).signOut(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppText('Module 8 ✓  Navigation & route guards',
                  variant: AppTextVariant.h3),
              const SizedBox(height: AppSpacing.xs),
              const AppText(
                'Tap a destination to push it on the stack (back returns here). '
                'Log out and the auth guard bounces you to the login screen.',
                variant: AppTextVariant.caption,
                color: AppTextColor.muted,
              ),
              const SizedBox(height: AppSpacing.md),

              _NavCard(),
              const SizedBox(height: AppSpacing.lg),

              // The live catalog proof carried over from Module 6.
              const CatalogProofCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card of buttons that push each protected route — a live proof of the stack
/// navigator and the route tree.
class _NavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Go to', variant: AppTextVariant.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              const _NavButton('Categories', AppRoutes.categories),
              const _NavButton('Search', AppRoutes.search),
              const _NavButton('Cart', AppRoutes.cart),
              const _NavButton('My bookings', AppRoutes.orders),
              const _NavButton('About', AppRoutes.about),
              _NavButton('A service', AppRoutes.serviceOf('svc_split_clean')),
              const _NavButton('Booking (guarded)', AppRoutes.bookingLocation),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final String path;
  const _NavButton(this.label, this.path);

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.sm,
      onPressed: () => context.push(path),
    );
  }
}

/// Reads the whole active catalog and renders each AsyncValue state — loading,
/// error (with a working "Try again" that invalidates the cache to refetch),
/// empty, and data (a count plus the first few service names and "from" prices).
/// Carried over from Module 6 as a live proof; folded into the real Home in
/// Module 9.
class CatalogProofCard extends ConsumerWidget {
  static const _query = ServiceQuery.all;

  const CatalogProofCard({super.key});

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
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: AppText(s.name,
                                    variant: AppTextVariant.body),
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
      if (error.isTimeout) {
        return 'Request timed out. Check the backend is running.';
      }
      if (error.isNetwork) {
        return 'Network error. Is the backend reachable at '
            '${config.apiBaseUrl}?';
      }
      return error.message;
    }
    return 'Could not load the catalog: $error';
  }
}

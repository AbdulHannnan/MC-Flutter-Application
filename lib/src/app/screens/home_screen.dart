// lib/src/app/screens/home_screen.dart — the "/" route: the Home / dashboard.
// Dart port of the RN app's `src/app/index.tsx` (Module 9).
//
// The first screen a signed-in user lands on. It greets them, offers My-bookings +
// cart shortcuts (the cart shows a live count badge) and log out, a tappable search
// pill, a horizontal strip of CATEGORIES ("See all" → the full list), and a
// vertical list of POPULAR SERVICES (the highest-rated few, client-sorted). The
// catalog comes from the Module 6 read providers; loading / error / empty states
// come from the shared QueryBoundary. It lives behind the auth guard, so the user
// is always present. Taps open the (stubbed until their module) detail routes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../features/auth/auth.dart';
import '../../features/cart/cart.dart';
import '../../features/services/services.dart';
import '../../models/models.dart';
import '../app_routes.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final categories = ref.watch(categoriesProvider);
    final services = ref.watch(servicesProvider(ServiceQuery.all));
    final cartCount = ref.watch(cartCountProvider);

    // Prefer a first name; fall back to the full name, then a friendly default.
    final greetingName = user?.firstName ?? user?.fullName ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            // ── Header: greeting, shortcuts, logout ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AppText('Hi $greetingName 👋',
                            variant: AppTextVariant.h2, maxLines: 1),
                      ),
                      IconButton(
                        onPressed: () => context.push(AppRoutes.orders),
                        icon: const Icon(Icons.receipt_long_outlined),
                        color: AppColors.text,
                        tooltip: 'My bookings',
                      ),
                      _CartButton(count: cartCount),
                      TextButton(
                        onPressed: () =>
                            ref.read(sessionProvider.notifier).signOut(),
                        child: const AppText('Log out',
                            variant: AppTextVariant.caption,
                            color: AppTextColor.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const AppText(
                    'Book AC cleaning, repair & maintenance across Dubai.',
                    color: AppTextColor.muted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SearchPill(onTap: () => context.push(AppRoutes.search)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Categories (horizontal) ──
            _Section(
              title: 'Categories',
              action: _SeeAll(onTap: () => context.push(AppRoutes.categories)),
              child: QueryBoundary<ServiceCategory>(
                query: categories,
                emptyLabel: 'No categories yet.',
                onRetry: () => ref.invalidate(categoriesProvider),
                builder: (list) => SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) => CategoryChip(
                      category: list[i],
                      onTap: () =>
                          context.push(AppRoutes.categoryOf(list[i].id)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Popular services (vertical, highest-rated first) ──
            _Section(
              title: 'Popular services',
              child: QueryBoundary<Service>(
                query: services,
                emptyLabel: 'No services yet.',
                onRetry: () =>
                    ref.invalidate(servicesProvider(ServiceQuery.all)),
                builder: (list) {
                  final popular = [...list]
                    ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
                  final top = popular.take(5).toList();
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      children: [
                        for (final service in top) ...[
                          ServiceCard(
                            service: service,
                            onTap: () =>
                                context.push(AppRoutes.serviceOf(service.id)),
                          ),
                          if (service != top.last)
                            const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled section: a heading (with an optional right-aligned action) above its
/// content. The content lays out its own horizontal padding so full-bleed strips
/// work.
class _Section extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget child;

  const _Section({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(title, variant: AppTextVariant.h3),
              ?action,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _SeeAll extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAll({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const AppText('See all',
          variant: AppTextVariant.caption, color: AppTextColor.primary),
    );
  }
}

/// The tappable search bar — a pill that opens the search screen (which owns the
/// input). A soft shadow so it reads as a real affordance, not a plain box.
class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.pillAll,
          boxShadow: [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, size: 20, color: AppColors.textSubtle),
            SizedBox(width: AppSpacing.sm),
            AppText('Search AC services…', color: AppTextColor.muted),
          ],
        ),
      ),
    );
  }
}

/// The cart shortcut with a live count badge (hidden when empty).
class _CartButton extends StatelessWidget {
  final int count;
  const _CartButton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push(AppRoutes.cart),
          icon: const Icon(Icons.shopping_cart_outlined),
          color: AppColors.text,
          tooltip: 'Your cart',
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppText('$count',
                  variant: AppTextVariant.caption,
                  color: AppTextColor.inverse,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, height: 1)),
            ),
          ),
      ],
    );
  }
}

// lib/src/features/orders/screens/orders_screen.dart — the "/orders" route (My
// Bookings). Dart port of the RN app's `OrdersScreen.tsx` (Module 15).
//
// The signed-in user's confirmed bookings, newest first, read from the local store
// through [bookingsProvider]. A settled-empty history gets a full-screen
// invitation to browse (not a bare list line); loading and error reuse the shared
// full-screen primitives. Tapping a booking opens its digital receipt
// (`/orders/:id`). This route lives behind the auth guard, so a user is always
// present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../orders_providers.dart';
import '../widgets/booking_card.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: SafeArea(
        child: bookings.when(
          loading: () => const LoadingState(),
          error: (_, _) => ErrorState(
            title: "Couldn't load your bookings",
            onRetry: () => ref.invalidate(bookingsProvider),
          ),
          data: (list) => list.isEmpty
              ? const _EmptyOrders()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final booking = list[i];
                    return BookingCard(
                      booking: booking,
                      onTap: () =>
                          context.push(AppRoutes.orderOf(booking.id)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// No bookings yet — a friendly nudge back to browsing (mirrors the RN empty
/// state and the cart's own empty screen).
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.textSubtle),
            const SizedBox(height: AppSpacing.md),
            const AppText('No bookings yet',
                variant: AppTextVariant.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            const AppText(
              "Once you book a service it'll show up here with its receipt.",
              color: AppTextColor.muted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Browse services',
              onPressed: () => context.go(AppRoutes.home),
            ),
          ],
        ),
      ),
    );
  }
}

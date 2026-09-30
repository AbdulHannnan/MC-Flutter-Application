// lib/src/features/checkout/screens/checkout_failure_screen.dart — the
// "/checkout/failure" route. Dart port of the RN app's failure screen (Module 14).
//
// Checkout didn't complete. The cart is intentionally LEFT INTACT (we never clear
// it on failure), so the user loses nothing. Shows the reason and two ways on:
// "Try again" → back to checkout, "Back to cart" → the cart. If reached with no
// recorded outcome (refresh / deep link), bounces to the cart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../checkout_controller.dart';

class CheckoutFailureScreen extends ConsumerWidget {
  const CheckoutFailureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(checkoutControllerProvider);

    if (outcome != null && outcome.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.cart);
      });
      return const Scaffold(body: SafeArea(child: SizedBox.shrink()));
    }

    final reason = outcome?.failureReason ?? 'Something went wrong with your payment.';

    void tryAgain() {
      ref.read(checkoutControllerProvider.notifier).reset();
      context.go(AppRoutes.checkout);
    }

    void backToCart() {
      ref.read(checkoutControllerProvider.notifier).reset();
      context.go(AppRoutes.cart);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment failed'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const Center(
                    child: Icon(Icons.error_outline,
                        size: 72, color: AppColors.danger),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppText('Payment failed',
                      variant: AppTextVariant.h2, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  AppText(reason,
                      color: AppTextColor.muted, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  const AppText(
                    'Your cart is still saved.',
                    variant: AppTextVariant.caption,
                    color: AppTextColor.muted,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Try again',
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: tryAgain,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Back to cart',
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: backToCart,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

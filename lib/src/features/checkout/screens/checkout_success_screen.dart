// lib/src/features/checkout/screens/checkout_success_screen.dart — the
// "/checkout/success" route. Dart port of the RN app's success screen (Module 14).
//
// The booking is placed, the cart + draft are cleared. Shows the reference(s), the
// amount charged and the payment transaction ref. There is NO back button: going
// back into a completed, emptied checkout makes no sense, so the app bar has no
// leading control and the system back is blocked ([PopScope]); the only way on is
// "Done" → Home. If the screen is reached with no recorded outcome (a refresh or
// deep link), it bounces Home.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../checkout_controller.dart';

class CheckoutSuccessScreen extends ConsumerWidget {
  const CheckoutSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(checkoutControllerProvider);

    // No outcome to show (refresh / deep link) → leave for Home.
    if (outcome == null || !outcome.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const Scaffold(body: SafeArea(child: SizedBox.shrink()));
    }

    void done() {
      ref.read(checkoutControllerProvider.notifier).reset();
      context.go(AppRoutes.home);
    }

    return PopScope(
      canPop: false, // no going back into a completed checkout
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirmed'),
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
                      child: Icon(Icons.check_circle,
                          size: 72, color: AppColors.success),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppText('Booking confirmed',
                        variant: AppTextVariant.h2, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xs),
                    const AppText(
                      'We\'ve sent a confirmation and notified the provider.',
                      color: AppTextColor.muted,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      child: Column(
                        children: [
                          _Row(
                            label: outcome.references.length > 1
                                ? 'References'
                                : 'Reference',
                            value: outcome.references.join(', '),
                          ),
                          const Divider(height: AppSpacing.lg),
                          _Row(
                              label: 'Amount paid',
                              value: outcome.amount?.format() ?? '—'),
                          if (outcome.transactionRef != null) ...[
                            const Divider(height: AppSpacing.lg),
                            _Row(
                                label: 'Transaction',
                                value: outcome.transactionRef!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppButton(
                    label: 'Done',
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: done,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label → value receipt row.
class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, color: AppTextColor.muted),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppText(value,
              variant: AppTextVariant.bodyStrong, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

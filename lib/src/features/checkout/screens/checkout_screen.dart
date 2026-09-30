// lib/src/features/checkout/screens/checkout_screen.dart — the "/checkout" route.
// Dart port of the RN app's CheckoutScreen (Module 14).
//
// The last step before payment: a read-only order summary (every cart line + the
// total), the payer's contact — Phone (required) and Email (prefilled from the
// session, validated) — and a single "Pay {amount}" CTA. An empty cart can't be
// paid: the router redirects /checkout → /cart when the cart is empty, and we
// guard here too. On pay we run [CheckoutController.pay] and route to the Success
// or Failure screen on its outcome.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../../auth/auth.dart';
import '../../cart/cart.dart';
import '../checkout_controller.dart';
import '../checkout_validation.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _email =
      TextEditingController(text: ref.read(sessionProvider).user?.email ?? '');

  CheckoutErrors _errors = const CheckoutErrors();
  bool _paying = false;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final errors = validateCheckout(phone: _phone.text, email: _email.text);
    setState(() => _errors = errors);
    if (errors.hasErrors) return;

    setState(() => _paying = true);
    final outcome = await ref.read(checkoutControllerProvider.notifier).pay(
          phone: _phone.text,
          email: _email.text,
        );
    if (!mounted) return;
    setState(() => _paying = false);

    context.go(outcome.success
        ? AppRoutes.checkoutSuccess
        : AppRoutes.checkoutFailure);
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final total = ref.watch(cartSubtotalProvider);

    // Defensive empty-cart guard (the router also redirects to /cart).
    if (lines.isEmpty || total == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText('Your cart is empty',
                      variant: AppTextVariant.h3, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Browse services',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const AppText('Order summary', variant: AppTextVariant.h3),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      children: [
                        for (final line in lines) ...[
                          _SummaryLine(line: line),
                          if (line != lines.last)
                            const Divider(height: AppSpacing.lg),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppText('Contact', variant: AppTextVariant.h3),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Phone',
                    hintText: '+971 50 123 4567',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    errorText: _errors.phone,
                    onChanged: (_) {
                      if (_errors.phone != null) {
                        setState(() => _errors =
                            CheckoutErrors(email: _errors.email));
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Email',
                    hintText: 'you@example.com',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    errorText: _errors.email,
                    onChanged: (_) {
                      if (_errors.email != null) {
                        setState(() => _errors =
                            CheckoutErrors(phone: _errors.phone));
                      }
                    },
                    onSubmitted: (_) => _pay(),
                  ),
                ],
              ),
            ),
            _Footer(total: total, paying: _paying, onPay: _paying ? null : _pay),
          ],
        ),
      ),
    );
  }
}

/// One order-summary line: service (+ option) × qty, and the line total.
class _SummaryLine extends StatelessWidget {
  final CartItem line;
  const _SummaryLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final title = line.optionName == null
        ? line.serviceName
        : '${line.serviceName} · ${line.optionName}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, variant: AppTextVariant.bodyStrong, maxLines: 2),
              if (line.quantity > 1) ...[
                const SizedBox(height: AppSpacing.xs),
                AppText('Qty ${line.quantity}',
                    variant: AppTextVariant.caption, color: AppTextColor.muted),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppText(line.lineTotal.format(), variant: AppTextVariant.bodyStrong),
      ],
    );
  }
}

/// The pinned footer: the total and the "Pay {amount}" CTA (spinner while paying).
class _Footer extends StatelessWidget {
  final Money total;
  final bool paying;
  final VoidCallback? onPay;

  const _Footer({required this.total, required this.paying, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText('Total', color: AppTextColor.muted),
                  AppText(total.format(), variant: AppTextVariant.h3),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Pay ${total.format()}',
                size: AppButtonSize.lg,
                fullWidth: true,
                loading: paying,
                onPressed: onPay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

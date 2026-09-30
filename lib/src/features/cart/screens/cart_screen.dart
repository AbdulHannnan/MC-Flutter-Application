// lib/src/features/cart/screens/cart_screen.dart — the "/cart" route. Dart port
// of the RN app's cart screen (Module 13).
//
// Reads the persisted cart store ([cartProvider]) and renders one card per line
// with a quantity stepper, a remove action and the line total; a pinned footer
// shows the subtotal and the Checkout CTA. An empty cart shows a friendly empty
// state instead of the list/footer, and a non-empty cart offers "Clear" in the
// app bar. All mutations go through [CartController]; this screen holds no cart
// state of its own.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../cart_controller.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const AppText('Clear',
                  variant: AppTextVariant.caption, color: AppTextColor.danger),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: lines.isEmpty
            ? const _EmptyCart()
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: lines.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) => _CartLineCard(item: lines[i]),
                    ),
                  ),
                  _Footer(
                    subtotal: subtotal,
                    onCheckout: () => context.push(AppRoutes.checkout),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('This removes every item from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Clear',
                variant: AppTextVariant.body, color: AppTextColor.danger),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(cartProvider.notifier).clear();
  }
}

/// One cart line: what was booked (service / option / add-ons / where+when) with
/// a quantity stepper, a remove button and the line total.
class _CartLineCard extends ConsumerWidget {
  final CartItem item;
  const _CartLineCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(item.serviceName,
                        variant: AppTextVariant.bodyStrong, maxLines: 2),
                    if (item.optionName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppText(item.optionName!,
                          variant: AppTextVariant.caption,
                          color: AppTextColor.muted),
                    ],
                    if (item.addons.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppText('+ ${item.addons.map((a) => a.name).join(', ')}',
                          variant: AppTextVariant.caption,
                          color: AppTextColor.muted,
                          maxLines: 2),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Remove the whole line.
              IconButton(
                onPressed: () => controller.remove(item.id),
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.muted,
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (_whereWhen != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined,
                    size: 16, color: AppColors.textSubtle),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AppText(_whereWhen!,
                      variant: AppTextVariant.caption,
                      color: AppTextColor.muted,
                      maxLines: 2),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QtyStepper(
                quantity: item.quantity,
                onDecrement: () => controller.decrement(item.id),
                onIncrement: () => controller.increment(item.id),
              ),
              AppText(item.lineTotal.format(),
                  variant: AppTextVariant.bodyStrong),
            ],
          ),
        ],
      ),
    );
  }

  /// A compact "where · when" line, built from whichever of location/slot the
  /// line carries (both are optional on the model).
  String? get _whereWhen {
    final parts = <String>[];
    final loc = item.location;
    if (loc != null) {
      final where = loc.area ?? loc.label ?? loc.addressText;
      if (where.trim().isNotEmpty) parts.add(where.trim());
    }
    final slot = item.slot;
    if (slot != null) {
      parts.add('${formatFullDate(toLocalIsoDate(slot.start))}, '
          '${formatTime(slot.start)}');
    }
    return parts.isEmpty ? null : parts.join('  ·  ');
  }
}

/// The −/+ quantity control. Minus at 1 removes the line (the controller drops a
/// line whose quantity hits zero).
class _QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QtyStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: onDecrement,
            semanticLabel: 'Decrease quantity',
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: AppText('$quantity', variant: AppTextVariant.bodyStrong),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: onIncrement,
            semanticLabel: 'Increase quantity',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: AppRadii.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Icon(icon,
            size: 18, color: AppColors.text, semanticLabel: semanticLabel),
      ),
    );
  }
}

/// The pinned footer: the subtotal + the Checkout CTA.
class _Footer extends StatelessWidget {
  final Money? subtotal;
  final VoidCallback onCheckout;

  const _Footer({required this.subtotal, required this.onCheckout});

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
                  const AppText('Subtotal', color: AppTextColor.muted),
                  AppText(subtotal?.format() ?? '—',
                      variant: AppTextVariant.subheading),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Checkout',
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: subtotal == null ? null : onCheckout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when there's nothing in the cart — a friendly nudge back to browsing.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined,
                size: 56, color: AppColors.textSubtle),
            const SizedBox(height: AppSpacing.md),
            const AppText('Your cart is empty',
                variant: AppTextVariant.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            const AppText(
              'Browse AC services and add one to get started.',
              color: AppTextColor.muted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Builder(
              builder: (context) => AppButton(
                label: 'Browse services',
                onPressed: () => context.go(AppRoutes.home),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/src/features/orders/screens/order_detail_screen.dart — the "/orders/:id"
// route: the digital receipt. Dart port of the RN app's `OrderDetailScreen.tsx`
// (Module 15).
//
// The full proof-of-booking view for one confirmed booking: its reference and
// status, what was booked (service, option, add-ons), when and where the visit
// happens, any notes, and the money — a per-line breakdown down to the paid total,
// plus the gateway payment reference. Read through [bookingProvider] (scoped to the
// signed-in user), so one account can never open another's receipt.
//
// States: a spinner while it loads, a genuine error with retry, a "not found" note
// when the id is unknown or belongs to someone else (the provider resolves null),
// else the receipt.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../orders_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  /// The booking id from the route (`/orders/:id`).
  final String bookingId;

  const OrderDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking receipt')),
      body: SafeArea(
        child: booking.when(
          loading: () => const LoadingState(),
          error: (_, _) => ErrorState(
            title: "Couldn't load this booking",
            onRetry: () => ref.invalidate(bookingProvider(bookingId)),
          ),
          data: (value) =>
              value == null ? const _NotFound() : _Receipt(booking: value),
        ),
      ),
    );
  }
}

/// The receipt body — only rendered once there's a booking.
class _Receipt extends StatelessWidget {
  final Booking booking;
  const _Receipt({required this.booking});

  @override
  Widget build(BuildContext context) {
    final placedOn = formatFullDate(toLocalIsoDate(booking.createdAt));
    final visitDate = formatFullDate(toLocalIsoDate(booking.slot.start));
    final visitTime =
        '${formatTime(booking.slot.start)} – ${formatTime(booking.slot.end)}';
    final location = booking.location;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        // Header: reference + status + when it was placed.
        Column(
          children: [
            const Text('🧾', style: TextStyle(fontSize: 44)),
            const SizedBox(height: AppSpacing.xs),
            AppText(booking.reference, variant: AppTextVariant.h2),
            const SizedBox(height: AppSpacing.sm),
            StatusPill(status: booking.status),
            const SizedBox(height: AppSpacing.xs),
            AppText('Placed on $placedOn',
                variant: AppTextVariant.caption, color: AppTextColor.muted),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Schedule.
        _Section(
          title: 'Schedule',
          children: [
            _Row(label: 'Date', value: visitDate),
            _Row(label: 'Time', value: visitTime),
          ],
        ),

        // Where the visit happens.
        if (location != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Location',
            children: [
              if (location.label != null)
                _Row(label: 'Saved as', value: location.label!),
              _Row(label: 'Address', value: location.addressText),
              if (location.area != null)
                _Row(label: 'Area', value: location.area!),
            ],
          ),
        ],

        // What was booked — one block per line, with its add-ons and line total.
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Service',
          children: [
            for (final item in booking.items) _ItemLine(item: item),
          ],
        ),

        // Special instructions left at review.
        if (booking.notes != null && booking.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Notes',
            children: [AppText(booking.notes!, color: AppTextColor.muted)],
          ),
        ],

        // Money: subtotal → total. (No separate fees/taxes in the app today.)
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Payment',
          children: [
            _Row(label: 'Subtotal', value: booking.subtotal.format()),
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppText('Total paid', variant: AppTextVariant.bodyStrong),
                AppText(booking.total.format(),
                    variant: AppTextVariant.bodyStrong),
              ],
            ),
            if (booking.paymentId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('Payment reference',
                      variant: AppTextVariant.caption,
                      color: AppTextColor.muted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppText(booking.paymentId!,
                        variant: AppTextVariant.caption,
                        color: AppTextColor.subtle,
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The id is unknown or belongs to someone else.
class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined,
                size: 56, color: AppColors.textSubtle),
            const SizedBox(height: AppSpacing.md),
            const AppText('Booking not found',
                variant: AppTextVariant.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            const AppText(
              "This booking doesn't exist or isn't on your account.",
              color: AppTextColor.muted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Back to bookings',
              variant: AppButtonVariant.outline,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.orders),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The receipt building blocks ─────────────────────────────────────────────

/// One booked line: service (+ option), its add-ons, quantity, and the line
/// total.
class _ItemLine extends StatelessWidget {
  final CartItem item;
  const _ItemLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    item.quantity > 1
                        ? '${item.serviceName}  × ${item.quantity}'
                        : item.serviceName,
                    variant: AppTextVariant.bodyStrong,
                  ),
                  if (item.optionName != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppText(item.optionName!,
                        variant: AppTextVariant.caption,
                        color: AppTextColor.muted),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppText(item.lineTotal.format(), variant: AppTextVariant.bodyStrong),
          ],
        ),
        // Add-ons, listed under the line.
        if (item.addons.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final addon in item.addons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText('+ ${addon.name}',
                              variant: AppTextVariant.caption,
                              color: AppTextColor.muted),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppText(addon.price.format(),
                            variant: AppTextVariant.caption,
                            color: AppTextColor.muted),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A titled card grouping related rows.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title.toUpperCase(),
              variant: AppTextVariant.caption, color: AppTextColor.subtle),
          const SizedBox(height: AppSpacing.sm),
          ..._withGaps(children),
        ],
      ),
    );
  }

  /// `sm` vertical rhythm between a section's rows (the RN `gap-sm`).
  static List<Widget> _withGaps(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(height: AppSpacing.sm));
      out.add(items[i]);
    }
    return out;
  }
}

/// A label → value line inside a section.
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

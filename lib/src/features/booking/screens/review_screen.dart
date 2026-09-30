// lib/src/features/booking/screens/review_screen.dart — the "/booking/review"
// route: the final booking step (step 4). Dart port of the RN app's ReviewScreen
// (Module 13).
//
// A read-back of the assembled draft — Service (option + add-ons), Where and When
// — each with an "Edit" link that jumps back to the step that owns that data (the
// step re-seeds from the draft, so nothing is lost). Notes are editable here. The
// footer shows the total and the two ways forward:
//   • Add to cart (outline) — snapshot the draft into the persisted cart and go
//     to the cart. No revalidation: the price is reconciled later, at checkout.
//   • Pay now (primary)     — REVALIDATE against the live catalog first. A gone
//     service/option/slot shows a BLOCKING banner and stops; a price drift is
//     auto-applied with an INFO banner (the user re-confirms); otherwise the draft
//     is added to the cart and we continue to checkout.
//
// GUARD: the router's `_bookingDraftGuard` requires service + location + slot
// before this builds, so those are present; we still null-check defensively.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../../cart/cart.dart';
import '../booking_controller.dart';
import '../booking_draft.dart';
import '../booking_revalidation.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final TextEditingController _notes =
      TextEditingController(text: ref.read(bookingDraftProvider).notes);

  /// True while a "Pay now" revalidation is in flight (spinner + block re-taps).
  bool _revalidating = false;

  /// The last revalidation result, rendered as the info/blocking banner.
  RevalidationOutcome? _outcome;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _editService(String serviceId) =>
      context.push(AppRoutes.serviceOf(serviceId));
  void _editWhere() => context.push(AppRoutes.bookingLocation);
  void _editWhen() => context.push(AppRoutes.bookingSchedule);

  /// Snapshot the draft into the cart, clear the draft, and hand back a fresh cart.
  void _addToCart() {
    final item = ref.read(bookingDraftProvider).buildCartItem();
    if (item == null) return;
    ref.read(cartProvider.notifier).add(item);
    ref.read(bookingDraftProvider.notifier).reset();
    context.go(AppRoutes.cart);
  }

  Future<void> _payNow() async {
    setState(() {
      _revalidating = true;
      _outcome = null;
    });
    final outcome = await ref.read(bookingDraftProvider.notifier).revalidate();
    if (!mounted) return;
    setState(() {
      _revalidating = false;
      _outcome = outcome;
    });

    // Only a clean revalidation proceeds. A price drift updated the draft (and the
    // total below) and shows an info banner; the user taps Pay now again to confirm.
    // A block leaves the banner up until they edit the offending step.
    if (!outcome.canProceed) return;

    final item = ref.read(bookingDraftProvider).buildCartItem();
    if (item == null) return;
    ref.read(cartProvider.notifier).add(item);
    ref.read(bookingDraftProvider.notifier).reset();
    context.go(AppRoutes.checkout);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final service = draft.service;
    final subtotal = draft.subtotal;

    // The guard guarantees a service; if somehow absent, bail to a bare scaffold.
    if (service == null || subtotal == null) {
      return Scaffold(appBar: AppBar(title: const Text('Review')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _ServiceCard(draft: draft, onEdit: () => _editService(service.id)),
                  const SizedBox(height: AppSpacing.md),
                  _WhereCard(location: draft.location, onEdit: _editWhere),
                  const SizedBox(height: AppSpacing.md),
                  _WhenCard(slot: draft.slot, onEdit: _editWhen),
                  const SizedBox(height: AppSpacing.md),
                  _NotesCard(
                    controller: _notes,
                    onChanged: (v) =>
                        ref.read(bookingDraftProvider.notifier).setNotes(v),
                  ),
                ],
              ),
            ),
            _Footer(
              total: subtotal,
              outcome: _outcome,
              revalidating: _revalidating,
              onAddToCart: _addToCart,
              onPayNow: _revalidating ? null : _payNow,
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled section card with an "Edit" link that jumps to the owning step.
class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onEdit;
  final Widget child;

  const _SectionCard({required this.title, required this.child, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(title, variant: AppTextVariant.subheading),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: const AppText('Edit',
                      variant: AppTextVariant.caption,
                      color: AppTextColor.primary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Service read-back: name, chosen option, and a price breakdown (unit + add-ons).
class _ServiceCard extends StatelessWidget {
  final BookingDraft draft;
  final VoidCallback onEdit;

  const _ServiceCard({required this.draft, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final service = draft.service!;
    final unit = draft.unitPrice!;
    final baseLabel = draft.option?.name ?? service.name;

    return _SectionCard(
      title: 'Service',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(service.name, variant: AppTextVariant.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          _PriceRow(label: baseLabel, value: unit.format()),
          for (final a in draft.addons) ...[
            const SizedBox(height: AppSpacing.xs),
            _PriceRow(
                label: a.name, value: '+${a.price.format()}', muted: true),
          ],
        ],
      ),
    );
  }
}

/// Where read-back: the typed address, plus area/label when set.
class _WhereCard extends StatelessWidget {
  final BookingLocation? location;
  final VoidCallback onEdit;

  const _WhereCard({required this.location, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final l = location;
    final secondary = l?.area ?? l?.label;

    return _SectionCard(
      title: 'Where',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            l == null || l.addressText.trim().isEmpty
                ? (secondary ?? 'No address set')
                : l.addressText.trim(),
            variant: AppTextVariant.body,
          ),
          if (secondary != null && l != null && l.addressText.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            AppText(secondary,
                variant: AppTextVariant.caption, color: AppTextColor.muted),
          ],
        ],
      ),
    );
  }
}

/// When read-back: the chosen day and time.
class _WhenCard extends StatelessWidget {
  final TimeSlot? slot;
  final VoidCallback onEdit;

  const _WhenCard({required this.slot, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final s = slot;
    return _SectionCard(
      title: 'When',
      onEdit: onEdit,
      child: s == null
          ? const AppText('No time selected', color: AppTextColor.muted)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(formatFullDate(toLocalIsoDate(s.start)),
                    variant: AppTextVariant.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                AppText(formatTime(s.start),
                    variant: AppTextVariant.caption, color: AppTextColor.muted),
              ],
            ),
    );
  }
}

/// Editable notes for the provider.
class _NotesCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NotesCard({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Notes',
      child: AppTextField(
        controller: controller,
        hintText: 'Anything the provider should know? (optional)',
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}

/// A label → value row (used for the price breakdown).
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;

  const _PriceRow({required this.label, required this.value, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppTextColor.muted : AppTextColor.normal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: AppText(label, color: color)),
        const SizedBox(width: AppSpacing.md),
        AppText(value, color: color),
      ],
    );
  }
}

/// The pinned footer: the revalidation banner (when any), the total, and the two
/// CTAs (Add to cart / Pay now).
class _Footer extends StatelessWidget {
  final Money total;
  final RevalidationOutcome? outcome;
  final bool revalidating;
  final VoidCallback onAddToCart;
  final VoidCallback? onPayNow;

  const _Footer({
    required this.total,
    required this.outcome,
    required this.revalidating,
    required this.onAddToCart,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    final blocked = o?.isBlocked ?? false;

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
              if (o != null && o.message != null) ...[
                _RevalidationBanner(message: o.message!, blocking: blocked),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText('Total', color: AppTextColor.muted),
                  AppText(total.format(), variant: AppTextVariant.h3),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Add to cart',
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: revalidating ? null : onAddToCart,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Pay now',
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      loading: revalidating,
                      onPressed: onPayNow,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The revalidation banner: danger styling when blocking (service/slot gone),
/// warning styling when it's an informational price update.
class _RevalidationBanner extends StatelessWidget {
  final String message;
  final bool blocking;

  const _RevalidationBanner({required this.message, required this.blocking});

  @override
  Widget build(BuildContext context) {
    final bg = blocking ? AppColors.dangerSoft : AppColors.warningSoft;
    final border = blocking ? AppColors.danger : AppColors.warning;
    final icon = blocking ? Icons.error_outline : Icons.info_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: border),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppText(message,
                variant: AppTextVariant.caption, color: AppTextColor.normal),
          ),
        ],
      ),
    );
  }
}

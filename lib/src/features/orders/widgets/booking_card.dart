// lib/src/features/orders/widgets/booking_card.dart — one row in the order
// history. Dart port of the RN app's `BookingCard.tsx` (Module 15).
//
// A tappable summary of a confirmed booking: the service (and a "+ N more" when a
// line bundles extras), when and where the visit happens, its status badge, the
// reference code and the amount paid. Presentational — the list screen owns the
// data and the navigation; this just lays out one booking and calls [onTap].

import 'package:flutter/material.dart';

import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const BookingCard({super.key, required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // A booking is one visit → one primary service line; surface the first and
    // count any extras (mirrors the RN card).
    final serviceName =
        booking.items.isNotEmpty ? booking.items.first.serviceName : 'Service';
    final extraLines = booking.items.length > 1 ? booking.items.length - 1 : 0;
    final when = '${formatFullDate(toLocalIsoDate(booking.slot.start))} · '
        '${formatTime(booking.slot.start)}';
    final where = booking.location?.area ?? booking.location?.addressText;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.lgAll,
      child: Semantics(
        button: true,
        label: 'Booking ${booking.reference}, $serviceName',
        child: AppCard(
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
                        AppText(
                          extraLines > 0
                              ? '$serviceName  + $extraLines more'
                              : serviceName,
                          variant: AppTextVariant.bodyStrong,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppText(when,
                            variant: AppTextVariant.caption,
                            color: AppTextColor.muted),
                        if (where != null && where.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 14, color: AppColors.textSubtle),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: AppText(where.trim(),
                                    variant: AppTextVariant.caption,
                                    color: AppTextColor.subtle,
                                    maxLines: 1),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  StatusPill(status: booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText(booking.reference,
                      variant: AppTextVariant.caption,
                      color: AppTextColor.subtle),
                  AppText(booking.total.format(),
                      variant: AppTextVariant.bodyStrong),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

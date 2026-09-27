// lib/src/core/widgets/status_pill.dart — the booking-status badge. Dart port of
// the RN app's `StatusPill.tsx` + `bookingStatus.ts` describeStatus mapping.
//
// A small pill showing a booking's status (Confirmed / Completed / …), used by
// both the order-history card and the receipt screen so the badge is identical
// everywhere. One place turns a [BookingStatus] into a human label plus a tone;
// the tone maps to a soft tinted background and matching text colour.

import 'package:flutter/widgets.dart';

import '../../models/booking.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// The tones a status can take — each pairs a soft background with a text colour.
enum _StatusTone { primary, success, danger, muted }

class _StatusDescriptor {
  final String label;
  final _StatusTone tone;
  const _StatusDescriptor(this.label, this.tone);
}

const Map<BookingStatus, _StatusDescriptor> _descriptors = {
  BookingStatus.pending: _StatusDescriptor('Pending', _StatusTone.muted),
  BookingStatus.confirmed: _StatusDescriptor('Confirmed', _StatusTone.primary),
  BookingStatus.completed: _StatusDescriptor('Completed', _StatusTone.success),
  BookingStatus.cancelled: _StatusDescriptor('Cancelled', _StatusTone.danger),
};

const Map<_StatusTone, Color> _toneBackground = {
  _StatusTone.primary: AppColors.primarySoft,
  _StatusTone.success: AppColors.successSoft,
  _StatusTone.danger: AppColors.dangerSoft,
  _StatusTone.muted: AppColors.surfaceAlt,
};

const Map<_StatusTone, Color> _toneText = {
  _StatusTone.primary: AppColors.primary,
  _StatusTone.success: AppColors.success,
  _StatusTone.danger: AppColors.danger,
  _StatusTone.muted: AppColors.muted,
};

class StatusPill extends StatelessWidget {
  final BookingStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final descriptor = _descriptors[status]!;
    // `self-start`: only as wide as its content.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: _toneBackground[descriptor.tone],
          borderRadius: AppRadii.pillAll,
        ),
        child: Text(
          descriptor.label,
          style: AppTextStyles.caption.copyWith(
            color: _toneText[descriptor.tone],
            fontWeight: AppFontWeights.semibold,
          ),
        ),
      ),
    );
  }
}

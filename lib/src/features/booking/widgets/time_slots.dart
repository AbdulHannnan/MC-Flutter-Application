// lib/src/features/booking/widgets/time_slots.dart — the time-slot picker. Dart
// port of the RN app's `TimeSlots.tsx`.
//
// A PRESENTATIONAL grid of tappable time chips — the calendar's counterpart for the
// *time* half of a booking. It renders one day's slots (a wrapping grid of start
// times, ~3 per row) and reports which one the user taps.
//
// PROPS-IN, EVENTS-OUT (same contract as [Calendar]): the component owns no state.
// The caller passes the [slots] to show, the [selectedSlotId] to highlight, and an
// [onSelectSlot] callback. It doesn't fetch — WHERE the slots come from (a day's
// availability) is the caller's concern.
//
// A slot with `isAvailable == false` is shown DISABLED (struck through), not hidden —
// so a busy day still reads as "these times exist, they're just taken" rather than a
// suspiciously empty grid.

import 'package:flutter/material.dart';

import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';

class TimeSlots extends StatelessWidget {
  /// The day's slots to display, in start-time order.
  final List<TimeSlot> slots;

  /// The chosen slot's id, highlighted when present.
  final String? selectedSlotId;

  /// Called with the tapped slot. Unavailable slots don't fire it.
  final ValueChanged<TimeSlot>? onSelectSlot;

  const TimeSlots({
    super.key,
    required this.slots,
    this.selectedSlotId,
    this.onSelectSlot,
  });

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.sm;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three chips per row: subtract the two inter-chip gaps, split three ways.
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final slot in slots)
              SizedBox(
                width: width,
                child: _SlotChip(
                  slot: slot,
                  selected: slot.id == selectedSlotId,
                  onPressed: () => onSelectSlot?.call(slot),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One selectable slot. Highlighted when selected; struck through and non-pressable
/// when already taken (`isAvailable == false`).
class _SlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool selected;
  final VoidCallback onPressed;

  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !slot.isAvailable;

    final Color background = selected
        ? AppColors.primary
        : disabled
            ? AppColors.surfaceAlt
            : AppColors.surface;
    final Color border = selected ? AppColors.primary : AppColors.border;
    final AppTextColor textColor = selected
        ? AppTextColor.inverse
        : disabled
            ? AppTextColor.subtle
            : AppTextColor.normal;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: border),
          ),
          child: AppText(
            formatTime(slot.start),
            variant: selected ? AppTextVariant.bodyStrong : AppTextVariant.body,
            color: textColor,
            style: disabled
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        ),
      ),
    );
  }
}

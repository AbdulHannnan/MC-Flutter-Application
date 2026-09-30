// lib/src/features/booking/screens/schedule_screen.dart — pick a date & time
// (booking step 3). Dart port of the RN app's `ScheduleScreen.tsx`.
//
// The third step of the flow (service detail → location → HERE → review). A custom
// month [Calendar] chooses the day; once a day is set, that day's slots load and the
// [TimeSlots] picker appears.
//
// STATE: the chosen slot lives on the booking DRAFT (bookingDraftProvider) so it
// survives leaving/re-entering the screen and is ready for review/checkout. The
// visible day is LOCAL UI state, seeded from the draft's slot so returning restores
// the day you were on.
//
// DATA, NOT STATE: the slots are fetched (client-side, but behind the same seam as
// the catalog) via [daySlotsProvider] and rendered through the shared [QueryBoundary]
// (loading / error / empty) — never copied into our state. The only thing we keep is
// the ONE slot the user taps.
//
// GUARD: the router's `_bookingDraftGuard` requires service + location before this
// builds, so we don't re-check here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../features/services/services.dart' show QueryBoundary;
import '../../../models/models.dart';
import '../availability_providers.dart';
import '../booking_controller.dart';
import '../widgets/calendar.dart';
import '../widgets/time_slots.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// The tapped day ("YYYY-MM-DD"). Seeds from the draft's slot so re-entering the
  /// screen reopens on the day already chosen.
  late String? _selectedDate = () {
    final slot = ref.read(bookingDraftProvider).slot;
    return slot == null ? null : toLocalIsoDate(slot.start);
  }();

  /// Changing the day invalidates any time picked on the previous day.
  void _onSelectDate(String date) {
    if (date == _selectedDate) return;
    setState(() => _selectedDate = date);
    ref.read(bookingDraftProvider.notifier).setSlot(null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedSlot =
        ref.watch(bookingDraftProvider.select((d) => d.slot));
    final date = _selectedDate;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const AppText('Choose a date', variant: AppTextVariant.h3),
                  const SizedBox(height: AppSpacing.md),
                  Calendar(
                    selectedDate: date,
                    onSelectDate: _onSelectDate,
                  ),
                  // The time picker appears only after a day is chosen.
                  if (date != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const AppText('Choose a time',
                        variant: AppTextVariant.h3),
                    const SizedBox(height: AppSpacing.md),
                    QueryBoundary<TimeSlot>(
                      query: ref.watch(daySlotsProvider(date)),
                      emptyLabel: 'No times available for this day.',
                      onRetry: () => ref.invalidate(daySlotsProvider(date)),
                      builder: (slots) => TimeSlots(
                        slots: slots,
                        selectedSlotId: selectedSlot?.id,
                        onSelectSlot: (slot) => ref
                            .read(bookingDraftProvider.notifier)
                            .setSlot(slot),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Footer(
              selectedDate: date,
              selectedSlot: selectedSlot,
              onContinue: () => context.push(AppRoutes.bookingReview),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pinned footer: the current Date/Time selection + the forward CTA (disabled
/// until a slot is chosen).
class _Footer extends StatelessWidget {
  final String? selectedDate;
  final TimeSlot? selectedSlot;
  final VoidCallback onContinue;

  const _Footer({
    required this.selectedDate,
    required this.selectedSlot,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final slot = selectedSlot;

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
              if (slot != null) ...[
                _SummaryRow(
                    label: 'Date', value: formatFullDate(selectedDate!)),
                const SizedBox(height: AppSpacing.xs),
                _SummaryRow(label: 'Time', value: formatTime(slot.start)),
                const SizedBox(height: AppSpacing.md),
              ] else ...[
                AppText(
                  selectedDate != null
                      ? 'Pick a time to continue.'
                      : 'Pick a day to continue.',
                  variant: AppTextVariant.caption,
                  color: AppTextColor.muted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: 'Continue',
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: slot != null ? onContinue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label/value line in the footer summary (Date, Time).
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

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

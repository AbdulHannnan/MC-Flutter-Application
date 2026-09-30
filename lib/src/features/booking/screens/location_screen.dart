// lib/src/features/booking/screens/location_screen.dart — pick WHERE the visit
// happens (booking step 2). Dart port of the RN app's `LocationScreen.tsx`.
//
// The second step of the AC-services flow (service detail → HERE → schedule →
// review). The user sets a delivery address by typing it and/or dropping a pin on a
// preset Dubai area via the mock [LocationPicker].
//
// STATE: the location lives on the booking DRAFT (bookingDraftProvider) so it
// survives leaving/re-entering the screen. We keep a small LOCAL editing copy and
// commit it to the draft on "Continue" — the same pattern the Schedule screen uses.
//
// GUARD: the flow starts from a service, so with no service in the draft the router's
// `_bookingDraftGuard` bounces home before this ever builds; we read the service only
// for the sub-heading.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../booking_controller.dart';
import '../widgets/location_picker.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  /// The local editing copy, seeded from whatever's already on the draft.
  late BookingLocation? _location =
      ref.read(bookingDraftProvider).location;

  /// Ready once we have a typed address OR a chosen area/pin.
  bool get _canContinue {
    final l = _location;
    return l != null &&
        (l.addressText.trim().isNotEmpty || l.area != null || l.coords != null);
  }

  void _onChange(BookingLocation next) => setState(() => _location = next);

  void _continue() {
    final l = _location;
    if (!_canContinue || l == null) return;
    ref.read(bookingDraftProvider.notifier).setLocation(
          BookingLocation(
            addressText: l.addressText.trim(),
            area: l.area,
            coords: l.coords,
            label: l.label,
          ),
        );
    context.push(AppRoutes.bookingSchedule);
  }

  @override
  Widget build(BuildContext context) {
    final serviceName = ref.watch(
      bookingDraftProvider.select((d) => d.service?.name),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const AppText('Where should we come?',
                      variant: AppTextVariant.h3),
                  const SizedBox(height: AppSpacing.xs),
                  AppText(
                    serviceName == null
                        ? 'Add the address for your visit.'
                        : 'Add the address for your ${serviceName.toLowerCase()} visit.',
                    color: AppTextColor.muted,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LocationPicker(value: _location, onChange: _onChange),
                ],
              ),
            ),
            _Footer(canContinue: _canContinue, onContinue: _continue),
          ],
        ),
      ),
    );
  }
}

/// The pinned footer: a hint until an address/area is set, then the Continue CTA.
class _Footer extends StatelessWidget {
  final bool canContinue;
  final VoidCallback onContinue;

  const _Footer({required this.canContinue, required this.onContinue});

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
              if (!canContinue) ...[
                const AppText(
                  'Enter an address or pick an area to continue.',
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
                onPressed: canContinue ? onContinue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

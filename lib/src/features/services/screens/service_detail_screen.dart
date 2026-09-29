// lib/src/features/services/screens/service_detail_screen.dart — the
// "/service/:id" route: one service, and the START of the booking flow. Dart port
// of the RN app's `ServiceDetailScreen.tsx` (Module 11).
//
// Two selections:
//   • OPTION  — single-select sub-service (radio). A service with no options is
//     booked as-is at its base price.
//   • ADD-ONS — multi-select extras (checkboxes) on top.
// The pinned footer's total updates with the chosen option AND ticked add-ons.
//
// FIRST STEP OF THE FLOW: "Continue" doesn't add to the cart — it STARTS a booking
// draft (service + option + add-ons) and pushes to the Location step. When we
// arrived here via "Edit" from Review (the draft already holds THIS service), the
// selections are pre-seeded and the location/slot/notes already chosen are kept.
//
// A single service is an object (not a list), so loading/error are handled inline
// via LoadingState/ErrorState rather than the list-shaped QueryBoundary.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/format/duration.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../features/booking/booking.dart';
import '../../../models/models.dart';
import '../catalog_providers.dart';

class ServiceDetailScreen extends ConsumerWidget {
  final String serviceId;

  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceProvider(serviceId));

    return service.when(
      loading: () => const Scaffold(body: SafeArea(child: LoadingState())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ErrorState(
            title: 'Service unavailable',
            description:
                "We couldn't load this service. It may have been removed.",
            onRetry: () => ref.invalidate(serviceProvider(serviceId)),
          ),
        ),
      ),
      // Split into its own stateful widget so the selection state initialises
      // only once we actually have a service (mirrors RN's inner ServiceDetail).
      data: (data) => _ServiceDetailView(service: data),
    );
  }
}

class _ServiceDetailView extends ConsumerStatefulWidget {
  final Service service;
  const _ServiceDetailView({required this.service});

  @override
  ConsumerState<_ServiceDetailView> createState() => _ServiceDetailViewState();
}

class _ServiceDetailViewState extends ConsumerState<_ServiceDetailView> {
  Service get _service => widget.service;
  bool get _hasOptions => _service.options.isNotEmpty;
  bool get _hasAddons => _service.addons.isNotEmpty;

  /// Are we editing this same service (arrived via "Edit" from Review)? Captured
  /// once — the draft doesn't change while we're on this screen.
  late final bool _isEditing;

  /// Chosen option id; '' means "no option applicable" (booked at base price).
  late String _selectedOptionId;

  /// Ticked add-on ids, kept as a set for quick lookup.
  late final Set<String> _selectedAddonIds;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _isEditing = draft.service?.id == _service.id;

    _selectedOptionId = _isEditing && draft.option != null
        ? draft.option!.id
        : _hasOptions
        ? _service.options.first.id
        : '';

    _selectedAddonIds = _isEditing
        ? draft.addons.map((a) => a.id).toSet()
        : <String>{};
  }

  ServiceOption? get _selectedOption {
    for (final o in _service.options) {
      if (o.id == _selectedOptionId) return o;
    }
    return null;
  }

  List<ServiceAddon> get _selectedAddons =>
      _service.addons.where((a) => _selectedAddonIds.contains(a.id)).toList();

  Money get _price {
    final base = _selectedOption?.price ?? _service.basePrice;
    return _selectedAddons.fold<Money>(base, (sum, a) => sum + a.price);
  }

  int get _duration {
    final base = _selectedOption?.duration ?? _service.duration;
    return _selectedAddons.fold<int>(base, (sum, a) => sum + (a.duration ?? 0));
  }

  void _toggleAddon(String id) {
    setState(() {
      _selectedAddonIds.contains(id)
          ? _selectedAddonIds.remove(id)
          : _selectedAddonIds.add(id);
    });
  }

  void _continue() {
    final controller = ref.read(bookingDraftProvider.notifier);
    if (_isEditing) {
      // Same service — keep the location/slot/notes, apply the (maybe changed)
      // option + add-ons.
      controller.setOption(_selectedOption);
      controller.setAddons(_selectedAddons);
    } else {
      // A fresh service — start a clean draft.
      controller.start(_service, _selectedOption);
      controller.setAddons(_selectedAddons);
    }
    context.push(AppRoutes.bookingLocation);
  }

  @override
  Widget build(BuildContext context) {
    final uri = _service.image?.uri;
    final selectedCount = _selectedAddons.length;

    // Footer caption mirrors RN: extras count, else "Selected" when options exist,
    // else "Price".
    final footerLabel = selectedCount > 0
        ? 'Total · $selectedCount extra${selectedCount > 1 ? 's' : ''}'
        : _hasOptions
        ? 'Selected'
        : 'Price';

    return Scaffold(
      appBar: AppBar(title: Text(_service.name)),
      // The footer is the last child of a Column (not `bottomNavigationBar`): the
      // Expanded list feeds it UNBOUNDED vertical constraints, so its button sizes
      // to its content rather than stretching to fill the slot.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Hero image.
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: uri == null
                        ? const ColoredBox(color: AppColors.surfaceAlt)
                        : Image.network(
                            uri,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: AppColors.surfaceAlt),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(_service.name, variant: AppTextVariant.h2),
                        // Duration only when known (>0) — live backend gives none.
                        if (_duration > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          AppText(
                            formatDuration(_duration),
                            variant: AppTextVariant.caption,
                            color: AppTextColor.muted,
                          ),
                        ],
                        if (_service.description != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          AppText(
                            _service.description!,
                            color: AppTextColor.muted,
                          ),
                        ],

                        // Sub-service selection (single-select).
                        if (_hasOptions) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const AppText(
                            'Choose an option',
                            variant: AppTextVariant.subheading,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final option in _service.options) ...[
                            _OptionRow(
                              option: option,
                              selected: option.id == _selectedOptionId,
                              onSelect: () =>
                                  setState(() => _selectedOptionId = option.id),
                            ),
                            if (option != _service.options.last)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                        ],

                        // Add-ons (multi-select).
                        if (_hasAddons) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const AppText(
                            'Add extras',
                            variant: AppTextVariant.subheading,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final addon in _service.addons) ...[
                            _AddonRow(
                              addon: addon,
                              selected: _selectedAddonIds.contains(addon.id),
                              onToggle: () => _toggleAddon(addon.id),
                            ),
                            if (addon != _service.addons.last)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Pinned footer: running total + forward CTA.
            _Footer(label: footerLabel, price: _price, onContinue: _continue),
          ],
        ),
      ),
    );
  }
}

/// The pinned bottom bar: current price (option + extras) and the Continue CTA.
class _Footer extends StatelessWidget {
  final String label;
  final Money price;
  final VoidCallback onContinue;

  const _Footer({
    required this.label,
    required this.price,
    required this.onContinue,
  });

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
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    label,
                    variant: AppTextVariant.caption,
                    color: AppTextColor.muted,
                  ),
                  AppText(price.format(), variant: AppTextVariant.h3),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Continue',
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single-select option row (radio-style). Local to this screen.
class _OptionRow extends StatelessWidget {
  final ServiceOption option;
  final bool selected;
  final VoidCallback onSelect;

  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '${option.name}, ${option.price.format()}',
      child: GestureDetector(
        onTap: onSelect,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _RadioDot(selected: selected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(option.name, variant: AppTextVariant.bodyStrong),
                    if (option.duration > 0)
                      AppText(
                        formatDuration(option.duration),
                        variant: AppTextVariant.caption,
                        color: AppTextColor.muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppText(
                option.price.format(),
                variant: AppTextVariant.bodyStrong,
                color: selected ? AppTextColor.primary : AppTextColor.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderStrong,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

/// A multi-select add-on row (checkbox-style). Local to this screen.
class _AddonRow extends StatelessWidget {
  final ServiceAddon addon;
  final bool selected;
  final VoidCallback onToggle;

  const _AddonRow({
    required this.addon,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      label: '${addon.name}, ${addon.price.format()}',
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _CheckBox(selected: selected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(addon.name, variant: AppTextVariant.bodyStrong),
                    if (addon.description != null)
                      AppText(
                        addon.description!,
                        variant: AppTextVariant.caption,
                        color: AppTextColor.muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppText(
                '+${addon.price.format()}',
                variant: AppTextVariant.bodyStrong,
                color: selected ? AppTextColor.primary : AppTextColor.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool selected;
  const _CheckBox({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: AppRadii.smAll,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderStrong,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: AppColors.primaryText)
          : null,
    );
  }
}

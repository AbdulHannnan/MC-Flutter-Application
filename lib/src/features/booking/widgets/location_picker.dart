// lib/src/features/booking/widgets/location_picker.dart — the (mock) map location
// picker. Dart port of the RN app's `LocationPicker.tsx`.
//
// Lets the user set WHERE the AC visit happens, three ways:
//   • type a free-text address,
//   • tap a preset Dubai-area chip (drops the pin at that area), or
//   • "Use my current location" (a mock that drops a default Dubai pin).
//
// MOCK MAP, REAL SHAPE: the "map" is a styled panel with a pin — NOT a live Google
// Map (the app is mock-data driven, and web has no native maps). Crucially it
// produces a real [BookingLocation] ({ addressText, area?, coords? }), so dropping in
// a real maps SDK later means rewriting only THIS widget.
//
// CONTROLLED: the screen owns the value and passes [value] + [onChange]; this widget
// renders it and reports edits back. The address field is a controlled TextField, so
// we keep a local [TextEditingController] and re-sync it when the value's address is
// changed programmatically (the "use current location" case).

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../data/dubai_areas.dart';

/// The mock "current location" — a sensible default Dubai pin (first preset area).
final DubaiArea _mockCurrent = kDubaiAreas[0];

class LocationPicker extends StatefulWidget {
  final BookingLocation? value;
  final ValueChanged<BookingLocation> onChange;

  const LocationPicker({super.key, this.value, required this.onChange});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late final TextEditingController _address =
      TextEditingController(text: widget.value?.addressText ?? '');

  @override
  void didUpdateWidget(LocationPicker old) {
    super.didUpdateWidget(old);
    // Re-sync the controller only when the address changed from OUTSIDE (e.g. "use
    // current location" filled it) — never on the user's own keystrokes, which
    // would fight the cursor.
    final text = widget.value?.addressText ?? '';
    if (text != _address.text) _address.text = text;
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  /// Merge a partial change onto the current value (addressText always present).
  void _update({String? addressText, String? area, LatLng? coords, String? label}) {
    final current = widget.value;
    widget.onChange(BookingLocation(
      addressText: addressText ?? current?.addressText ?? '',
      area: area ?? current?.area,
      coords: coords ?? current?.coords,
      label: label ?? current?.label,
    ));
  }

  void _selectArea(DubaiArea area) =>
      _update(area: area.name, coords: area.coords);

  void _useCurrentLocation() {
    final text = widget.value?.addressText ?? '';
    widget.onChange(BookingLocation(
      addressText: text.isNotEmpty ? text : '${_mockCurrent.name}, Dubai',
      area: _mockCurrent.name,
      coords: _mockCurrent.coords,
      label: 'Current location',
    ));
  }

  String? get _pinLabel {
    final v = widget.value;
    if (v?.area != null) return v!.area;
    final c = v?.coords;
    if (c != null) {
      return '${c.lat.toStringAsFixed(3)}, ${c.lng.toStringAsFixed(3)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedArea = widget.value?.area;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mock map panel with a pin ──
        ClipRRect(
          borderRadius: AppRadii.lgAll,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadii.lgAll,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const ColoredBox(
                        color: AppColors.primarySoft,
                        child: SizedBox.expand(),
                      ),
                      // Faint decorative "roads" to suggest a map.
                      const Positioned(
                          left: 0, right: 0, top: 60, child: _RoadLine()),
                      const Positioned(
                          left: 0, right: 0, top: 120, child: _RoadLine()),
                      const Positioned(
                          top: 0, bottom: 0, left: 90, child: _RoadLine(vertical: true)),
                      const Positioned(
                          top: 0, bottom: 0, right: 70, child: _RoadLine(vertical: true)),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: AppSpacing.xs),
                          AppText(
                            _pinLabel != null
                                ? 'Pin: $_pinLabel'
                                : 'Choose an area to drop a pin',
                            variant: AppTextVariant.caption,
                            color: AppTextColor.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Semantics(
                    button: true,
                    label: 'Use my current location',
                    child: GestureDetector(
                      onTap: _useCurrentLocation,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🎯'),
                            SizedBox(width: AppSpacing.sm),
                            AppText('Use my current location',
                                variant: AppTextVariant.caption,
                                color: AppTextColor.primary,
                                style: TextStyle(
                                    fontWeight: AppFontWeights.semibold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Address text ──
        AppTextField(
          label: 'Address',
          controller: _address,
          onChanged: (text) => _update(addressText: text),
          hintText: 'Building / villa, street, apartment no.',
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Preset Dubai areas ──
        const AppText('POPULAR AREAS',
            variant: AppTextVariant.caption, color: AppTextColor.muted),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final area in kDubaiAreas) ...[
                _AreaChip(
                  name: area.name,
                  selected: selectedArea == area.name,
                  onPressed: () => _selectArea(area),
                ),
                if (area != kDubaiAreas.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A faint decorative line in the mock map (horizontal by default).
class _RoadLine extends StatelessWidget {
  final bool vertical;
  const _RoadLine({this.vertical = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: SizedBox(
        width: vertical ? 1 : null,
        height: vertical ? null : 1,
        child: const ColoredBox(color: AppColors.borderStrong),
      ),
    );
  }
}

/// A pill-shaped preset-area chip.
class _AreaChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onPressed;

  const _AreaChip({
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: AppRadii.pillAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
            ),
          ),
          child: AppText(
            name,
            variant: AppTextVariant.caption,
            color: selected ? AppTextColor.inverse : AppTextColor.normal,
            style: const TextStyle(fontWeight: AppFontWeights.medium),
          ),
        ),
      ),
    );
  }
}

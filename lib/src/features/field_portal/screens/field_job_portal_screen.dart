// lib/src/features/field_portal/screens/field_job_portal_screen.dart — the Field
// Job Portal FORM. Module 2: the fields + the live Generated Job Number, reachable
// from the technician area. NO submit and NO photo capture yet (Modules 3–4).
//
// TEMPORARY FEATURE (see FIELD_PORTAL_REMOVAL.md). Self-contained under
// lib/src/features/field_portal/. It only READS the existing technician session (to
// pre-fill the technician's name) and reuses the shared design-system widgets — it
// modifies nothing in the technician-jobs code.
//
// Fields: Month (dropdown) · Team (dropdown) · Job Number (number) · Generated Job
// Number (read-only, live) · Technician Name (text, pre-filled). The generated
// number rebuilds on every change via [buildGeneratedJobNumber].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../technician/technician_session.dart';
import '../field_job_form.dart';

class FieldJobPortalScreen extends ConsumerStatefulWidget {
  const FieldJobPortalScreen({super.key});

  @override
  ConsumerState<FieldJobPortalScreen> createState() =>
      _FieldJobPortalScreenState();
}

class _FieldJobPortalScreenState extends ConsumerState<FieldJobPortalScreen> {
  final _technicianName = TextEditingController();
  final _sequence = TextEditingController();

  FieldMonth? _month;
  FieldTeam? _team;

  @override
  void initState() {
    super.initState();
    // Pre-fill the technician's name from the signed-in profile (editable).
    final tech = ref.read(technicianSessionProvider).technician;
    _technicianName.text = tech?.name ?? '';
  }

  @override
  void dispose() {
    _technicianName.dispose();
    _sequence.dispose();
    super.dispose();
  }

  /// The parsed Job Number (null when blank / non-positive).
  int? get _sequenceValue {
    final n = int.tryParse(_sequence.text.trim());
    return (n != null && n > 0) ? n : null;
  }

  String get _generatedNumber => buildGeneratedJobNumber(
        month: _month,
        team: _team,
        sequence: _sequenceValue,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Field Job Portal',
            variant: AppTextVariant.subheading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const AppText('New field job', variant: AppTextVariant.h2),
            const SizedBox(height: AppSpacing.xs),
            const AppText(
              'Fill in the job details. The job number is generated for you.',
              color: AppTextColor.muted,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Month
            _Dropdown<FieldMonth>(
              label: 'Month',
              hint: 'Select month',
              value: _month,
              items: FieldMonth.values,
              labelOf: (m) => m.label,
              onChanged: (m) => setState(() => _month = m),
            ),
            const SizedBox(height: AppSpacing.md),

            // Team
            _Dropdown<FieldTeam>(
              label: 'Team',
              hint: 'Select team',
              value: _team,
              items: FieldTeam.values,
              labelOf: (t) => t.label,
              onChanged: (t) => setState(() => _team = t),
            ),
            const SizedBox(height: AppSpacing.md),

            // Job Number (sequence)
            AppTextField(
              label: 'Job Number',
              hintText: 'e.g. 5',
              controller: _sequence,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              // Digits only; the generated preview updates on every keystroke.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),

            // Generated Job Number (read-only, live)
            _GeneratedNumberField(value: _generatedNumber),
            const SizedBox(height: AppSpacing.md),

            // Technician Name
            AppTextField(
              label: 'Technician Name',
              hintText: 'Your name',
              controller: _technicianName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Photo capture (Module 3) and submit (Module 4) are added next.
            const AppButton(
              label: 'Submit field job',
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: null, // wired in Module 4 (after the backend is deployed)
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppText(
              'Before/after photos and submit are added in the next steps.',
              variant: AppTextVariant.caption,
              color: AppTextColor.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The read-only, live Generated Job Number — styled like a disabled field so it
/// reads as output, not input.
class _GeneratedNumberField extends StatelessWidget {
  const _GeneratedNumberField({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('Generated Job Number', variant: AppTextVariant.caption),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: AppText(
            value,
            variant: AppTextVariant.subheading,
            style: const TextStyle(letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }
}

/// A labelled dropdown styled to match [AppTextField].
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, variant: AppTextVariant.caption),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          style: AppTextStyles.body,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          hint: AppText(hint,
              color: AppTextColor.subtle, variant: AppTextVariant.body),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            enabledBorder: border(AppColors.border),
            focusedBorder: border(AppColors.primary, width: 1.5),
            border: border(AppColors.border),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: AppText(labelOf(item)),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

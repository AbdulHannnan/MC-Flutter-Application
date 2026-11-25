// lib/src/features/field_portal/screens/field_job_portal_screen.dart — the Field
// Job Portal FORM + submit + success confirmation.
//
// TEMPORARY FEATURE (see FIELD_PORTAL_REMOVAL.md). Self-contained under
// lib/src/features/field_portal/. It READS the technician session (pre-fill the
// name) and reuses the shared design-system widgets + the proven image_picker /
// PhotoUpload approach — pointed at the NEW field-jobs function + field-job-photos
// bucket. It modifies nothing in the technician-jobs code.
//
// Fields: Month · Team · Job Number · Generated Job Number (read-only, live) ·
// Technician Name (pre-filled) · Before/After photos (multi-pick, optional). Submit
// creates the field job + uploads the photos in one request; on success the screen
// swaps to a confirmation showing the generated number (no extra route).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/widgets/form_error_banner.dart';
import '../../technician/data/technician_api.dart' show PhotoUpload;
import '../../technician/technician_session.dart';
import '../data/field_job_api.dart';
import '../field_job_form.dart';

class FieldJobPortalScreen extends ConsumerStatefulWidget {
  const FieldJobPortalScreen({super.key});

  @override
  ConsumerState<FieldJobPortalScreen> createState() =>
      _FieldJobPortalScreenState();
}

class _FieldJobPortalScreenState extends ConsumerState<FieldJobPortalScreen> {
  final ImagePicker _picker = ImagePicker();
  final _technicianName = TextEditingController();
  final _sequence = TextEditingController();

  FieldMonth? _month;
  FieldTeam? _team;
  final List<PhotoUpload> _before = [];
  final List<PhotoUpload> _after = [];

  bool _submitting = false;
  String? _formError;
  String? _monthError;
  String? _teamError;
  String? _sequenceError;
  String? _nameError;

  /// Non-null once a submit has succeeded — the screen then shows the confirmation.
  SubmittedFieldJob? _result;

  // At most 10 photos per kind (the function also enforces this).
  static const int _maxPerKind = 10;

  @override
  void initState() {
    super.initState();
    final tech = ref.read(technicianSessionProvider).technician;
    _technicianName.text = tech?.name ?? '';
  }

  @override
  void dispose() {
    _technicianName.dispose();
    _sequence.dispose();
    super.dispose();
  }

  int? get _sequenceValue {
    final n = int.tryParse(_sequence.text.trim());
    return (n != null && n > 0) ? n : null;
  }

  String get _generatedNumber => buildGeneratedJobNumber(
        month: _month,
        team: _team,
        sequence: _sequenceValue,
      );

  Future<void> _pickPhotos(PhotoKindSlot slot) async {
    final list = slot == PhotoKindSlot.before ? _before : _after;
    final remaining = _maxPerKind - list.length;
    if (remaining <= 0) {
      _toast('You can attach up to $_maxPerKind ${slot.label} photos.');
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 70, maxWidth: 1600);
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining);
    for (final x in toAdd) {
      final bytes = await x.readAsBytes();
      list.add(PhotoUpload(
        bytes: bytes,
        filename: x.name,
        contentType: _contentTypeFor(x),
      ));
    }
    if (picked.length > remaining) {
      _toast('Only $_maxPerKind ${slot.label} photos allowed; extras were skipped.');
    }
    if (mounted) setState(() {});
  }

  void _removePhoto(PhotoKindSlot slot, int index) {
    setState(() {
      (slot == PhotoKindSlot.before ? _before : _after).removeAt(index);
    });
  }

  Future<void> _submit() async {
    final month = _month;
    final team = _team;
    final sequence = _sequenceValue;
    final name = _technicianName.text.trim();

    setState(() {
      _monthError = month == null ? 'Select a month.' : null;
      _teamError = team == null ? 'Select a team.' : null;
      _sequenceError = sequence == null ? 'Enter a job number (1 or more).' : null;
      _nameError = name.isEmpty ? 'Technician name is required.' : null;
      _formError = null;
    });
    if (month == null || team == null || sequence == null || name.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final result = await ref.read(fieldJobApiProvider).submit(
            month: month,
            team: team,
            sequence: sequence,
            technicianName: name,
            before: _before,
            after: _after,
          );
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Reset for another submission (keeps the pre-filled technician name).
  void _reset() {
    setState(() {
      _month = null;
      _team = null;
      _sequence.clear();
      _before.clear();
      _after.clear();
      _formError = null;
      _monthError = _teamError = _sequenceError = _nameError = null;
      _result = null;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _contentTypeFor(XFile x) {
    final mime = x.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = x.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    if (name.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Field Job Portal',
            variant: AppTextVariant.subheading),
      ),
      body: SafeArea(
        child: _result != null
            ? _SuccessView(result: _result!, onAnother: _reset)
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppText('New field job', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        const AppText(
          'Fill in the job details. The job number is generated for you.',
          color: AppTextColor.muted,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (_formError != null) ...[
          FormErrorBanner(message: _formError!),
          const SizedBox(height: AppSpacing.md),
        ],

        _Dropdown<FieldMonth>(
          label: 'Month',
          hint: 'Select month',
          value: _month,
          items: FieldMonth.values,
          labelOf: (m) => m.label,
          errorText: _monthError,
          onChanged: (m) => setState(() {
            _month = m;
            _monthError = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),

        _Dropdown<FieldTeam>(
          label: 'Team',
          hint: 'Select team',
          value: _team,
          items: FieldTeam.values,
          labelOf: (t) => t.label,
          errorText: _teamError,
          onChanged: (t) => setState(() {
            _team = t;
            _teamError = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),

        AppTextField(
          key: const Key('field_job_sequence'),
          label: 'Job Number',
          hintText: 'e.g. 5',
          controller: _sequence,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          errorText: _sequenceError,
          onChanged: (_) => setState(() => _sequenceError = null),
        ),
        const SizedBox(height: AppSpacing.md),

        _GeneratedNumberField(value: _generatedNumber),
        const SizedBox(height: AppSpacing.md),

        AppTextField(
          key: const Key('field_job_name'),
          label: 'Technician Name',
          hintText: 'Your name',
          controller: _technicianName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          errorText: _nameError,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        _PhotoPicker(
          slot: PhotoKindSlot.before,
          photos: _before,
          onAdd: () => _pickPhotos(PhotoKindSlot.before),
          onRemove: (i) => _removePhoto(PhotoKindSlot.before, i),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PhotoPicker(
          slot: PhotoKindSlot.after,
          photos: _after,
          onAdd: () => _pickPhotos(PhotoKindSlot.after),
          onRemove: (i) => _removePhoto(PhotoKindSlot.after, i),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: 'Submit field job',
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Which photo group a pick targets.
enum PhotoKindSlot {
  before,
  after;

  String get label => name; // 'before' | 'after'
  String get title => this == PhotoKindSlot.before ? 'Before' : 'After';
}

/// The success confirmation shown in place of the form after a submit.
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result, required this.onAnother});

  final SubmittedFieldJob result;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft,
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 44, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Center(
          child: AppText('Field job submitted', variant: AppTextVariant.h2),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Center(
          child: AppText(
            'Saved for the CRM team. Your job number is:',
            color: AppTextColor.muted,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: AppText(
            result.generatedNumber,
            variant: AppTextVariant.h2,
            color: AppTextColor.primary,
            style: const TextStyle(letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Submit another',
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: onAnother,
        ),
      ],
    );
  }
}

/// A before/after photo group: local thumbnails (from picked bytes) + an add tile.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.slot,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final PhotoKindSlot slot;
  final List<PhotoUpload> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('${slot.title} photos (${photos.length})',
            variant: AppTextVariant.caption),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                _LocalThumb(
                  bytes: photos[i].bytes,
                  onRemove: () => onRemove(i),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _AddTile(onTap: onAdd),
            ],
          ),
        ),
      ],
    );
  }
}

/// A local (not-yet-uploaded) photo thumbnail with a remove badge.
class _LocalThumb extends StatelessWidget {
  const _LocalThumb({required this.bytes, required this.onRemove});
  final List<int> bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppRadii.mdAll,
          child: Image.memory(
            Uint8List.fromList(bytes),
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xCC000000),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.mdAll,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// The read-only, live Generated Job Number — styled like a disabled field.
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

/// A labelled dropdown styled to match [AppTextField], with an optional error line.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
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
            enabledBorder: border(hasError ? AppColors.danger : AppColors.border),
            focusedBorder: border(
                hasError ? AppColors.danger : AppColors.primary,
                width: 1.5),
            border: border(hasError ? AppColors.danger : AppColors.border),
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
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          AppText(errorText!,
              variant: AppTextVariant.caption, color: AppTextColor.danger),
        ],
      ],
    );
  }
}

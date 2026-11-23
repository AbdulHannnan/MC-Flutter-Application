// lib/src/features/technician/screens/technician_job_detail_screen.dart — one
// job's full detail, its before/after photos, and its lifecycle actions.
//
// Data: technicianJobProvider(id) for the job, jobPhotosProvider(id) for the
// photos (a separate call — only it returns the short-lived signed URLs for the
// private objects). Actions, keyed off jobStatus:
//   ASSIGNED      → "Acknowledge job"
//   ACKNOWLEDGED  → "Start job" (→ IN_PROGRESS); photo capture enabled
//   IN_PROGRESS   → photo capture + "Mark as done" (enabled once there is ≥1
//                   before AND ≥1 after photo — the server also enforces this)
//   DONE          → photos read-only, no actions
// In-flight / error UI is owned here (button spinner + SnackBar carrying the
// server's message, e.g. a 409); data stays visible during refetches.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format/date_time.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asset_url.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/technician_api.dart';
import '../data/technician_job.dart';
import '../jobs_providers.dart';
import '../widgets/job_status_pill.dart';

class TechnicianJobDetailScreen extends ConsumerStatefulWidget {
  const TechnicianJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<TechnicianJobDetailScreen> createState() =>
      _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState
    extends ConsumerState<TechnicianJobDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _submitting = false; // a status transition is in flight
  PhotoKind? _uploadingKind; // a photo upload is in flight (which kind)

  String get _id => widget.jobId;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _submitting = true);
    try {
      await action();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _acknowledge() =>
      _run(() => ref.read(jobActionsProvider).acknowledge(_id));
  void _start() =>
      _run(() => ref.read(jobActionsProvider).setStatus(_id, JobStatus.inProgress));
  void _markDone() =>
      _run(() => ref.read(jobActionsProvider).setStatus(_id, JobStatus.done));

  Future<void> _addPhoto(PhotoKind kind) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null) return; // cancelled

    setState(() => _uploadingKind = kind);
    try {
      final bytes = await picked.readAsBytes();
      final upload = PhotoUpload(
        bytes: bytes,
        filename: picked.name,
        contentType: _contentTypeFor(picked),
      );
      await ref.read(jobActionsProvider).uploadPhotos(_id, kind, [upload]);
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not upload the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingKind = null);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(technicianJobProvider(_id));
    final photos = ref.watch(jobPhotosProvider(_id));

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Job detail', variant: AppTextVariant.subheading),
      ),
      body: SafeArea(
        // Footer pinned via Expanded(list) + trailing bar (not a
        // bottomNavigationBar, which collapses the list's height here).
        child: job.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingState(),
          error: (_, _) => ErrorState(
            onRetry: () => ref.invalidate(technicianJobProvider(_id)),
          ),
          data: (j) => Column(
            children: [
              Expanded(
                child: _JobDetail(
                  job: j,
                  photos: photos,
                  canUpload: _canUpload(j.jobStatus),
                  uploadingKind: _uploadingKind,
                  onAddPhoto: _addPhoto,
                ),
              ),
              _ActionBar(
                status: j.jobStatus,
                submitting: _submitting,
                canMarkDone: _hasBeforeAndAfter(photos),
                onAcknowledge: _acknowledge,
                onStart: _start,
                onMarkDone: _markDone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _canUpload(JobStatus s) =>
      s == JobStatus.acknowledged || s == JobStatus.inProgress;

  static bool _hasBeforeAndAfter(AsyncValue<List<JobPhoto>> photos) =>
      photos.maybeWhen(
        data: (list) =>
            list.any((p) => p.kind == PhotoKind.before) &&
            list.any((p) => p.kind == PhotoKind.after),
        orElse: () => false,
      );

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
}

/// The pinned action for the job's current status.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.status,
    required this.submitting,
    required this.canMarkDone,
    required this.onAcknowledge,
    required this.onStart,
    required this.onMarkDone,
  });

  final JobStatus status;
  final bool submitting;
  final bool canMarkDone;
  final VoidCallback onAcknowledge;
  final VoidCallback onStart;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final Widget? inner = switch (status) {
      JobStatus.assigned => AppButton(
          label: 'Acknowledge job',
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: submitting,
          onPressed: onAcknowledge,
        ),
      JobStatus.acknowledged => AppButton(
          label: 'Start job',
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: submitting,
          onPressed: onStart,
        ),
      JobStatus.inProgress => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Mark as done',
              size: AppButtonSize.lg,
              fullWidth: true,
              loading: submitting,
              // The server also enforces this; the gate is just clearer UX.
              onPressed: canMarkDone ? onMarkDone : null,
            ),
            if (!canMarkDone) ...[
              const SizedBox(height: AppSpacing.xs),
              const AppText(
                'Add at least one before and one after photo to finish.',
                variant: AppTextVariant.caption,
                color: AppTextColor.muted,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      _ => null, // DONE / UNASSIGNED — nothing to do
    };

    if (inner == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: inner,
    );
  }
}

class _JobDetail extends StatelessWidget {
  const _JobDetail({
    required this.job,
    required this.photos,
    required this.canUpload,
    required this.uploadingKind,
    required this.onAddPhoto,
  });

  final TechnicianJob job;
  final AsyncValue<List<JobPhoto>> photos;
  final bool canUpload;
  final PhotoKind? uploadingKind;
  final void Function(PhotoKind kind) onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final when = job.scheduledDate != null
        ? '${formatFullDate(toLocalIsoDate(job.scheduledDate!))}'
            '${job.scheduledTime != null ? '\n${job.scheduledTime}' : ''}'
        : 'Not scheduled';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: AppText(job.serviceName, variant: AppTextVariant.h2)),
            const SizedBox(width: AppSpacing.sm),
            JobStatusPill(status: job.jobStatus),
          ],
        ),
        if (job.reference != null) ...[
          const SizedBox(height: AppSpacing.xs),
          AppText('Ref ${job.reference}',
              variant: AppTextVariant.caption, color: AppTextColor.muted),
        ],
        const SizedBox(height: AppSpacing.lg),

        _Section(title: 'When', child: AppText(when)),
        _Section(
          title: 'Where',
          child: AppText(
            (job.address?.isNotEmpty ?? false) ? job.address! : 'No address',
          ),
        ),
        _Section(
          title: 'Customer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(job.contactName ?? '—'),
              if (job.contactPhone != null && job.contactPhone!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                AppText(job.contactPhone!, color: AppTextColor.muted),
              ],
            ],
          ),
        ),
        _Section(
          title: 'Service',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (job.serviceOption != null)
                _LineRow(label: job.serviceOption!.label, trailing: null),
              if (job.quantity != null)
                _LineRow(label: 'Quantity', trailing: '${job.quantity}'),
              for (final a in job.addons)
                _LineRow(
                  label: '${a.addonName}${a.quantity > 1 ? ' ×${a.quantity}' : ''}',
                  trailing: a.lineTotal.format(),
                ),
              if (job.total != null) ...[
                const Divider(height: AppSpacing.lg),
                _LineRow(
                    label: 'Total', trailing: job.total!.format(), strong: true),
              ],
            ],
          ),
        ),
        if (job.notes != null && job.notes!.trim().isNotEmpty)
          _Section(title: 'Notes', child: AppText(job.notes!.trim())),

        _PhotosSection(
          photos: photos,
          canUpload: canUpload,
          uploadingKind: uploadingKind,
          onAddPhoto: onAddPhoto,
        ),
      ],
    );
  }
}

/// Before/after photo groups with (when the job is in an uploadable state) an
/// "Add" button per kind. Thumbnails use the signed URL (private bucket) and fall
/// back to assetUrl for a relative path.
class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.photos,
    required this.canUpload,
    required this.uploadingKind,
    required this.onAddPhoto,
  });

  final AsyncValue<List<JobPhoto>> photos;
  final bool canUpload;
  final PhotoKind? uploadingKind;
  final void Function(PhotoKind kind) onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Photos',
      child: photos.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingState(compact: true),
        error: (_, _) => const AppText('Could not load photos.',
            variant: AppTextVariant.caption, color: AppTextColor.muted),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotoGroup(
              kind: PhotoKind.before,
              photos: list.where((p) => p.kind == PhotoKind.before).toList(),
              canUpload: canUpload,
              uploading: uploadingKind == PhotoKind.before,
              onAdd: () => onAddPhoto(PhotoKind.before),
            ),
            const SizedBox(height: AppSpacing.md),
            _PhotoGroup(
              kind: PhotoKind.after,
              photos: list.where((p) => p.kind == PhotoKind.after).toList(),
              canUpload: canUpload,
              uploading: uploadingKind == PhotoKind.after,
              onAdd: () => onAddPhoto(PhotoKind.after),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGroup extends StatelessWidget {
  const _PhotoGroup({
    required this.kind,
    required this.photos,
    required this.canUpload,
    required this.uploading,
    required this.onAdd,
  });

  final PhotoKind kind;
  final List<JobPhoto> photos;
  final bool canUpload;
  final bool uploading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final label = kind == PhotoKind.before ? 'Before' : 'After';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('$label (${photos.length})', variant: AppTextVariant.bodyStrong),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in photos) ...[
                _Thumb(photo: p),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (canUpload) _AddTile(uploading: uploading, onTap: onAdd),
              if (!canUpload && photos.isEmpty)
                const AppText('None', color: AppTextColor.muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});
  final JobPhoto photo;

  @override
  Widget build(BuildContext context) {
    final uri = photo.signedUrl ?? assetUrl(photo.url);
    return ClipRRect(
      borderRadius: AppRadii.mdAll,
      child: SizedBox(
        width: 88,
        height: 88,
        child: uri == null
            ? const ColoredBox(color: AppColors.surfaceAlt)
            : Image.network(uri, fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.surfaceAlt)),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.uploading, required this.onTap});
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: AppRadii.mdAll,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: uploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title.toUpperCase(),
              variant: AppTextVariant.caption, color: AppTextColor.muted),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.label, this.trailing, this.strong = false});
  final String label;
  final String? trailing;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final variant = strong ? AppTextVariant.bodyStrong : AppTextVariant.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      child: Row(
        children: [
          Expanded(child: AppText(label, variant: variant)),
          if (trailing != null) AppText(trailing!, variant: variant),
        ],
      ),
    );
  }
}

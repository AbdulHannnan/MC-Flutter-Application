// lib/src/features/technician/screens/technician_job_detail_screen.dart — one
// job's full detail + its lifecycle actions.
//
// Reads technicianJobProvider(id) for the data and drives the job forward with the
// bottom action bar, keyed off jobStatus:
//   ASSIGNED      → "Acknowledge job"  (acknowledge)
//   ACKNOWLEDGED  → "Start job"        (status → IN_PROGRESS)
//   IN_PROGRESS   → (photos + "Mark done" land in the next module)
//   DONE          → no action
// The action's in-flight / error UI is owned here (a button spinner + a SnackBar
// carrying the server's message, e.g. a 409 wrong-transition); on success the
// providers are refreshed so the status + button update. The data stays visible
// during that refetch (skipLoadingOnReload).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_time.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asset_url.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
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
  bool _submitting = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _submitting = true);
    try {
      await action();
      // Providers are invalidated inside JobActions → the job refetches and the
      // status/button update; nothing else to do here.
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _acknowledge() =>
      _run(() => ref.read(jobActionsProvider).acknowledge(widget.jobId));

  void _start() => _run(() =>
      ref.read(jobActionsProvider).setStatus(widget.jobId, JobStatus.inProgress));

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(technicianJobProvider(widget.jobId));

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
            onRetry: () => ref.invalidate(technicianJobProvider(widget.jobId)),
          ),
          data: (j) => Column(
            children: [
              Expanded(child: _JobDetail(job: j)),
              _ActionBar(
                status: j.jobStatus,
                submitting: _submitting,
                onAcknowledge: _acknowledge,
                onStart: _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pinned action for the job's current status (null when there's nothing to do).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.status,
    required this.submitting,
    required this.onAcknowledge,
    required this.onStart,
  });

  final JobStatus status;
  final bool submitting;
  final VoidCallback onAcknowledge;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final (label, onPressed) = switch (status) {
      JobStatus.assigned => ('Acknowledge job', onAcknowledge),
      JobStatus.acknowledged => ('Start job', onStart),
      _ => (null, null),
    };

    // IN_PROGRESS: the finish flow (photos + mark done) arrives next module.
    final Widget inner = (label == null)
        ? (status == JobStatus.inProgress
            ? const AppText(
                'Add before & after photos to finish — coming soon.',
                variant: AppTextVariant.caption,
                color: AppTextColor.muted,
                textAlign: TextAlign.center,
              )
            : const SizedBox.shrink())
        : AppButton(
            label: label,
            size: AppButtonSize.lg,
            fullWidth: true,
            loading: submitting,
            onPressed: onPressed,
          );

    if (inner is SizedBox) return inner; // nothing to show (e.g. DONE)

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: inner,
      ),
    );
  }
}

class _JobDetail extends StatelessWidget {
  const _JobDetail({required this.job});
  final TechnicianJob job;

  @override
  Widget build(BuildContext context) {
    final when = job.scheduledDate != null
        ? '${formatFullDate(toLocalIsoDate(job.scheduledDate!))}'
            '${job.scheduledTime != null ? '\n${job.scheduledTime}' : ''}'
        : 'Not scheduled';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Header — service + reference + status.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppText(job.serviceName, variant: AppTextVariant.h2),
            ),
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
                _LineRow(label: 'Total', trailing: job.total!.format(), strong: true),
              ],
            ],
          ),
        ),

        if (job.notes != null && job.notes!.trim().isNotEmpty)
          _Section(title: 'Notes', child: AppText(job.notes!.trim())),

        if (job.photos.isNotEmpty)
          _Section(
            title: 'Photos',
            child: _PhotoStrip(photos: job.photos),
          ),
      ],
    );
  }
}

/// A titled block.
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

/// A label on the left, optional value on the right.
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

/// Horizontally-scrolling before/after photo thumbnails. Photo urls may be
/// relative, so they're resolved with assetUrl() before loading.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});
  final List<JobPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final photo = photos[i];
          final uri = assetUrl(photo.url);
          return ClipRRect(
            borderRadius: AppRadii.mdAll,
            child: SizedBox(
              width: 96,
              height: 96,
              child: uri == null
                  ? const ColoredBox(color: AppColors.surfaceAlt)
                  : Image.network(uri, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.surfaceAlt)),
            ),
          );
        },
      ),
    );
  }
}

// lib/src/features/technician/screens/technician_job_detail_screen.dart — one
// job's full detail for the assigned technician (read-only this module).
//
// Reads technicianJobProvider(id) and lays out the job: service + option, when,
// where, the customer contact, the line items + total, notes, and any before/after
// photos. Acknowledge / status / photo-upload actions land in later modules.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_time.dart';
import '../../../core/network/asset_url.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/technician_job.dart';
import '../jobs_providers.dart';
import '../widgets/job_status_pill.dart';

class TechnicianJobDetailScreen extends ConsumerWidget {
  const TechnicianJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(technicianJobProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Job detail', variant: AppTextVariant.subheading),
      ),
      body: SafeArea(
        child: job.when(
          loading: () => const LoadingState(),
          error: (_, _) => ErrorState(
            onRetry: () => ref.invalidate(technicianJobProvider(jobId)),
          ),
          data: (j) => _JobDetail(job: j),
        ),
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

/// A titled block with a divider above it (skips the divider on the first one via
/// the surrounding list spacing).
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
    final variant =
        strong ? AppTextVariant.bodyStrong : AppTextVariant.body;
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

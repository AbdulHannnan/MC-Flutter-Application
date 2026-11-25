// lib/src/features/technician/screens/technician_home_screen.dart — the signed-in
// technician's work area: their JOB QUEUE.
//
// Replaces the Module-1 placeholder. Lists the jobs assigned to this technician
// (soonest first, from the `technician` Edge Function), each tappable through to
// its detail. Pull-to-refresh re-fetches; loading / error / empty are handled
// inline with the shared core state widgets. Actions (acknowledge / status /
// photos) land in later modules — this module is read-only list + detail.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/technician_job.dart';
import '../jobs_providers.dart';
import '../technician_session.dart';
import '../widgets/job_status_pill.dart';

class TechnicianHomeScreen extends ConsumerWidget {
  const TechnicianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final technician = ref.watch(technicianSessionProvider).technician;
    final greetingName = technician?.firstName ?? 'there';
    final jobs = ref.watch(technicianJobsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const AppText('My jobs', variant: AppTextVariant.subheading),
        actions: [
          // TEMPORARY — Field Job Portal entry (see FIELD_PORTAL_REMOVAL.md).
          // Remove this IconButton at teardown.
          IconButton(
            tooltip: 'Field Job Portal',
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () => context.push(AppRoutes.fieldPortal),
          ),
          TextButton(
            onPressed: () =>
                ref.read(technicianSessionProvider.notifier).logout(),
            child: const AppText('Log out',
                variant: AppTextVariant.caption, color: AppTextColor.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(technicianJobsProvider(null)),
          child: jobs.when(
            loading: () => const LoadingState(),
            error: (_, _) => ErrorState(
              onRetry: () => ref.invalidate(technicianJobsProvider(null)),
            ),
            data: (list) => _JobList(greetingName: greetingName, jobs: list),
          ),
        ),
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.greetingName, required this.jobs});

  final String greetingName;
  final List<TechnicianJob> jobs;

  @override
  Widget build(BuildContext context) {
    // Always scrollable so pull-to-refresh works even when empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppText('Hi $greetingName 👋', variant: AppTextVariant.h2, maxLines: 1),
        const SizedBox(height: AppSpacing.xs),
        AppText(
          jobs.isEmpty
              ? 'No jobs assigned to you yet.'
              : '${jobs.length} job${jobs.length == 1 ? '' : 's'} assigned to you.',
          color: AppTextColor.muted,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (jobs.isEmpty)
          const _EmptyJobs()
        else
          ...jobs.map((j) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _JobCard(job: j),
              )),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});
  final TechnicianJob job;

  @override
  Widget build(BuildContext context) {
    final when = job.scheduledDate != null
        ? '${formatFullDate(toLocalIsoDate(job.scheduledDate!))}'
            '${job.scheduledTime != null ? ' · ${job.scheduledTime}' : ''}'
        : 'Not scheduled';

    return InkWell(
      onTap: () => context.push(AppRoutes.technicianJobOf(job.id)),
      borderRadius: AppRadii.lgAll,
      child: AppCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(job.serviceName,
                    variant: AppTextVariant.subheading, maxLines: 1),
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
            const SizedBox(height: AppSpacing.sm),
            _IconLine(icon: Icons.event_outlined, text: when),
            if (job.address != null && job.address!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _IconLine(icon: Icons.place_outlined, text: job.address!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A muted icon + text row used on the job card.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: AppText(text,
              variant: AppTextVariant.caption, color: AppTextColor.muted),
        ),
      ],
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft,
            ),
            child: const Icon(Icons.handyman_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppText('Nothing to do right now', variant: AppTextVariant.h3),
          const SizedBox(height: AppSpacing.sm),
          const AppText(
            'When a job is assigned to you it will show up here. '
            'Pull down to refresh.',
            variant: AppTextVariant.body,
            color: AppTextColor.muted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

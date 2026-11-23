// lib/src/features/technician/widgets/job_status_pill.dart — a small badge for a
// job's fulfillment status (Assigned / In progress / Done …). The technician-side
// analog of the customer StatusPill (which is bound to BookingStatus), kept
// separate so the two status vocabularies don't entangle.

import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../data/technician_job.dart';

class JobStatusPill extends StatelessWidget {
  final JobStatus status;
  const JobStatusPill({super.key, required this.status});

  ({Color bg, Color fg}) get _tone => switch (status) {
        JobStatus.assigned ||
        JobStatus.acknowledged =>
          (bg: AppColors.primarySoft, fg: AppColors.primary),
        JobStatus.inProgress =>
          (bg: AppColors.warningSoft, fg: AppColors.warning),
        JobStatus.done => (bg: AppColors.successSoft, fg: AppColors.success),
        JobStatus.unassigned =>
          (bg: AppColors.surfaceAlt, fg: AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          color: tone.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

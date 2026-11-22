// lib/src/features/technician/screens/technician_home_screen.dart — the landing
// screen for a signed-in TECHNICIAN (staff) account.
//
// Technicians get a DIFFERENT experience from customers: no services, catalog,
// cart, or booking flow. The role-aware router guard (src/app/app_router.dart)
// routes technician accounts here and keeps them out of the customer app. For now
// this is a scoped placeholder — the actual staff tools (assigned jobs, status
// updates, …) land in a later pass; the role plumbing + separate shell are what's
// in place today.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../technician_session.dart';

class TechnicianHomeScreen extends ConsumerWidget {
  const TechnicianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final technician = ref.watch(technicianSessionProvider).technician;
    final greetingName = technician?.firstName ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Technician', variant: AppTextVariant.subheading),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(technicianSessionProvider.notifier).logout(),
            child: const AppText('Log out',
                variant: AppTextVariant.caption, color: AppTextColor.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText('Hi $greetingName 👋',
                  variant: AppTextVariant.h2, maxLines: 1),
              const SizedBox(height: AppSpacing.xs),
              const _StaffBadge(),
              const SizedBox(height: AppSpacing.xl),

              // Scoped placeholder for the staff tools that land next.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const AppText('Your work area',
                          variant: AppTextVariant.h3),
                      const SizedBox(height: AppSpacing.sm),
                      const AppText(
                        'This is the technician dashboard. Your assigned jobs '
                        'and tools will appear here.',
                        variant: AppTextVariant.body,
                        color: AppTextColor.muted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill marking this as the staff area — a quick visual cue that this is
/// not the customer app.
class _StaffBadge extends StatelessWidget {
  const _StaffBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const AppText('Staff account',
          variant: AppTextVariant.caption, color: AppTextColor.primary),
    );
  }
}

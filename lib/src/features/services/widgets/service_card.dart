// lib/src/features/services/widgets/service_card.dart — a service list card. Dart
// port of the RN app's `ServiceCard`.
//
// Presentational: given a [Service], render its card — cover image with an optional
// rating badge, name, summary, "from" price and (when known) duration. No data
// fetching, no navigation; the parent passes [onTap]. Reused by the Home dashboard,
// the category list (Module 10) and search results (Module 10).

import 'package:flutter/material.dart';

import '../../../core/format/duration.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';

class ServiceCard extends StatelessWidget {
  final Service service;

  /// Tap handler — the parent decides where it goes (usually the detail screen).
  final VoidCallback? onTap;

  const ServiceCard({super.key, required this.service, this.onTap});

  @override
  Widget build(BuildContext context) {
    final uri = service.image?.uri;

    return Semantics(
      button: onTap != null,
      label: '${service.name}, ${service.basePrice.format()}',
      child: GestureDetector(
        onTap: onTap,
        child: AppCard(
          elevated: true,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover image with the rating badge floating over its top-right.
              Stack(
                children: [
                  SizedBox(
                    height: 160,
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
                  if (service.rating != null)
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs, vertical: 2),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.pillAll,
                        ),
                        child: AppText(
                          '⭐ ${service.rating!.toStringAsFixed(1)}',
                          variant: AppTextVariant.caption,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(service.name,
                        variant: AppTextVariant.bodyStrong, maxLines: 1),
                    if (service.summary != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppText(service.summary!,
                          variant: AppTextVariant.caption,
                          color: AppTextColor.muted,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(service.basePrice.format(),
                            variant: AppTextVariant.bodyStrong,
                            color: AppTextColor.primary),
                        // Duration is hidden when unknown (0) — the live backend
                        // supplies none.
                        if (service.duration > 0)
                          AppText(formatDuration(service.duration),
                              variant: AppTextVariant.caption,
                              color: AppTextColor.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

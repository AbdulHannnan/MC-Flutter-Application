// lib/src/features/services/screens/category_services_screen.dart — the
// "/category/:id" route: the services inside one category. Dart port of the RN
// app's `CategoryServicesScreen.tsx` (Module 10).
//
// Reached from the Home strip or the Categories list. Two reads:
//   • categoryProvider(id) — titles the screen (AppBar) and, if present, shows a
//     short intro line from the category description.
//   • servicesProvider(ServiceQuery(categoryId: id)) — the list itself.
// Loading / error / empty for the list come from the shared QueryBoundary; the
// header title falls back to a neutral label until the category resolves.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../catalog_providers.dart';
import '../catalog_repository.dart';
import '../widgets/query_boundary.dart';
import '../widgets/service_card.dart';

class CategoryServicesScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryServicesScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryProvider(categoryId));
    final query = ServiceQuery(categoryId: categoryId);
    final services = ref.watch(servicesProvider(query));

    // The category name titles the header once it's known; a neutral label holds
    // the space while it loads (or if the id is unknown).
    final title = category.value?.name ?? 'Services';
    final intro = category.value?.description;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: QueryBoundary<Service>(
          query: services,
          emptyLabel: 'No services in this category yet.',
          onRetry: () => ref.invalidate(servicesProvider(query)),
          builder: (list) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            // A leading intro line (index 0) when the category has a description.
            itemCount: list.length + (intro != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              if (intro != null && i == 0) {
                return AppText(intro, color: AppTextColor.muted);
              }
              final service = list[intro != null ? i - 1 : i];
              return ServiceCard(
                service: service,
                onTap: () => context.push(AppRoutes.serviceOf(service.id)),
              );
            },
          ),
        ),
      ),
    );
  }
}

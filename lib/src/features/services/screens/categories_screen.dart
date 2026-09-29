// lib/src/features/services/screens/categories_screen.dart — the "/categories"
// route: the full list of service categories. Dart port of the RN app's
// `CategoriesScreen.tsx` (Module 10).
//
// The Home strip only shows a short horizontal slice; this is the complete,
// vertical list. Each row navigates to that category's services
// (`/category/:id`). Data comes from `categoriesProvider`; loading / error /
// empty are handled by the shared `QueryBoundary`.
//
// NOTE: in LIVE mode the catalog fabricates a single synthetic "AC Services"
// category, so this list has one row — faithful to the RN app. The full set of
// categories only appears in MOCK mode.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../catalog_providers.dart';
import '../widgets/query_boundary.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: SafeArea(
        child: QueryBoundary<ServiceCategory>(
          query: categories,
          emptyLabel: 'No categories yet.',
          onRetry: () => ref.invalidate(categoriesProvider),
          builder: (list) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _CategoryRow(
              category: list[i],
              onTap: () => context.push(AppRoutes.categoryOf(list[i].id)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width category row: thumbnail + name + description + chevron. Local to
/// this screen (the Home strip uses the compact [CategoryChip] instead).
class _CategoryRow extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const _CategoryRow({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uri = category.image?.uri;
    return Semantics(
      button: true,
      label: category.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AppCard(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadii.mdAll,
                child: SizedBox(
                  height: 64,
                  width: 64,
                  child: uri == null
                      ? const ColoredBox(color: AppColors.surfaceAlt)
                      : Image.network(
                          uri,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.surfaceAlt),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(category.name,
                        variant: AppTextVariant.bodyStrong, maxLines: 1),
                    if (category.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppText(category.description!,
                          variant: AppTextVariant.caption,
                          color: AppTextColor.muted,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AppText('›',
                  variant: AppTextVariant.h3, color: AppTextColor.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

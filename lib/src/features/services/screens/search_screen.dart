// lib/src/features/services/screens/search_screen.dart — the "/search" route:
// free-text search + category filter over the catalog. Dart port of the RN app's
// `SearchScreen.tsx` (Module 10).
//
// Two ways to narrow the catalog, feeding ONE servicesProvider read:
//   • a free-text box, DEBOUNCED 300ms (query when typing pauses, not per key), and
//   • category filter chips (All + one per category).
// Each (categoryId, search) pair is its own provider cache entry. To avoid a
// spinner flash between keystrokes we KEEP the previous results on screen while
// the next query loads (the "keepPrevious" seam noted in catalog_providers.dart):
// we render `services.value ?? _lastResults` and only show the full loading
// state on the very first fetch.
//
// With an empty box and "All" selected it lists the whole catalog, so this screen
// doubles as "browse everything".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';
import '../catalog_providers.dart';
import '../catalog_repository.dart';
import '../widgets/service_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// The debounced, trimmed search term that actually drives the query.
  String _search = '';
  String? _categoryId;

  /// Last successful results, kept visible while the next query loads.
  List<Service>? _lastResults;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Immediate rebuild so the clear button appears/disappears with the text…
    setState(() {});
    // …but only commit the search term (and refetch) once typing pauses.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    setState(() => _search = value.trim());
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _search = '');
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final query = ServiceQuery(categoryId: _categoryId, search: _search);
    final services = ref.watch(servicesProvider(query));

    // Remember the latest data so a subsequent query can show it while loading.
    ref.listen<AsyncValue<List<Service>>>(servicesProvider(query), (_, next) {
      if (next.hasValue) _lastResults = next.value;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search box + category filter ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _controller,
                    hintText: 'Search services…',
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    suffix: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.textSubtle,
                            onPressed: _clear,
                            tooltip: 'Clear',
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CategoryFilter(
                    categories: categories.value ?? const [],
                    selectedId: _categoryId,
                    onSelect: (id) => setState(() => _categoryId = id),
                  ),
                ],
              ),
            ),

            // ── Results ──
            Expanded(child: _results(services)),
          ],
        ),
      ),
    );
  }

  Widget _results(AsyncValue<List<Service>> services) {
    // Error with nothing to fall back to → full error state + retry.
    if (services.hasError && _lastResults == null) {
      return ErrorState(
        compact: true,
        onRetry: () => ref.invalidate(
          servicesProvider(ServiceQuery(categoryId: _categoryId, search: _search)),
        ),
      );
    }

    // Prefer fresh data; otherwise keep the previous results visible.
    final list = services.value ?? _lastResults;
    if (list == null) return const LoadingState(compact: true);

    if (list.isEmpty) {
      final label = _search.isNotEmpty
          ? 'No services match "$_search".'
          : 'No services here yet.';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppText(label,
            variant: AppTextVariant.caption, color: AppTextColor.muted),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      // A leading result-count line (index 0), then one card per service.
      itemCount: list.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        if (i == 0) {
          return AppText(
            '${list.length} ${list.length == 1 ? 'result' : 'results'}',
            variant: AppTextVariant.caption,
            color: AppTextColor.muted,
          );
        }
        final service = list[i - 1];
        return ServiceCard(
          service: service,
          onTap: () => context.push(AppRoutes.serviceOf(service.id)),
        );
      },
    );
  }
}

/// The horizontal row of category filter pills: "All" plus one per category.
/// Kept for RN parity even when a single synthetic category means just
/// `[All] [AC Services]`.
class _CategoryFilter extends StatelessWidget {
  final List<ServiceCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: category.name,
              selected: selectedId == category.id,
              onTap: () => onSelect(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// A pill-shaped filter toggle. Local to search — the only place category chips
/// act as filters (the Home strip uses [CategoryChip] as navigation tiles).
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadii.pillAll,
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: AppText(
            label,
            variant: AppTextVariant.caption,
            color: selected ? AppTextColor.primary : AppTextColor.muted,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

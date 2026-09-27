// lib/src/features/services/widgets/query_boundary.dart — catalog state renderer.
// Dart port of the RN app's `QueryBoundary`.
//
// Every catalog section (Home, categories list, category services) needs the same
// four-way branch on a fetch: a compact spinner while loading, a compact error with
// a retry, an "empty" note, or the data. This widget owns that branch ONCE, keyed
// off an [AsyncValue], so the screens stay declarative and every state looks the
// same. It renders data via a [builder] that takes the non-empty list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

class QueryBoundary<T> extends StatelessWidget {
  final AsyncValue<List<T>> query;

  /// Optional derived items to render instead of `query.value` (e.g. a sorted
  /// slice for "popular"). The loading/error states still come from [query].
  final List<T>? items;

  /// Shown when the fetch succeeded but there's nothing to list.
  final String emptyLabel;

  /// Re-run the fetch (wired to `ref.invalidate(provider)` by the caller).
  final VoidCallback? onRetry;

  /// Render the list once there's at least one item.
  final Widget Function(List<T> items) builder;

  const QueryBoundary({
    super.key,
    required this.query,
    required this.emptyLabel,
    required this.builder,
    this.items,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return query.when(
      loading: () => const LoadingState(compact: true),
      error: (error, _) => ErrorState(compact: true, onRetry: onRetry),
      data: (data) {
        final list = items ?? data;
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppText(emptyLabel,
                variant: AppTextVariant.caption, color: AppTextColor.muted),
          );
        }
        return builder(list);
      },
    );
  }
}

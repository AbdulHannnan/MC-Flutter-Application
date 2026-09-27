// lib/src/features/services/catalog_providers.dart — the catalog CACHING layer.
// The Riverpod equivalent of the RN app's React Query setup (`queryClient.ts` +
// `hooks/useCatalog.ts`).
//
// THE SEAM: screens read these providers and get an `AsyncValue<T>` — Flutter's
// native `{ data, isLoading, error }`, with `ref.invalidate(provider)` as the
// `refetch`. So there's no bespoke `QueryResult` wrapper (RN needed one to hide
// React Query; here `AsyncValue` already IS that stable shape).
//
// WHAT REACT QUERY GAVE US, and how each maps to Riverpod:
//   • Cache keyed by queryKey        → each `.family` argument IS the cache key
//                                       (ServiceQuery/id value-equality dedupes).
//   • Request de-duplication          → Riverpod shares one future per key.
//   • staleTime (5 min) + gc          → `ref.cacheFor(kCatalogStaleTime)`: the
//                                       entry is kept alive for the window even
//                                       with no listeners, then disposed so the
//                                       next read refetches. Revisiting within the
//                                       window is instant with no network call.
//   • retry: 2 with backoff           → Riverpod 3's NATIVE `retry:` parameter,
//                                       driven by [catalogRetryPolicy] (2 retries,
//                                       exponential backoff). We do NOT hand-roll
//                                       retries — the framework owns that loop.
//   • don't retry a 404               → [serviceRetryPolicy] returns null (stop)
//                                       for a [ServiceNotFoundError].
//   • keepPreviousData (search)       → handled at the search screen (Module 10)
//                                       via `AsyncValue`'s previous value while
//                                       refreshing; nothing to do at this layer.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'catalog_repository.dart';

/// How long fetched catalog data is considered fresh (React Query `staleTime`).
/// The catalog changes rarely, so 5 minutes avoids needless refetches while the
/// user browses. Matches the RN `queryClient` default.
const Duration kCatalogStaleTime = Duration(minutes: 5);

/// Retry a failed query this many times before surfacing the error (React Query
/// `retry: 2`) — smooths over flaky mobile networks without hanging forever.
const int kCatalogRetries = 2;

/// The default catalog retry policy for Riverpod's native `retry:`. Returns the
/// delay before the next attempt, or null to stop. Retries up to [kCatalogRetries]
/// times with exponential backoff (300ms, 600ms). [retryCount] is the number of
/// retries already made (0 on the first failure).
Duration? catalogRetryPolicy(int retryCount, Object error) => retryCount < kCatalogRetries
    ? Duration(milliseconds: 300 * (1 << retryCount))
    : null;

/// Retry policy for a single-service lookup: like [catalogRetryPolicy], but never
/// retries a [ServiceNotFoundError] — a genuine 404 won't change on a retry, and
/// retrying only delays showing the error.
Duration? serviceRetryPolicy(int retryCount, Object error) =>
    error is ServiceNotFoundError ? null : catalogRetryPolicy(retryCount, error);

/// Keep a keep-alive provider cached for [duration] even when nothing is
/// listening, then dispose it so the next read refetches. This reproduces React
/// Query's staleTime+gc behaviour on an `autoDispose` provider: instant revisits
/// inside the window, a fresh fetch after it.
extension CacheForRef on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

/// All categories, in display order. (Key: `['categories']`.)
final categoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>(
  (ref) {
    ref.cacheFor(kCatalogStaleTime);
    return ref.watch(catalogRepositoryProvider).getCategories();
  },
  retry: catalogRetryPolicy,
);

/// A single category by id — the category screen's header. (Key: `['category', id]`.)
final categoryProvider =
    FutureProvider.autoDispose.family<ServiceCategory?, String>(
  (ref, id) {
    ref.cacheFor(kCatalogStaleTime);
    return ref.watch(catalogRepositoryProvider).getCategoryById(id);
  },
  retry: catalogRetryPolicy,
);

/// Services, optionally filtered by category and/or search term. Each distinct
/// [ServiceQuery] is its own cache entry, so switching a filter back reuses a
/// previously fetched result instantly. (Key: the query's value identity.)
final servicesProvider =
    FutureProvider.autoDispose.family<List<Service>, ServiceQuery>(
  (ref, query) {
    ref.cacheFor(kCatalogStaleTime);
    return ref.watch(catalogRepositoryProvider).getServices(query);
  },
  retry: catalogRetryPolicy,
);

/// A single service by id — the detail screen. A missing id throws
/// [ServiceNotFoundError], surfaced as the `AsyncValue`'s error and NOT retried
/// (see [serviceRetryPolicy]). (Key: `['service', id]`.)
final serviceProvider = FutureProvider.autoDispose.family<Service, String>(
  (ref, id) {
    ref.cacheFor(kCatalogStaleTime);
    return ref.watch(catalogRepositoryProvider).getServiceById(id);
  },
  retry: serviceRetryPolicy,
);

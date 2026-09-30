// lib/src/features/booking/availability_providers.dart — the availability CACHING
// layer. The Riverpod equivalent of the RN app's `useAvailability` hook (a React
// Query `useQuery` over `availabilityApi`).
//
// Same seam as the catalog providers (Module 6): screens read [daySlotsProvider] and
// get an `AsyncValue<List<TimeSlot>>` — Flutter's native `{ data, isLoading, error }`,
// with `ref.invalidate(provider)` as the refetch — which drops straight into the
// shared [QueryBoundary]. We reuse the catalog layer's `ref.cacheFor(...)` staleTime
// helper and default retry policy rather than re-declaring them.
//
// A SHORTER staleTime than the catalog's (60s vs 5m): in the real system
// availability shifts as others book, so we don't want to serve a stale grid for
// long. (Here it's client-generated, but the seam keeps the same freshness contract.)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../services/catalog_providers.dart' show CacheForRef, catalogRetryPolicy;
import 'availability_repository.dart';

/// How long a fetched day's slots stay fresh (React Query `staleTime`).
const Duration kAvailabilityStaleTime = Duration(seconds: 60);

/// The single availability data source. Overridable in tests (e.g. zero latency /
/// forced demo-taken).
final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => AvailabilityRepository(),
);

/// The bookable slots for one calendar day ("YYYY-MM-DD"). Each date is its own
/// cache entry, so revisiting a day is instant within the stale window. (Key:
/// `['availability', date]`.)
final daySlotsProvider =
    FutureProvider.autoDispose.family<List<TimeSlot>, String>(
  (ref, date) {
    ref.cacheFor(kAvailabilityStaleTime);
    return ref.watch(availabilityRepositoryProvider).getDaySlots(date);
  },
  retry: catalogRetryPolicy,
);

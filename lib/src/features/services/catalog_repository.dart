// lib/src/features/services/catalog_repository.dart — the catalog DATA SOURCE seam.
//
// Holds the catalog read contract ([CatalogSource]) + its value types
// ([ServiceQuery], [ServiceNotFoundError]), and wires [catalogRepositoryProvider]
// to the single implementation, [SupabaseCatalogRepository] (supabase-js reads of
// the RLS-guarded `Service`/`Addon` tables; see supabase_catalog_repository.dart).
// Exposed as the interface so tests override the provider with an in-memory fake.
//
// WHAT THIS IS NOT: it is not caching. Deciding *when* to refetch, holding results,
// and de-duping requests is the caching layer's job (catalog_providers.dart, the
// react-query equivalent).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client.dart';
import '../../models/models.dart';
import 'supabase_catalog_repository.dart';

/// Filters for listing services. Its value equality is what makes it a stable
/// CACHE KEY for `servicesProvider` — two queries that normalise to the same
/// category/term share one cache entry. Mirrors the RN `ServiceQuery` +
/// `catalogKeys.services` normalisation (`search` trimmed; empty → null).
class ServiceQuery {
  /// Only services in this category. Null/empty ⇒ the whole catalog.
  final String? categoryId;

  /// Free-text search over name/summary/description. Trimmed; null/empty ⇒ none.
  final String? search;

  const ServiceQuery._(this.categoryId, this.search);

  factory ServiceQuery({String? categoryId, String? search}) {
    final term = search?.trim();
    return ServiceQuery._(
      (categoryId != null && categoryId.isNotEmpty) ? categoryId : null,
      (term != null && term.isNotEmpty) ? term : null,
    );
  }

  /// The whole active catalog, unfiltered.
  static const ServiceQuery all = ServiceQuery._(null, null);

  @override
  bool operator ==(Object other) =>
      other is ServiceQuery &&
      other.categoryId == categoryId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(categoryId, search);

  @override
  String toString() => 'ServiceQuery(categoryId: $categoryId, search: $search)';
}

/// Raised when a lookup by id finds nothing — mirrors a real backend 404. The
/// caching layer does NOT retry this (a genuine 404 won't change on a retry).
class ServiceNotFoundError implements Exception {
  final String id;
  const ServiceNotFoundError(this.id);

  @override
  String toString() => 'ServiceNotFoundError: Service not found: $id';
}

/// The catalog read contract the caching layer + screens depend on.
/// [SupabaseCatalogRepository] implements it; tests override
/// [catalogRepositoryProvider] with an in-memory fake [CatalogSource].
abstract interface class CatalogSource {
  Future<List<ServiceCategory>> getCategories();
  Future<List<Service>> getServices([ServiceQuery query]);
  Future<Service> getServiceById(String id);
  Future<ServiceCategory?> getCategoryById(String id);
}

/// The single catalog source the whole app reads (Supabase), as the [CatalogSource]
/// seam so it can be overridden with a fake in tests.
final catalogRepositoryProvider = Provider<CatalogSource>(
  (ref) => SupabaseCatalogRepository(ref.watch(supabaseClientProvider)),
);

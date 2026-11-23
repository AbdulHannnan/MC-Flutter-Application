// lib/src/features/services/catalog_repository.dart — the catalog DATA SOURCE.
// Dart/Riverpod port of the RN app's `src/features/services/servicesApi.ts`.
//
// This is the ONE place the app fetches catalog data. It has two backends, chosen
// by `CATALOG_MODE` (config.isMockCatalog):
//   • mock — the in-repo seed data (catalog_mock_data.dart), so the app runs
//     offline; served behind a small simulated latency so loading states show.
//   • live (default) — the real web backend: GET /api/services and GET /api/addons.
// Either way the SIGNATURES are the contract, so the caching providers
// (catalog_providers.dart) and screens don't change. The live branch ADAPTS the
// backend's shapes to our domain types.
//
// WHAT THE BACKEND ACTUALLY GIVES US (README spec §3), and how we adapt it:
//   • No Category entity → we browse a single synthetic "AC Services" category.
//   • No get-one or search endpoints → we fetch the full list and find/filter on device.
//   • Money is MAJOR-unit AED *strings* ("40.00") → Money.fromAed() converts to fils.
//   • Images are relative paths ("/images/…") → assetUrl() prepends the API origin.
//   • No `duration` on services/options → mapped to 0 (the UI hides a 0 duration).
//   • Add-ons live behind a separate endpoint keyed by serviceId (not embedded on a
//     service), so we fetch them only on the detail lookup that needs them.
//
// WHAT THIS IS NOT: it is not caching. Deciding *when* to refetch, holding results,
// and de-duping requests is the caching layer's job (catalog_providers.dart, the
// react-query equivalent). This layer performs the fetch and returns domain models
// (or throws).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/supabase_client.dart';
import '../../models/models.dart';
import 'catalog_mappers.dart';
import 'catalog_mock_data.dart';
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

/// The catalog data source. Construct with an [ApiClient] (used only in live
/// The catalog read contract the caching layer + screens depend on. Both the
/// Express/mock [CatalogRepository] and the [SupabaseCatalogRepository] implement
/// it, so [catalogRepositoryProvider] can serve either behind the SAME type —
/// nothing downstream changes when a build flips `CATALOG_BACKEND`.
abstract interface class CatalogSource {
  Future<List<ServiceCategory>> getCategories();
  Future<List<Service>> getServices([ServiceQuery query]);
  Future<Service> getServiceById(String id);
  Future<ServiceCategory?> getCategoryById(String id);
}

/// mode) and the mock/live toggle; both are injected so tests can drive either
/// branch. Feature code reads [catalogRepositoryProvider] instead.
class CatalogRepository implements CatalogSource {
  final ApiClient _api;

  /// When true, serve the in-repo seed instead of calling the backend.
  final bool useMock;

  /// How long the mock "network" takes, so loading states are visible in dev.
  /// Zero in tests (pass `mockLatency: Duration.zero`).
  final Duration mockLatency;

  CatalogRepository(
    this._api, {
    required this.useMock,
    this.mockLatency = const Duration(milliseconds: 400),
  });

  // ── Public API ─────────────────────────────────────────────────────────────

  /// All categories, in display order.
  @override
  Future<List<ServiceCategory>> getCategories() async {
    if (!useMock) {
      // No Category entity server-side — the app browses one synthetic group.
      return [acServicesCategory];
    }
    await _delay();
    final ordered = [...kMockCategories]
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return ordered;
  }

  /// Active services, optionally filtered by category and/or a search term.
  @override
  Future<List<Service>> getServices([ServiceQuery query = ServiceQuery.all]) async {
    if (!useMock) {
      // GET /api/services returns ALL active services (with their options[]).
      // There is no filter/search endpoint (spec §3), so we do both on the device.
      final raw = await _api.get<List<dynamic>>('/api/services');
      var results = raw
          .map((e) => mapService(e as Map<String, dynamic>))
          .toList();

      // Single synthetic category: a categoryId filter matches all services or none.
      if (query.categoryId != null &&
          query.categoryId != acServicesCategory.id) {
        results = [];
      }

      final term = query.search?.toLowerCase();
      if (term != null && term.isNotEmpty) {
        results = results
            .where((s) =>
                s.name.toLowerCase().contains(term) ||
                (s.description?.toLowerCase().contains(term) ?? false))
            .toList();
      }
      return results;
    }

    await _delay();
    var results = kMockServices.where((s) => s.active).toList();

    if (query.categoryId != null) {
      results = results.where((s) => s.categoryId == query.categoryId).toList();
    }

    final term = query.search?.toLowerCase();
    if (term != null && term.isNotEmpty) {
      results = results
          .where((s) =>
              s.name.toLowerCase().contains(term) ||
              (s.summary?.toLowerCase().contains(term) ?? false) ||
              (s.description?.toLowerCase().contains(term) ?? false))
          .toList();
    }
    return results;
  }

  /// A single service by id. Throws [ServiceNotFoundError] if it doesn't exist.
  @override
  Future<Service> getServiceById(String id) async {
    if (!useMock) {
      // No get-one endpoint (spec §3): fetch the list and find the id. In
      // parallel, fetch THIS service's add-ons (their own endpoint) so the detail
      // screen has its extras.
      final results = await Future.wait([
        _api.get<List<dynamic>>('/api/services'),
        _api.get<List<dynamic>>('/api/addons', query: {'serviceId': id}),
      ]);
      final raw = results[0];
      final rawAddons = results[1];

      final found = raw.cast<Map<String, dynamic>>().firstWhere(
            (s) => s['id'] == id,
            orElse: () => throw ServiceNotFoundError(id),
          );
      final addons = rawAddons
          .map((e) => mapServiceAddon(e as Map<String, dynamic>))
          .toList();
      return mapService(found, addons);
    }

    await _delay();
    for (final s in kMockServices) {
      if (s.id == id) return s;
    }
    throw ServiceNotFoundError(id);
  }

  /// A single category by id. Returns null if it doesn't exist.
  @override
  Future<ServiceCategory?> getCategoryById(String id) async {
    if (!useMock) {
      return id == acServicesCategory.id ? acServicesCategory : null;
    }
    await _delay();
    for (final c in kMockCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ── Mock plumbing ────────────────────────────────────────────────────────────

  Future<void> _delay() =>
      mockLatency == Duration.zero ? Future.value() : Future.delayed(mockLatency);

  // Live JSON→domain adapting lives in catalog_mappers.dart (shared with the
  // Supabase backend), since Express and Supabase return the same per-entity
  // shapes.
}

/// The single catalog source the whole app reads, as the shared [CatalogSource]
/// interface. Chosen by the build's flags, with Express as the proven fallback:
///   • `CATALOG_MODE=mock`               → in-repo seed data.
///   • live + `CATALOG_BACKEND=supabase` → [SupabaseCatalogRepository] (only when
///                                         Supabase is configured; else Express).
///   • live (default)                    → Express `GET /api/services` + `/api/addons`.
/// Overridable with a fake in tests (any [CatalogSource]).
final catalogRepositoryProvider = Provider<CatalogSource>((ref) {
  if (config.isMockCatalog) {
    return CatalogRepository(ref.watch(apiClientProvider), useMock: true);
  }
  if (config.isSupabaseCatalog) {
    return SupabaseCatalogRepository(ref.watch(supabaseClientProvider));
  }
  return CatalogRepository(ref.watch(apiClientProvider), useMock: false);
});

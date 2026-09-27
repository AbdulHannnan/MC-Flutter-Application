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
import '../../core/network/asset_url.dart';
import '../../models/models.dart';
import 'catalog_mock_data.dart';

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
/// mode) and the mock/live toggle; both are injected so tests can drive either
/// branch. Feature code reads [catalogRepositoryProvider] instead.
class CatalogRepository {
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
  Future<List<Service>> getServices([ServiceQuery query = ServiceQuery.all]) async {
    if (!useMock) {
      // GET /api/services returns ALL active services (with their options[]).
      // There is no filter/search endpoint (spec §3), so we do both on the device.
      final raw = await _api.get<List<dynamic>>('/api/services');
      var results = raw
          .map((e) => _mapService(e as Map<String, dynamic>))
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
          .map((e) => _mapAddon(e as Map<String, dynamic>))
          .toList();
      return _mapService(found, addons);
    }

    await _delay();
    for (final s in kMockServices) {
      if (s.id == id) return s;
    }
    throw ServiceNotFoundError(id);
  }

  /// A single category by id. Returns null if it doesn't exist.
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

  // ── Live backend: adapters (raw JSON → our domain types) ─────────────────────
  //
  // The raw shapes (spec §3) are read structurally from the decoded JSON rather
  // than through typed classes — nothing outside this file sees them. Adapting
  // matches the RN `mapOption`/`mapAddon`/`mapService` exactly.

  /// One price-tier option. Backend `label` → our `name`; no server duration → 0.
  ServiceOption _mapOption(Map<String, dynamic> o) => ServiceOption(
        id: o['id'] as String,
        name: o['label'] as String,
        price: Money.fromAed(o['price']),
        duration: 0,
      );

  /// One add-on. Add-ons carry no duration server-side, so we leave it unset.
  ServiceAddon _mapAddon(Map<String, dynamic> a) => ServiceAddon(
        id: a['id'] as String,
        name: a['name'] as String,
        description: (a['description'] as String?),
        price: Money.fromAed(a['price']),
      );

  /// A backend service → our [Service]. Add-ons come from a separate endpoint, so
  /// callers that need them (the detail lookup) pass them in; list views map none.
  Service _mapService(Map<String, dynamic> s, [List<ServiceAddon> addons = const []]) {
    final options = (s['options'] as List<dynamic>? ?? const [])
        .map((e) => _mapOption(e as Map<String, dynamic>))
        .toList();

    // basePrice = the cheapest option (the "from" price on cards); 0 with none.
    final basePrice = options.isEmpty
        ? Money.fromAed(0)
        : options
            .map((o) => o.price)
            .reduce((min, p) => p.amountMinor < min.amountMinor ? p : min);

    final imageUri = assetUrl(s['imageUrl'] as String?);

    return Service(
      id: s['id'] as String,
      categoryId: acServicesCategory.id,
      name: s['name'] as String,
      slug: s['slug'] as String,
      description: s['description'] as String?,
      image: imageUri == null ? null : ImageRef(uri: imageUri, alt: s['name'] as String),
      basePrice: basePrice,
      duration: 0, // backend has no durations (spec §3); the UI hides a 0 duration.
      options: options,
      addons: addons,
      active: s['isActive'] as bool? ?? true,
    );
  }
}

/// The single [CatalogRepository] the whole app reads. Wired to the shared
/// [apiClientProvider] and the build's `CATALOG_MODE` — the idiomatic Flutter
/// replacement for the RN module-level `servicesApi` singleton. Overridable with a
/// fake in tests.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return CatalogRepository(api, useMock: config.isMockCatalog);
});

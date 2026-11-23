// lib/src/features/services/supabase_catalog_repository.dart — the catalog read
// path on SUPABASE (supabase-js style reads of the Postgres tables, RLS-guarded).
//
// The Supabase-native replacement for the Express `GET /api/services` +
// `GET /api/addons` routes. A faithful port of the booking website's
// `supabaseCatalog.js` (the proven client of these same tables + policies):
//   • Services  → `Service` with embedded active `ServiceOption`s
//                 (SELECT aliases the embed as `options`, sorted by `unitCount`).
//   • Add-ons   → per service via the `ServiceAddon` join → `Addon`; RLS hides
//                 inactive rows (surface as a null embed we drop).
//
// RLS already restricts reads to ACTIVE services / options / add-ons under the
// public key, so this never sees inactive rows and can never write. The decoded
// rows share the SAME per-entity shapes as the Express JSON (prices arrive numeric
// here rather than as "40.00" strings — [Money.fromAed] handles both), so the
// domain mapping is the shared one in catalog_mappers.dart.
//
// The app browses a single synthetic "AC Services" category (there is no Category
// entity server-side), and there is no get-one/search endpoint — exactly as the
// Express path, so category/search filtering is done on-device here too.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'catalog_mappers.dart';
import 'catalog_repository.dart' show CatalogSource, ServiceQuery, ServiceNotFoundError;

/// Columns for a service read, with its active price-tier options embedded and
/// aliased to `options` (the key the shared mapper reads). Mirrors the website's
/// `SERVICE_SELECT`.
const String _serviceSelect =
    'id,code,name,slug,description,imageUrl,subServices,propertyTypes,isActive,'
    'createdAt,updatedAt,options:ServiceOption(id,label,unitCount,price)';

/// Columns for an add-on read. Mirrors the website's `ADDON_FIELDS`.
const String _addonFields = 'id,code,name,description,price,imageUrl';

class SupabaseCatalogRepository implements CatalogSource {
  SupabaseCatalogRepository(this._sb);

  final SupabaseClient _sb;

  @override
  Future<List<ServiceCategory>> getCategories() async {
    // No Category entity server-side — the app browses one synthetic group.
    return [acServicesCategory];
  }

  @override
  Future<ServiceCategory?> getCategoryById(String id) async {
    return id == acServicesCategory.id ? acServicesCategory : null;
  }

  @override
  Future<List<Service>> getServices([ServiceQuery query = ServiceQuery.all]) async {
    var results = await _fetchServices();

    // Single synthetic category: a categoryId filter matches all services or none.
    if (query.categoryId != null && query.categoryId != acServicesCategory.id) {
      return [];
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

  @override
  Future<Service> getServiceById(String id) async {
    // No get-one endpoint: fetch the active list and find the id, and in parallel
    // fetch THIS service's add-ons (their own table), so the detail screen has
    // its extras — same two-call shape the Express path uses.
    final results = await Future.wait([
      _fetchServiceRows(),
      _fetchAddons(id),
    ]);
    final rows = results[0] as List<Map<String, dynamic>>;
    final addons = results[1] as List<ServiceAddon>;

    final found = rows.firstWhere(
      (s) => s['id'] == id,
      orElse: () => throw ServiceNotFoundError(id),
    );
    return mapService(found, addons);
  }

  // ── Supabase reads ───────────────────────────────────────────────────────────

  /// Active services as decoded rows, each with its options sorted by `unitCount`
  /// (RLS already hides inactive services + inactive embedded options).
  Future<List<Map<String, dynamic>>> _fetchServiceRows() async {
    final rows = await _sb
        .from('Service')
        .select(_serviceSelect)
        .eq('isActive', true)
        .order('name', ascending: true);

    for (final row in rows) {
      final options = (row['options'] as List?)?.cast<Map<String, dynamic>>();
      if (options != null) {
        options.sort((a, b) =>
            ((a['unitCount'] ?? 0) as num).compareTo((b['unitCount'] ?? 0) as num));
        row['options'] = options;
      }
    }
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Service>> _fetchServices() async {
    final rows = await _fetchServiceRows();
    return rows.map((r) => mapService(r)).toList();
  }

  /// A service's add-ons via the `ServiceAddon` join → `Addon`. RLS nulls out
  /// inactive add-ons, which we drop; sorted by name to match the website.
  Future<List<ServiceAddon>> _fetchAddons(String serviceId) async {
    final rows = await _sb
        .from('ServiceAddon')
        .select('addon:Addon($_addonFields)')
        .eq('serviceId', serviceId);

    final addons = rows
        .map((r) => r['addon'])
        .whereType<Map<String, dynamic>>()
        .map(mapServiceAddon)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return addons;
  }
}

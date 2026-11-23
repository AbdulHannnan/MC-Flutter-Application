// lib/src/features/services/catalog_mappers.dart — raw catalog JSON → domain model
// adapters, SHARED by both catalog backends.
//
// The Express routes and the Supabase tables return the SAME per-entity shapes
// (same field names: `label`/`price` on an option, `name`/`price` on an add-on,
// `name`/`slug`/`imageUrl`/`isActive`/`options` on a service), so one set of
// mappers serves both. The only cross-backend difference is the price TYPE —
// Express sends major-unit AED strings ("40.00"), Supabase sends numerics (40) —
// and [Money.fromAed] already accepts both, so these mappers don't care which
// backend produced the JSON.
//
// Backend-specific concerns stay OUT of here: Express vs supabase-js transport,
// Supabase's option `unitCount` sort, and its nested `{ addon: {...} }` add-on
// rows are unwrapped/sorted by each repository BEFORE calling these.

import '../../core/network/asset_url.dart';
import '../../models/models.dart';

/// One price-tier option. Backend `label` → our `name`; no server duration → 0.
ServiceOption mapServiceOption(Map<String, dynamic> o) => ServiceOption(
      id: o['id'] as String,
      name: o['label'] as String,
      price: Money.fromAed(o['price']),
      duration: 0,
    );

/// One add-on. Add-ons carry no duration server-side, so we leave it unset.
ServiceAddon mapServiceAddon(Map<String, dynamic> a) => ServiceAddon(
      id: a['id'] as String,
      name: a['name'] as String,
      description: a['description'] as String?,
      price: Money.fromAed(a['price']),
    );

/// A backend service → our [Service]. Add-ons come from a separate query, so
/// callers that need them (the detail lookup) pass them in; list views map none.
/// `options` are mapped in the order given — a caller that needs a specific order
/// (e.g. Supabase's `unitCount`) sorts the raw list first.
Service mapService(Map<String, dynamic> s,
    [List<ServiceAddon> addons = const []]) {
  final options = (s['options'] as List<dynamic>? ?? const [])
      .map((e) => mapServiceOption(e as Map<String, dynamic>))
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
    image:
        imageUri == null ? null : ImageRef(uri: imageUri, alt: s['name'] as String),
    basePrice: basePrice,
    duration: 0, // backend has no durations (spec §3); the UI hides a 0 duration.
    options: options,
    addons: addons,
    active: s['isActive'] as bool? ?? true,
  );
}

// lib/src/models/service.dart — the service-catalog entities. Dart port of the
// RN app's `src/types/service.ts`.
//
// The nouns of "what can I book?": a CATEGORY groups SERVICES, and a service may
// offer several OPTIONS (single-select sub-services) plus ADDONS (multi-select
// extras). These are SERVER DATA — fetched and cached by the catalog layer
// (Module 6); the raw backend→domain adapting (label→name, "40.00"→Money,
// relative image path→absolute) lives there, not here. These classes are the
// adapted DOMAIN shapes.
//
// `toJson`/`fromJson` here round-trip the DOMAIN shape (not the backend shape),
// so a snapshot can be persisted/restored locally and unit-tested.

import 'common.dart';
import 'money.dart';

/// A top-level grouping in the catalog. The backend has no Category entity — the
/// app browses a single synthetic [acServicesCategory] (see below).
class ServiceCategory {
  final Id id;
  final String name;

  /// URL/analytics-friendly key, e.g. "ac-services".
  final String slug;
  final String? description;
  final ImageRef? image;

  /// Lower numbers sort first; optional so the server can default it.
  final int? sortOrder;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.image,
    this.sortOrder,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        image: json['image'] == null
            ? null
            : ImageRef.fromJson(json['image'] as Map<String, dynamic>),
        sortOrder: (json['sortOrder'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        if (description != null) 'description': description,
        if (image != null) 'image': image!.toJson(),
        if (sortOrder != null) 'sortOrder': sortOrder,
      };
}

/// The single synthetic category. The backend serves a flat service list with no
/// Category entity (spec §3); to keep the category-based browse UI working, the
/// app presents ONE group that holds every service. Its [id] is what the category
/// screens filter/look up by. Mirrors the RN `AC_SERVICES_CATEGORY`.
const ServiceCategory acServicesCategory = ServiceCategory(
  id: 'ac-services',
  name: 'AC Services',
  slug: 'ac-services',
  description: 'AC cleaning, repair, installation and maintenance across Dubai.',
  sortOrder: 1,
);

/// A single-select sub-service chosen WITHIN a service — e.g. "Split AC (1 unit)"
/// vs. "Split AC (2 units)". A service with no options is booked at its base
/// price. The chosen option's price overrides the service base price.
class ServiceOption {
  final Id id;
  final String name;
  final String? description;

  /// Price for THIS option.
  final Money price;

  /// Duration in whole minutes; 0 when the backend gives none (the UI hides a
  /// zero duration).
  final int duration;

  const ServiceOption({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.description,
  });

  factory ServiceOption.fromJson(Map<String, dynamic> json) => ServiceOption(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: Money.fromJson(json['price'] as Map<String, dynamic>),
        duration: (json['duration'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'price': price.toJson(),
        'duration': duration,
      };
}

/// An optional multi-select EXTRA added on top of the chosen service/option —
/// e.g. "Deep coil clean", "Gas top-up". Each adds its price to the line total.
class ServiceAddon {
  final Id id;
  final String name;
  final String? description;

  /// Added to the line total when selected.
  final Money price;

  /// Extra minutes this add-on adds to the visit; optional (some take none).
  final int? duration;

  const ServiceAddon({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.duration,
  });

  factory ServiceAddon.fromJson(Map<String, dynamic> json) => ServiceAddon(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: Money.fromJson(json['price'] as Map<String, dynamic>),
        duration: (json['duration'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'price': price.toJson(),
        if (duration != null) 'duration': duration,
      };
}

/// A specific bookable service inside a category.
class Service {
  final Id id;
  final Id categoryId;
  final String name;
  final String slug;

  /// One-line teaser for list cards.
  final String? summary;

  /// Full description for the detail screen.
  final String? description;
  final ImageRef? image;

  /// Price shown on cards — typically the cheapest option (a "from" price).
  final Money basePrice;

  /// Typical duration in minutes; a chosen option may override it. 0 when the
  /// backend gives none.
  final int duration;

  /// Single-select sub-services. Empty = no options (book as-is).
  final List<ServiceOption> options;

  /// Multi-select extras. Empty = no add-ons offered.
  final List<ServiceAddon> addons;

  /// Denormalised rating for list UIs (server-computed), when present.
  final double? rating;
  final int? ratingCount;

  /// Hidden from browsing when false (kept for existing bookings' references).
  final bool active;

  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.basePrice,
    required this.duration,
    this.options = const [],
    this.addons = const [],
    this.summary,
    this.description,
    this.image,
    this.rating,
    this.ratingCount,
    this.active = true,
  });

  factory Service.fromJson(Map<String, dynamic> json) => Service(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        summary: json['summary'] as String?,
        description: json['description'] as String?,
        image: json['image'] == null
            ? null
            : ImageRef.fromJson(json['image'] as Map<String, dynamic>),
        basePrice: Money.fromJson(json['basePrice'] as Map<String, dynamic>),
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => ServiceOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        addons: (json['addons'] as List<dynamic>? ?? [])
            .map((e) => ServiceAddon.fromJson(e as Map<String, dynamic>))
            .toList(),
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['ratingCount'] as num?)?.toInt(),
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'slug': slug,
        if (summary != null) 'summary': summary,
        if (description != null) 'description': description,
        if (image != null) 'image': image!.toJson(),
        'basePrice': basePrice.toJson(),
        'duration': duration,
        'options': options.map((o) => o.toJson()).toList(),
        'addons': addons.map((a) => a.toJson()).toList(),
        if (rating != null) 'rating': rating,
        if (ratingCount != null) 'ratingCount': ratingCount,
        'active': active,
      };
}

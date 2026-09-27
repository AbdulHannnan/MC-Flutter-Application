// lib/src/models/common.dart — shared primitives the domain entities are built
// from. The Dart port of the RN app's `src/types/common.ts`.
//
// These are the small, reusable building blocks (ids, images) that the entities
// compose. Money — the most important primitive — lives in its own file
// (`money.dart`) because it carries real behaviour (major↔minor conversion,
// formatting, arithmetic), not just a shape.

/// Every entity's identifier — the id the backend assigns. Aliased as [Id]
/// rather than writing `String` everywhere so the intent is obvious (and we
/// could later swap in a wrapper type without churn). It is a plain `String`.
typedef Id = String;

/// A reference to an image: a URI plus optional alt text for accessibility.
/// Image URLs arrive from the backend as relative paths and are absolutized with
/// `assetUrl()` before being stored here (that adapting happens in the catalog
/// data layer, Module 6).
class ImageRef {
  final String uri;
  final String? alt;

  const ImageRef({required this.uri, this.alt});

  factory ImageRef.fromJson(Map<String, dynamic> json) => ImageRef(
        uri: json['uri'] as String,
        alt: json['alt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'uri': uri,
        if (alt != null) 'alt': alt,
      };

  @override
  bool operator ==(Object other) =>
      other is ImageRef && other.uri == uri && other.alt == alt;

  @override
  int get hashCode => Object.hash(uri, alt);
}

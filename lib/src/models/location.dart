// lib/src/models/location.dart — where the service is delivered. Dart port of
// the RN app's `src/types/location.ts`.
//
// After choosing a service and its add-ons, the user says WHERE the visit
// happens (Location step). This is CLIENT state the user assembles: a free-text
// address, an optional preset Dubai area, and a map pin. The pin comes from a
// MOCK picker today (preset-area centroid / simulated drop), not real device
// geolocation — but the shape is exactly what a real maps integration would
// produce, so swapping the picker's internals later touches only that widget.

/// A single geographic point. Mirrors what a real map/geocoder would return.
class LatLng {
  final double lat;
  final double lng;

  const LatLng({required this.lat, required this.lng});

  factory LatLng.fromJson(Map<String, dynamic> json) => LatLng(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// The address a booking is delivered to.
class BookingLocation {
  /// The free-text address the user typed, e.g. "Marina Gate 1, Apt 1204".
  final String addressText;

  /// A preset Dubai area picked from the chips, e.g. "Dubai Marina". Optional —
  /// a typed-only address may not map to one.
  final String? area;

  /// The map pin. From the mock picker today; a real geocode later.
  final LatLng? coords;

  /// Optional friendly label, e.g. "Home" or "Office".
  final String? label;

  const BookingLocation({
    required this.addressText,
    this.area,
    this.coords,
    this.label,
  });

  factory BookingLocation.fromJson(Map<String, dynamic> json) => BookingLocation(
        addressText: json['addressText'] as String,
        area: json['area'] as String?,
        coords: json['coords'] == null
            ? null
            : LatLng.fromJson(json['coords'] as Map<String, dynamic>),
        label: json['label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'addressText': addressText,
        if (area != null) 'area': area,
        if (coords != null) 'coords': coords!.toJson(),
        if (label != null) 'label': label,
      };
}

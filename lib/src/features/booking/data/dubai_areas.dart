// lib/src/features/booking/data/dubai_areas.dart — preset Dubai areas for the
// location step. Dart port of the RN app's `src/features/booking/data/dubaiAreas.ts`.
//
// A small, in-repo list of common Dubai areas the user can tap instead of typing a
// full address, each with an approximate centre coordinate. It powers the mock map
// picker (LocationPicker): selecting a chip drops the pin at that area's coords.
//
// MOCK, BY DESIGN: these coordinates are approximate area centroids, not a geocoded
// address — the app uses a lightweight picker rather than a real Google Maps/Places
// integration. The SHAPE matches what a real geocoder returns ([LatLng]), so
// swapping in the real thing later is isolated to the picker.

import '../../../models/models.dart';

/// A named Dubai area with its approximate centre coordinate.
class DubaiArea {
  final String name;
  final LatLng coords;
  const DubaiArea({required this.name, required this.coords});
}

/// The 12 preset areas, in display order (matches the RN list 1:1).
const List<DubaiArea> kDubaiAreas = [
  DubaiArea(name: 'Dubai Marina', coords: LatLng(lat: 25.0805, lng: 55.1403)),
  DubaiArea(name: 'JBR', coords: LatLng(lat: 25.0785, lng: 55.1330)),
  DubaiArea(name: 'Downtown Dubai', coords: LatLng(lat: 25.1972, lng: 55.2744)),
  DubaiArea(name: 'Business Bay', coords: LatLng(lat: 25.1857, lng: 55.2650)),
  DubaiArea(name: 'Jumeirah', coords: LatLng(lat: 25.2048, lng: 55.2400)),
  DubaiArea(name: 'Deira', coords: LatLng(lat: 25.2711, lng: 55.3095)),
  DubaiArea(name: 'Bur Dubai', coords: LatLng(lat: 25.2631, lng: 55.2972)),
  DubaiArea(name: 'JVC', coords: LatLng(lat: 25.0630, lng: 55.2090)),
  DubaiArea(name: 'Al Barsha', coords: LatLng(lat: 25.1128, lng: 55.1960)),
  DubaiArea(name: 'Silicon Oasis', coords: LatLng(lat: 25.1213, lng: 55.3773)),
  DubaiArea(name: 'Mirdif', coords: LatLng(lat: 25.2170, lng: 55.4200)),
  DubaiArea(name: 'The Springs', coords: LatLng(lat: 25.0530, lng: 55.1930)),
];

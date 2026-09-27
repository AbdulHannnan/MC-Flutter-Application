// lib/src/models — the shared, app-wide domain vocabulary (barrel). The Dart
// analog of the RN app's `src/types/index.ts`.
//
// The single import surface for the app's cross-feature models: feature code does
// `import 'package:microcare/src/models/models.dart';` rather than reaching into
// individual files.
//
//   common.dart    — Id, ImageRef                              (primitives)
//   money.dart     — Money, CurrencyCode                       (money + conversion)
//   service.dart   — ServiceCategory, Service, ServiceOption,
//                    ServiceAddon, acServicesCategory          (the catalog)
//   time_slot.dart — TimeSlot                                  (bookable slots)
//   location.dart  — LatLng, BookingLocation                   (where it happens)
//   cart.dart      — CartItem, CartAddon                       (the selection)
//   booking.dart   — Booking, BookingStatus                    (the order)

export 'booking.dart';
export 'cart.dart';
export 'common.dart';
export 'location.dart';
export 'money.dart';
export 'service.dart';
export 'time_slot.dart';

// Verifies every persistable domain model survives a toJson -> fromJson ->
// toJson round-trip unchanged. This is the cheap, high-value guarantee for the
// local-storage entities (cart, orders): what we persist we can restore exactly.
// Equality is checked on the JSON maps (deep) so we don't need `==` on the large
// aggregate types.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/models/models.dart';

void main() {
  const money = Money(amountMinor: 13500, currency: CurrencyCode.aed);

  const option = ServiceOption(
    id: 'opt1',
    name: 'Split AC (1 unit)',
    price: money,
    duration: 0,
    description: 'One indoor unit',
  );

  const addon = ServiceAddon(
    id: 'add1',
    name: 'Gas top-up',
    price: Money(amountMinor: 5000, currency: CurrencyCode.aed),
  );

  const service = Service(
    id: 'svc1',
    categoryId: 'ac-services',
    name: 'AC Deep Clean',
    slug: 'ac-deep-clean',
    basePrice: money,
    duration: 0,
    options: [option],
    addons: [addon],
    image: ImageRef(uri: 'http://localhost:5050/images/ac.jpg', alt: 'AC'),
    rating: 4.7,
    ratingCount: 32,
  );

  const location = BookingLocation(
    addressText: 'Marina Gate 1, Apt 1204',
    area: 'Dubai Marina',
    coords: LatLng(lat: 25.08, lng: 55.14),
    label: 'Home',
  );

  const slot = TimeSlot(
    id: 'slot-0900',
    start: '2026-09-01T09:00:00.000Z',
    end: '2026-09-01T10:00:00.000Z',
  );

  const cartItem = CartItem(
    id: 'line1',
    serviceId: 'svc1',
    optionId: 'opt1',
    quantity: 2,
    serviceName: 'AC Deep Clean',
    optionName: 'Split AC (1 unit)',
    unitPrice: money,
    addons: [CartAddon(id: 'add1', name: 'Gas top-up', price: money)],
    location: location,
    slot: slot,
    notes: 'Ring the bell twice',
  );

  const booking = Booking(
    id: 'bk1',
    reference: 'MC-2K4F9',
    userId: 'user1',
    status: BookingStatus.confirmed,
    items: [cartItem],
    slot: slot,
    location: location,
    subtotal: money,
    total: money,
    notes: 'Leave at reception',
    createdAt: '2026-09-01T08:00:00.000Z',
    paymentId: 'pay1',
  );

  void roundTrips(String name, Map<String, dynamic> json, Map<String, dynamic> Function(Map<String, dynamic>) reparse) {
    test('$name survives a JSON round-trip', () {
      expect(reparse(json), equals(json));
    });
  }

  group('domain model JSON round-trips', () {
    roundTrips('ImageRef', service.image!.toJson(),
        (j) => ImageRef.fromJson(j).toJson());
    roundTrips('ServiceOption', option.toJson(),
        (j) => ServiceOption.fromJson(j).toJson());
    roundTrips('ServiceAddon', addon.toJson(),
        (j) => ServiceAddon.fromJson(j).toJson());
    roundTrips('ServiceCategory', acServicesCategory.toJson(),
        (j) => ServiceCategory.fromJson(j).toJson());
    roundTrips('Service', service.toJson(),
        (j) => Service.fromJson(j).toJson());
    roundTrips('LatLng', location.coords!.toJson(),
        (j) => LatLng.fromJson(j).toJson());
    roundTrips('BookingLocation', location.toJson(),
        (j) => BookingLocation.fromJson(j).toJson());
    roundTrips('TimeSlot', slot.toJson(), (j) => TimeSlot.fromJson(j).toJson());
    roundTrips('CartItem', cartItem.toJson(),
        (j) => CartItem.fromJson(j).toJson());
    roundTrips('Booking', booking.toJson(),
        (j) => Booking.fromJson(j).toJson());
  });

  test('acServicesCategory is the synthetic single category', () {
    expect(acServicesCategory.id, 'ac-services');
    expect(acServicesCategory.name, 'AC Services');
  });
}

// The draft submit body (Module 14): buildDraftBody must honour the hard rules —
// top-level lowercase source:"app", NO prices, NO userId — and carry the confirmed
// fields (service/option/addons/quantity/schedule/location/customer/notes).

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/checkout/bookings_api.dart';
import 'package:microcare/src/models/models.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

CartItem _line() => CartItem(
      id: 'line_1',
      serviceId: 'svc_split_clean',
      optionId: 'opt_split_1',
      quantity: 2,
      serviceName: 'Split AC Deep Cleaning',
      optionName: '1 unit',
      unitPrice: _aed(9900),
      addons: [CartAddon(id: 'addon_gas', name: 'Gas top-up', price: _aed(2000))],
      location: const BookingLocation(
        addressText: 'Marina Gate 1',
        area: 'Dubai Marina',
        coords: LatLng(lat: 25.07, lng: 55.13),
      ),
      slot: const TimeSlot(
        id: 'slot_1',
        start: '2026-09-01T10:00:00.000',
        end: '2026-09-01T11:00:00.000',
      ),
      notes: 'Ring the bell twice',
    );

void main() {
  const customer =
      Customer(name: 'Jane Doe', phone: '0501234567', email: 'jane@example.com');

  test('sends source:"app" top-level and lowercase', () {
    final body = buildDraftBody(_line(), customer);
    expect(body['source'], 'app');
  });

  test('carries the configured fields', () {
    final body = buildDraftBody(_line(), customer);
    expect(body['serviceId'], 'svc_split_clean');
    expect(body['optionId'], 'opt_split_1');
    expect(body['addonIds'], ['addon_gas']);
    expect(body['quantity'], 2);
    expect(body['scheduledDate'], '2026-09-01T10:00:00.000');
    expect(body['scheduledTime'], '10:00 AM');
    expect((body['location'] as Map)['area'], 'Dubai Marina');
    expect((body['customer'] as Map)['email'], 'jane@example.com');
    expect(body['notes'], 'Ring the bell twice');
  });

  test('NEVER sends prices or userId', () {
    final body = buildDraftBody(_line(), customer);
    expect(body.containsKey('userId'), isFalse);
    expect(body.containsKey('unitPrice'), isFalse);
    expect(body.containsKey('total'), isFalse);
    expect(body.containsKey('price'), isFalse);
    // The customer sub-object must not smuggle a price either.
    expect((body['customer'] as Map).containsKey('price'), isFalse);
  });
}

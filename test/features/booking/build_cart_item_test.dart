// Regression: buildCartItem crashed on the WEB with
//   RangeError: max must be in range 0 < max ≤ 2^32, was 0
// because _makeLineId called Random().nextInt(1 << 32), and `1 << 32` is 0 under
// dart2js. That blocked Add-to-cart and Pay-now (both build a CartItem first).
//
// These assert buildCartItem succeeds for a Supabase-sourced draft (a Service
// mapped from a real Supabase catalog row) and mints a valid, unique line id.
// Run on `--platform chrome` to exercise the exact environment that failed.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/booking/booking_draft.dart';
import 'package:microcare/src/features/services/catalog_mappers.dart';
import 'package:microcare/src/models/models.dart';

// A Service built exactly as the Supabase catalog repo builds it (numeric prices,
// a uuid id, embedded options), so the draft is genuinely "Supabase-sourced".
Service _supabaseService() => mapService({
      'id': '2f3c1a9e-7b4d-4c2a-9e10-abcdef123456',
      'name': 'Split AC Deep Cleaning',
      'slug': 'split-ac-deep-cleaning',
      'description': 'Thorough coil + filter clean',
      'imageUrl': '/images/split.jpg',
      'isActive': true,
      'options': [
        {'id': 'opt_1', 'label': '1 unit', 'unitCount': 1, 'price': 99},
      ],
    });

BookingDraft _draft() {
  final service = _supabaseService();
  return BookingDraft(
    service: service,
    option: service.options.first,
    location: const BookingLocation(addressText: 'Marina Gate 1'),
    slot: const TimeSlot(
      id: 'slot_1',
      start: '2026-09-01T10:00:00.000',
      end: '2026-09-01T11:00:00.000',
    ),
  );
}

void main() {
  test('buildCartItem succeeds for a Supabase-sourced draft', () {
    final item = _draft().buildCartItem();

    expect(item, isNotNull);
    expect(item!.serviceId, '2f3c1a9e-7b4d-4c2a-9e10-abcdef123456');
    expect(item.optionId, 'opt_1');
    expect(item.unitPrice,
        const Money(amountMinor: 9900, currency: CurrencyCode.aed));
    // A non-empty line id that embeds the service id (the previously-crashing bit).
    expect(item.id, isNotEmpty);
    expect(item.id, startsWith('2f3c1a9e-7b4d-4c2a-9e10-abcdef123456__'));
  });

  test('each buildCartItem gets a distinct line id', () {
    final draft = _draft();
    final ids = {for (var i = 0; i < 50; i++) draft.buildCartItem()!.id};
    expect(ids.length, 50); // no collisions
  });

  test('buildCartItem returns null when no service is set', () {
    expect(const BookingDraft().buildCartItem(), isNull);
  });
}

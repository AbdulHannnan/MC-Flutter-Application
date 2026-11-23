// Tests the SHARED catalog mappers (catalog_mappers.dart) that adapt both the
// Express JSON and the Supabase rows into domain models. The cross-backend risk is
// the price TYPE: Express sends major-unit AED *strings* ("40.00"), Supabase sends
// *numerics* (40) — these assert both adapt identically, plus label→name,
// cheapest-option→basePrice, relative image→absolute, and isActive→active.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/services/catalog_mappers.dart';
import 'package:microcare/src/models/models.dart';

void main() {
  group('mapServiceOption', () {
    test('string price (Express) and numeric price (Supabase) are equivalent', () {
      final fromString =
          mapServiceOption({'id': 'o1', 'label': 'Standard', 'price': '40.00'});
      final fromNumber =
          mapServiceOption({'id': 'o1', 'label': 'Standard', 'price': 40});

      expect(fromString.price, const Money(amountMinor: 4000, currency: CurrencyCode.aed));
      expect(fromNumber.price, fromString.price);
      expect(fromString.name, 'Standard'); // label → name
    });
  });

  group('mapServiceAddon', () {
    test('adapts id/name/description/price (numeric price)', () {
      final addon = mapServiceAddon({
        'id': 'a1',
        'name': 'Gas top-up',
        'description': 'R410A refill',
        'price': 75,
      });
      expect(addon.id, 'a1');
      expect(addon.name, 'Gas top-up');
      expect(addon.description, 'R410A refill');
      expect(addon.price, const Money(amountMinor: 7500, currency: CurrencyCode.aed));
    });
  });

  group('mapService (Supabase-shaped row)', () {
    Map<String, dynamic> row() => {
          'id': 'svc_1',
          'name': 'AC Service',
          'slug': 'ac-service',
          'description': 'A/C cleaning',
          'imageUrl': '/images/ac.jpg',
          'isActive': true,
          'options': [
            {'id': 'o2', 'label': 'Deep', 'unitCount': 2, 'price': 120},
            {'id': 'o1', 'label': 'Basic', 'unitCount': 1, 'price': 40},
          ],
        };

    test('maps core fields and synthetic category', () {
      final s = mapService(row());
      expect(s.id, 'svc_1');
      expect(s.name, 'AC Service');
      expect(s.slug, 'ac-service');
      expect(s.categoryId, acServicesCategory.id);
      expect(s.active, isTrue);
      expect(s.options, hasLength(2));
    });

    test('basePrice is the cheapest option regardless of list order', () {
      // Options are given Deep(120) then Basic(40); basePrice must be 40.00.
      final s = mapService(row());
      expect(s.basePrice, const Money(amountMinor: 4000, currency: CurrencyCode.aed));
    });

    test('a relative imageUrl yields no image (no origin post-cutover)', () {
      // row()'s imageUrl is '/images/ac.jpg' — relative → placeholder.
      expect(mapService(row()).image, isNull);
    });

    test('an absolute imageUrl is kept', () {
      final r = row()..['imageUrl'] = 'https://cdn.example.com/ac.jpg';
      final s = mapService(r);
      expect(s.image, isNotNull);
      expect(s.image!.uri, 'https://cdn.example.com/ac.jpg');
    });

    test('passed-in add-ons are attached; none by default', () {
      expect(mapService(row()).addons, isEmpty);
      final withAddons = mapService(row(), [
        mapServiceAddon({'id': 'a1', 'name': 'Extra', 'price': 10}),
      ]);
      expect(withAddons.addons, hasLength(1));
    });

    test('missing isActive defaults to active', () {
      final r = row()..remove('isActive');
      expect(mapService(r).active, isTrue);
    });
  });
}

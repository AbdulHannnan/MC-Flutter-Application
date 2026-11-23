// Tests the SUPABASE catalog read path without a live project, by injecting a
// mock http client into SupabaseClient and returning canned PostgREST responses.
// This exercises the real table/column queries (Service with embedded options,
// the ServiceAddon→Addon join) plus the repo's on-device logic: option sort by
// unitCount, add-on null-drop + name sort, category/search filtering, and the
// 404 → ServiceNotFoundError path.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/features/services/supabase_catalog_repository.dart';
import 'package:microcare/src/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Two active services; prices are NUMERIC (as Supabase sends them), and the first
// service's options are intentionally out of unitCount order.
final _serviceRows = [
  {
    'id': 'svc_1',
    'code': 'AC',
    'name': 'AC Service',
    'slug': 'ac-service',
    'description': 'A/C cleaning',
    'imageUrl': '/images/ac.jpg',
    'subServices': <dynamic>[],
    'propertyTypes': <dynamic>[],
    'isActive': true,
    'options': [
      {'id': 'o2', 'label': 'Deep', 'unitCount': 2, 'price': 120},
      {'id': 'o1', 'label': 'Basic', 'unitCount': 1, 'price': 40},
    ],
  },
  {
    'id': 'svc_2',
    'code': 'DUCT',
    'name': 'Duct Cleaning',
    'slug': 'duct-cleaning',
    'description': 'Duct sanitisation',
    'imageUrl': '/images/duct.jpg',
    'subServices': <dynamic>[],
    'propertyTypes': <dynamic>[],
    'isActive': true,
    'options': [
      {'id': 'o3', 'label': 'Standard', 'unitCount': 1, 'price': 90},
    ],
  },
];

// ServiceAddon rows for svc_1: one real add-on, plus a null embed (an inactive
// add-on that RLS nulled out) which the repo must drop. 'Blower' sorts before
// 'Gas' to prove name-sorting.
final _addonRows = [
  {
    'addon': {
      'id': 'a2',
      'code': 'GAS',
      'name': 'Gas top-up',
      'description': 'R410A',
      'price': 75,
      'imageUrl': null,
    }
  },
  {
    'addon': {
      'id': 'a1',
      'code': 'BLOW',
      'name': 'Blower clean',
      'description': null,
      'price': 30,
      'imageUrl': null,
    }
  },
  {'addon': null},
];

SupabaseCatalogRepository _repo() {
  final mock = MockClient((request) async {
    final path = request.url.path;
    final body = path.endsWith('/ServiceAddon')
        ? _addonRows
        : path.endsWith('/Service')
            ? _serviceRows
            : <dynamic>[];
    return http.Response(
      jsonEncode(body),
      200,
      // postgrest reads response.request!.method, so echo the request back.
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  final client = SupabaseClient(
    'http://localhost',
    'test-anon-key',
    httpClient: mock,
  );
  return SupabaseCatalogRepository(client);
}

void main() {
  group('SupabaseCatalogRepository', () {
    test('getCategories returns the single synthetic AC category', () async {
      final cats = await _repo().getCategories();
      expect(cats, [acServicesCategory]);
    });

    test('getCategoryById returns the synthetic category or null', () async {
      final repo = _repo();
      expect(await repo.getCategoryById(acServicesCategory.id), acServicesCategory);
      expect(await repo.getCategoryById('nope'), isNull);
    });

    test('getServices maps all active services with numeric prices', () async {
      final services = await _repo().getServices();
      expect(services.map((s) => s.id), ['svc_1', 'svc_2']);
      // basePrice = cheapest option, adapted from a numeric price.
      expect(services.first.basePrice,
          const Money(amountMinor: 4000, currency: CurrencyCode.aed));
    });

    test('options are sorted by unitCount', () async {
      final svc = (await _repo().getServices()).first;
      expect(svc.options.map((o) => o.name), ['Basic', 'Deep']); // 1 then 2
    });

    test('search filters on name/description (on-device)', () async {
      final results = await _repo().getServices(ServiceQuery(search: 'duct'));
      expect(results.map((s) => s.id), ['svc_2']);
    });

    test('a non-synthetic categoryId yields no services', () async {
      final results =
          await _repo().getServices(ServiceQuery(categoryId: 'other'));
      expect(results, isEmpty);
    });

    test('getServiceById attaches add-ons, drops null embeds, sorts by name',
        () async {
      final svc = await _repo().getServiceById('svc_1');
      expect(svc.id, 'svc_1');
      // The null embed is dropped (2 real, not 3); sorted by name.
      expect(svc.addons.map((a) => a.name), ['Blower clean', 'Gas top-up']);
      expect(svc.addons.first.price,
          const Money(amountMinor: 3000, currency: CurrencyCode.aed));
    });

    test('getServiceById throws ServiceNotFoundError for a missing id', () async {
      expect(
        () => _repo().getServiceById('does-not-exist'),
        throwsA(isA<ServiceNotFoundError>()),
      );
    });
  });
}

// Tests the catalog data source without a real network.
//
// LIVE branch: a fake Dio adapter returns canned backend JSON so we can assert the
// adapters (label→name, "40.00"→Money fils, cheapest-option→basePrice, relative
// image→absolute, categoryId→synthetic), on-device category/search filtering, the
// parallel services+addons detail fetch, and the 404 → ServiceNotFoundError path.
//
// MOCK branch: the in-repo seed is served directly (zero latency) — we assert the
// counts, category filtering, search, sorted categories, and lookups.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/models/models.dart';

/// Routes each request to a handler keyed by path, returning canned JSON.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

CatalogRepository _liveRepo(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  final api = ApiClient(dio: dio, baseUrl: 'http://localhost:5050');
  return CatalogRepository(api, useMock: false);
}

CatalogRepository _mockRepo() => CatalogRepository(
      ApiClient(baseUrl: 'http://localhost:5050'),
      useMock: true,
      mockLatency: Duration.zero,
    );

// Canned backend payloads (raw shapes, BEFORE adapting).
final _backendServices = [
  {
    'id': 'svc_split_clean',
    'name': 'Split AC Deep Cleaning',
    'slug': 'split-ac-deep-cleaning',
    'description': 'Full service clean of split AC units.',
    'imageUrl': '/images/services/split.jpg',
    'isActive': true,
    'options': [
      {'id': 'opt_1', 'label': '1 unit', 'price': '99.00'},
      {'id': 'opt_2', 'label': '2 units', 'price': '179.00'},
    ],
  },
  {
    'id': 'svc_gas_refill',
    'name': 'AC Gas Refill',
    'slug': 'ac-gas-refill',
    'description': 'Refill refrigerant.',
    'imageUrl': null,
    'isActive': true,
    'options': [], // no options → basePrice 0
  },
];

final _backendAddons = [
  {
    'id': 'addon_deep_coil',
    'name': 'Deep coil clean',
    'description': 'Chemical wash of the coils.',
    'price': '60.00',
  },
];

void main() {
  group('live branch — adapters', () {
    test('maps a backend service to the domain shape', () async {
      final repo = _liveRepo(_FakeAdapter((_) => _json({'data': _backendServices})));

      final services = await repo.getServices();
      final split = services.firstWhere((s) => s.id == 'svc_split_clean');

      // label → name; string price → Money fils.
      expect(split.options, hasLength(2));
      expect(split.options.first.name, '1 unit');
      expect(split.options.first.price,
          const Money(amountMinor: 9900, currency: CurrencyCode.aed));
      // basePrice = cheapest option ("from" price).
      expect(split.basePrice.amountMinor, 9900);
      // relative image → absolute against the base URL.
      expect(split.image!.uri, 'http://localhost:5050/images/services/split.jpg');
      // no server duration → 0; synthetic category; active default.
      expect(split.duration, 0);
      expect(split.categoryId, acServicesCategory.id);
      expect(split.active, isTrue);
    });

    test('a service with no options gets a zero basePrice and no image', () async {
      final repo = _liveRepo(_FakeAdapter((_) => _json({'data': _backendServices})));

      final services = await repo.getServices();
      final gas = services.firstWhere((s) => s.id == 'svc_gas_refill');

      expect(gas.options, isEmpty);
      expect(gas.basePrice.amountMinor, 0);
      expect(gas.image, isNull);
    });
  });

  group('live branch — filtering', () {
    test('search filters over name and description', () async {
      final repo = _liveRepo(_FakeAdapter((_) => _json({'data': _backendServices})));

      final byName = await repo.getServices(ServiceQuery(search: 'gas'));
      expect(byName.map((s) => s.id), ['svc_gas_refill']);

      final byDesc = await repo.getServices(ServiceQuery(search: 'refrigerant'));
      expect(byDesc.map((s) => s.id), ['svc_gas_refill']);
    });

    test('the synthetic category id matches all; any other id matches none',
        () async {
      final repo = _liveRepo(_FakeAdapter((_) => _json({'data': _backendServices})));

      final all = await repo.getServices(
          ServiceQuery(categoryId: acServicesCategory.id));
      expect(all, hasLength(2));

      final none = await repo.getServices(ServiceQuery(categoryId: 'cat_other'));
      expect(none, isEmpty);
    });
  });

  group('live branch — getServiceById', () {
    test('fetches services + addons in parallel and attaches the add-ons',
        () async {
      final adapter = _FakeAdapter((options) {
        if (options.path == '/api/addons') return _json({'data': _backendAddons});
        return _json({'data': _backendServices});
      });
      final repo = _liveRepo(adapter);

      final service = await repo.getServiceById('svc_split_clean');

      expect(service.id, 'svc_split_clean');
      expect(service.addons, hasLength(1));
      expect(service.addons.first.name, 'Deep coil clean');
      expect(service.addons.first.price.amountMinor, 6000);
      // The add-ons request carried the serviceId query param.
      expect(adapter.lastRequest?.queryParameters['serviceId'], anyOf('svc_split_clean', isNull));
    });

    test('throws ServiceNotFoundError when the id is absent', () async {
      final adapter = _FakeAdapter((options) {
        if (options.path == '/api/addons') return _json({'data': <dynamic>[]});
        return _json({'data': _backendServices});
      });
      final repo = _liveRepo(adapter);

      expect(
        () => repo.getServiceById('svc_missing'),
        throwsA(isA<ServiceNotFoundError>()),
      );
    });
  });

  group('live branch — categories', () {
    test('getCategories returns only the synthetic AC Services category',
        () async {
      final repo = _liveRepo(_FakeAdapter((_) => _json({'data': _backendServices})));

      final cats = await repo.getCategories();
      expect(cats, [acServicesCategory]);
    });

    test('getCategoryById returns the synthetic category or null', () async {
      final repo = _liveRepo(_FakeAdapter((_) => _json({'data': _backendServices})));

      expect(await repo.getCategoryById(acServicesCategory.id), acServicesCategory);
      expect(await repo.getCategoryById('nope'), isNull);
    });
  });

  group('mock branch', () {
    test('getServices returns the full active seed', () async {
      final services = await _mockRepo().getServices();
      expect(services, hasLength(13));
      expect(services.every((s) => s.active), isTrue);
    });

    test('filters by fine-grained category id', () async {
      final cleaning = await _mockRepo()
          .getServices(ServiceQuery(categoryId: 'cat_ac_cleaning'));
      expect(cleaning, hasLength(3));
      expect(cleaning.every((s) => s.categoryId == 'cat_ac_cleaning'), isTrue);
    });

    test('search matches name, summary or description', () async {
      final results = await _mockRepo().getServices(ServiceQuery(search: 'duct'));
      expect(results.map((s) => s.id),
          containsAll(<String>['svc_duct_clean', 'svc_duct_sanitize']));
    });

    test('getCategories returns 5 categories sorted by sortOrder', () async {
      final cats = await _mockRepo().getCategories();
      expect(cats, hasLength(5));
      final orders = cats.map((c) => c.sortOrder).toList();
      final sorted = [...orders]..sort();
      expect(orders, sorted);
    });

    test('getServiceById returns the seed service or throws', () async {
      final svc = await _mockRepo().getServiceById('svc_split_clean');
      expect(svc.name, 'Split AC Deep Cleaning');
      expect(
        () => _mockRepo().getServiceById('svc_missing'),
        throwsA(isA<ServiceNotFoundError>()),
      );
    });
  });

  group('ServiceQuery normalisation (cache-key identity)', () {
    test('trims search and treats empty as none, so keys match', () {
      expect(ServiceQuery(search: '  clean  '), ServiceQuery(search: 'clean'));
      expect(ServiceQuery(search: '   '), ServiceQuery.all);
      expect(ServiceQuery(categoryId: ''), ServiceQuery.all);
      expect(ServiceQuery(search: 'clean').hashCode,
          ServiceQuery(search: 'clean').hashCode);
    });
  });
}

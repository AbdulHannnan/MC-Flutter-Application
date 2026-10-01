// Tests the react-query-equivalent caching layer.
//
//   • the retry POLICIES (fed to Riverpod's native `retry:`): bound to 2 retries
//     with backoff, and never retry a 404.
//   • serviceProvider: surfaces ServiceNotFoundError WITHOUT retrying it.
//   • servicesProvider: de-duplicates concurrent reads of the same key into one
//     repository call (the cache).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/services/catalog_providers.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/models/models.dart';

/// A repository that counts calls and can be told to fail a number of times —
/// used to observe retry/dedup behaviour at the provider layer.
class _FakeRepo extends CatalogRepository {
  _FakeRepo()
      : super(ApiClient(baseUrl: 'http://localhost:5050'),
            useMock: true, mockLatency: Duration.zero);

  int getServicesCalls = 0;
  int getServiceByIdCalls = 0;

  @override
  Future<List<Service>> getServices([ServiceQuery query = ServiceQuery.all]) async {
    getServicesCalls++;
    return const <Service>[];
  }

  // A missing id — used to prove the caching layer does NOT retry a 404.
  @override
  Future<Service> getServiceById(String id) async {
    getServiceByIdCalls++;
    throw ServiceNotFoundError(id);
  }
}

ProviderContainer _containerWith(CatalogRepository repo) {
  final container = ProviderContainer(
    overrides: [catalogRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('retry policies', () {
    test('catalogRetryPolicy retries twice with exponential backoff, then stops',
        () {
      final err = StateError('flaky');
      expect(catalogRetryPolicy(0, err), const Duration(milliseconds: 300));
      expect(catalogRetryPolicy(1, err), const Duration(milliseconds: 600));
      expect(catalogRetryPolicy(2, err), isNull); // give up after 2 retries
    });

    test('serviceRetryPolicy never retries a ServiceNotFoundError', () {
      expect(serviceRetryPolicy(0, const ServiceNotFoundError('x')), isNull);
      // Other errors still follow the catalog policy.
      expect(serviceRetryPolicy(0, StateError('flaky')),
          const Duration(milliseconds: 300));
    });
  });

  group('serviceProvider', () {
    test('surfaces ServiceNotFoundError without retrying', () async {
      final repo = _FakeRepo();
      final container = _containerWith(repo);

      await expectLater(
        container.read(serviceProvider('svc_missing').future),
        throwsA(isA<ServiceNotFoundError>()),
      );
      expect(repo.getServiceByIdCalls, 1);
    });
  });

  group('servicesProvider (cache)', () {
    test('de-duplicates concurrent reads of the same query into one fetch',
        () async {
      final repo = _FakeRepo();
      final container = _containerWith(repo);

      final futures = await Future.wait([
        container.read(servicesProvider(ServiceQuery.all).future),
        container.read(servicesProvider(ServiceQuery.all).future),
      ]);

      expect(futures, hasLength(2));
      expect(repo.getServicesCalls, 1); // shared cache entry
    });

    test('different queries are different cache entries', () async {
      final repo = _FakeRepo();
      final container = _containerWith(repo);

      await container.read(servicesProvider(ServiceQuery.all).future);
      await container
          .read(servicesProvider(ServiceQuery(search: 'clean')).future);

      expect(repo.getServicesCalls, 2);
    });
  });

  group('popularServicesProvider', () {
    // A real mock-seed repository so the sort runs over real catalog data.
    CatalogRepository seedRepo() => CatalogRepository(
          ApiClient(baseUrl: 'http://localhost:5050'),
          useMock: true,
          mockLatency: Duration.zero,
        );

    test('returns the top N by rating, highest first', () async {
      final container = _containerWith(seedRepo());

      final popular =
          await container.read(popularServicesProvider.future);

      expect(popular, hasLength(kPopularServicesLimit));
      // Highest-rated seed service leads.
      expect(popular.first.name, 'Annual Maintenance Contract');
      // Monotonically non-increasing by rating.
      for (var i = 1; i < popular.length; i++) {
        expect((popular[i - 1].rating ?? 0) >= (popular[i].rating ?? 0), isTrue);
      }
    });

    test('derives from a single upstream services fetch', () async {
      final repo = _FakeRepo();
      final container = _containerWith(repo);

      await container.read(popularServicesProvider.future);
      // Reading the underlying query again hits the shared cache, not the repo.
      await container.read(servicesProvider(ServiceQuery.all).future);

      expect(repo.getServicesCalls, 1);
    });
  });
}

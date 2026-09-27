// lib/src/features/services — the service-catalog feature's PUBLIC API (barrel).
// The Dart analog of the RN app's `src/features/services/index.ts`.
//
// Other features and the routing/UI layers import the catalog ONLY from here;
// the seed data stays private to the feature.
//
// Built so far:
//   Module 6 — the catalog data layer: the data source (CatalogRepository, live
//              adapters + mock seed) and the react-query-equivalent caching
//              providers (categories/services/service/category), with on-device
//              category/search filtering.
// Coming: catalog UI cards & screens (Modules 9–11).

export 'catalog_providers.dart'
    show
        categoriesProvider,
        categoryProvider,
        servicesProvider,
        serviceProvider,
        kCatalogStaleTime,
        kCatalogRetries,
        catalogRetryPolicy,
        serviceRetryPolicy;

export 'catalog_repository.dart'
    show
        CatalogRepository,
        catalogRepositoryProvider,
        ServiceQuery,
        ServiceNotFoundError;

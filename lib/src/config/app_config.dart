// lib/src/config/app_config.dart
//
// The single, TYPED access point for app configuration — the Flutter analog of
// the RN app's `src/lib/config.ts`.
//
// WHERE VALUES COME FROM:
// In RN, config flowed `.env` -> `app.config.ts` -> `extra` -> expo-constants.
// In Flutter we use COMPILE-TIME environment values passed with
// `--dart-define-from-file=config/dev.json` (or individual `--dart-define`s).
// Each key is read once here via `String.fromEnvironment` and normalised to a
// typed value, so screens never read raw strings or risk a typo. If we ever
// change where config comes from, we change it in this one file.
//
// RULE #7 / #8 — nothing sensitive and nothing hardcoded at call sites: only
// non-secret, client-safe values (which environment, which API URL, which
// mock/live flags) live here. Real payment/CRM/email keys are SERVER-side only
// and never read on the device.
//
// NOTE: every value below is `const`. The whole `config` object is resolved at
// compile time, so there is zero runtime parsing cost and the analyzer can see
// through it.

/// Which environment this build represents.
enum AppEnv { development, preview, production }

/// A per-feature data-source toggle: [mock] serves in-repo seed / local data;
/// [live] calls the real backend API. Catalog and bookings flip independently.
enum DataMode { mock, live }

/// Which payment implementation runs: the in-repo [mock], or the real N-Genius
/// SDK ([live]).
enum PaymentsMode { mock, live }

/// Whether REMOTE push-token registration is attempted. [mock] (default): local
/// notifications still work; no remote token is fetched or sent. [live]: attempt
/// real registration (also needs platform setup to actually succeed).
enum PushMode { mock, live }

/// Which N-Genius environment the `live` payments path targets.
enum NgeniusEnv { sandbox, production }

// ── Raw values read from the build environment ─────────────────────────────
// Defaults match the project README's flag table (base URL on :5050, catalog
// and bookings LIVE, payments and push MOCK, sandbox N-Genius). Passing
// `--dart-define-from-file=config/dev.json` overrides any of them.

const String _apiBaseUrlRaw =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5050');
const String _appEnvRaw =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');
const String _catalogModeRaw =
    String.fromEnvironment('CATALOG_MODE', defaultValue: 'live');
const String _bookingsModeRaw =
    String.fromEnvironment('BOOKINGS_MODE', defaultValue: 'live');
const String _paymentsModeRaw =
    String.fromEnvironment('PAYMENTS_MODE', defaultValue: 'mock');
const String _ngeniusEnvRaw =
    String.fromEnvironment('NGENIUS_ENV', defaultValue: 'sandbox');
const String _pushModeRaw =
    String.fromEnvironment('PUSH_MODE', defaultValue: 'mock');

// ── Normalisation (mirrors config.ts: anything not the expected token falls
//    back to the SAFE value) ─────────────────────────────────────────────────
// Catalog/bookings: the built-in default is `live` (README table), but any value
// other than exactly "live" resolves to `mock` — so a typo can never silently
// point a build at the wrong data source.

const AppEnv _appEnv = _appEnvRaw == 'production'
    ? AppEnv.production
    : (_appEnvRaw == 'preview' ? AppEnv.preview : AppEnv.development);

const DataMode _catalogMode =
    _catalogModeRaw == 'live' ? DataMode.live : DataMode.mock;
const DataMode _bookingsMode =
    _bookingsModeRaw == 'live' ? DataMode.live : DataMode.mock;
const PaymentsMode _paymentsMode =
    _paymentsModeRaw == 'live' ? PaymentsMode.live : PaymentsMode.mock;
const NgeniusEnv _ngeniusEnv =
    _ngeniusEnvRaw == 'production' ? NgeniusEnv.production : NgeniusEnv.sandbox;
const PushMode _pushMode =
    _pushModeRaw == 'live' ? PushMode.live : PushMode.mock;

// ── Nested config groups (mirrors the shape of config.ts's AppConfig) ───────

/// Service catalog source: where categories / services / add-ons come from.
class CatalogConfig {
  /// [DataMode.live] = `GET /api/services` + `/api/addons`; [DataMode.mock] = seed data.
  final DataMode mode;
  const CatalogConfig({required this.mode});
}

/// Bookings destination: where a submitted booking draft goes.
class BookingsConfig {
  /// [DataMode.live] = `POST /api/bookings/draft`; [DataMode.mock] = local storage.
  final DataMode mode;
  const BookingsConfig({required this.mode});
}

/// Payments: which implementation runs and, for `live`, which N-Genius env.
class PaymentsConfig {
  final PaymentsMode mode;
  final NgeniusEnv ngeniusEnv;
  const PaymentsConfig({required this.mode, required this.ngeniusEnv});
}

/// Push notifications: whether remote push-token registration is attempted.
class PushConfig {
  final PushMode mode;
  const PushConfig({required this.mode});
}

/// The typed, immutable configuration for this build.
class AppConfig {
  /// Which environment this build represents.
  final AppEnv appEnv;

  /// Base URL of the booking backend (talk ONLY to this over HTTP — rule #7).
  final String apiBaseUrl;

  final CatalogConfig catalog;
  final BookingsConfig bookings;
  final PaymentsConfig payments;
  final PushConfig push;

  const AppConfig({
    required this.appEnv,
    required this.apiBaseUrl,
    required this.catalog,
    required this.bookings,
    required this.payments,
    required this.push,
  });

  // Convenience flags so feature code reads clearly.
  bool get isDev => appEnv == AppEnv.development;
  bool get isProd => appEnv == AppEnv.production;
  bool get isMockCatalog => catalog.mode == DataMode.mock;
  bool get isMockBookings => bookings.mode == DataMode.mock;
  bool get isMockPayments => payments.mode == PaymentsMode.mock;
  bool get isMockPush => push.mode == PushMode.mock;

  /// A human-readable dump of the resolved config — used by the boot screen and
  /// logs to PROVE what the running build actually loaded.
  String describe() => [
        'appEnv        : ${appEnv.name}',
        'apiBaseUrl    : $apiBaseUrl',
        'catalog.mode  : ${catalog.mode.name}',
        'bookings.mode : ${bookings.mode.name}',
        'payments.mode : ${payments.mode.name}',
        'ngeniusEnv    : ${payments.ngeniusEnv.name}',
        'push.mode     : ${push.mode.name}',
      ].join('\n');
}

/// The single resolved config instance the whole app reads.
const AppConfig config = AppConfig(
  appEnv: _appEnv,
  apiBaseUrl: _apiBaseUrlRaw,
  catalog: CatalogConfig(mode: _catalogMode),
  bookings: BookingsConfig(mode: _bookingsMode),
  payments: PaymentsConfig(mode: _paymentsMode, ngeniusEnv: _ngeniusEnv),
  push: PushConfig(mode: _pushMode),
);

/// Whether [config.apiBaseUrl] looks usable. A loud dev-time check catches a
/// forgotten/empty config early instead of failing deep inside a network call.
bool get isApiBaseUrlValid => config.apiBaseUrl.trim().isNotEmpty;

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

/// Which REAL backend a `live` path talks to during the Express→Supabase
/// migration: the legacy [express] server (the proven fallback) or [supabase]
/// (Postgres + RLS + Edge Functions). Each path flips independently, one proven
/// module at a time; the default stays [express] until a path is verified.
enum Backend { express, supabase }

/// Where customer authentication runs: the in-app [mock] (local, dev-only — the
/// proven fallback) or real [supabase] Supabase Auth (email/password). Flips via
/// `AUTH_BACKEND`, default [mock] until verified on-device.
enum AuthBackend { mock, supabase }

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

// Supabase (the migrated backend): project URL + anon/public key. The anon key is
// FRONTEND-SAFE by design — it only identifies the project at the API gateway;
// Row-Level Security guards the data (rule #7 still holds: no service_role key, no
// DB credentials). So these are treated like [_apiBaseUrlRaw] (a plain config
// value), NOT a secret. Empty by default so a build with no Supabase config still
// boots on the Express/mock paths (foundation module introduces the seam only).
const String _supabaseUrlRaw =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String _supabaseAnonKeyRaw =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
const String _appEnvRaw =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');
const String _catalogModeRaw =
    String.fromEnvironment('CATALOG_MODE', defaultValue: 'live');
const String _bookingsModeRaw =
    String.fromEnvironment('BOOKINGS_MODE', defaultValue: 'live');
// Which backend each live path targets during the migration. Default `express`
// (the proven fallback); set to `supabase` once that path is verified on-device.
const String _catalogBackendRaw =
    String.fromEnvironment('CATALOG_BACKEND', defaultValue: 'express');
const String _bookingsBackendRaw =
    String.fromEnvironment('BOOKINGS_BACKEND', defaultValue: 'express');
const String _technicianBackendRaw =
    String.fromEnvironment('TECHNICIAN_BACKEND', defaultValue: 'express');
// Customer auth source. Default `mock` (the proven local fallback); set to
// `supabase` once real Supabase Auth is verified on-device.
const String _authBackendRaw =
    String.fromEnvironment('AUTH_BACKEND', defaultValue: 'mock');
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
// Anything other than exactly "supabase" resolves to express (the safe fallback),
// so a typo can never silently point a live path at the wrong backend.
const Backend _catalogBackend =
    _catalogBackendRaw == 'supabase' ? Backend.supabase : Backend.express;
const Backend _bookingsBackend =
    _bookingsBackendRaw == 'supabase' ? Backend.supabase : Backend.express;
const Backend _technicianBackend =
    _technicianBackendRaw == 'supabase' ? Backend.supabase : Backend.express;
// Anything other than exactly "supabase" resolves to mock (the safe fallback).
const AuthBackend _authBackend =
    _authBackendRaw == 'supabase' ? AuthBackend.supabase : AuthBackend.mock;
const PaymentsMode _paymentsMode =
    _paymentsModeRaw == 'live' ? PaymentsMode.live : PaymentsMode.mock;
const NgeniusEnv _ngeniusEnv =
    _ngeniusEnvRaw == 'production' ? NgeniusEnv.production : NgeniusEnv.sandbox;
const PushMode _pushMode =
    _pushModeRaw == 'live' ? PushMode.live : PushMode.mock;

// ── Nested config groups (mirrors the shape of config.ts's AppConfig) ───────

/// Service catalog source: where categories / services / add-ons come from.
class CatalogConfig {
  /// [DataMode.live] = the real catalog backend; [DataMode.mock] = seed data.
  final DataMode mode;

  /// When [mode] is live, which backend serves the catalog: [Backend.express]
  /// (`GET /api/services` + `/api/addons`) or [Backend.supabase] (supabase-js
  /// reads of the `Service`/`Addon` tables, RLS-guarded). Ignored when mock.
  final Backend backend;

  const CatalogConfig({required this.mode, this.backend = Backend.express});
}

/// Bookings destination: where a submitted booking goes.
class BookingsConfig {
  /// [DataMode.live] = a real booking backend; [DataMode.mock] = local storage.
  final DataMode mode;

  /// When [mode] is live, which backend receives the booking: [Backend.express]
  /// (`POST /api/bookings/draft`) or [Backend.supabase] (the create-draft →
  /// finalize-booking Edge Functions). Ignored when mock.
  final Backend backend;

  const BookingsConfig({required this.mode, this.backend = Backend.express});
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

  /// Base URL of the legacy Express booking backend (the fallback transport while
  /// each path is migrated to Supabase, one proven module at a time).
  final String apiBaseUrl;

  /// Supabase project URL (e.g. `https://<ref>.supabase.co`). Empty until
  /// configured; the migrated customer auth / catalog / booking-write and
  /// technician paths target this (`$supabaseUrl/functions/v1/<fn>` for Edge
  /// Functions, and supabase-js reads for the catalog).
  final String supabaseUrl;

  /// Supabase anon/public key — frontend-safe (RLS guards the data). Sent as the
  /// `apikey`/Bearer on Supabase calls. Empty until configured.
  final String supabaseAnonKey;

  /// Where customer authentication runs (mock vs real Supabase Auth).
  final AuthBackend authBackend;

  /// Which backend serves the technician (staff) auth + jobs: [Backend.express]
  /// (`/api/technician/*`) or [Backend.supabase] (the `technician` Edge Function).
  final Backend technicianBackend;

  final CatalogConfig catalog;
  final BookingsConfig bookings;
  final PaymentsConfig payments;
  final PushConfig push;

  const AppConfig({
    required this.appEnv,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authBackend,
    required this.technicianBackend,
    required this.catalog,
    required this.bookings,
    required this.payments,
    required this.push,
  });

  // Convenience flags so feature code reads clearly.
  bool get isDev => appEnv == AppEnv.development;
  bool get isProd => appEnv == AppEnv.production;
  bool get isMockCatalog => catalog.mode == DataMode.mock;

  /// True when the catalog should be served from Supabase: a live catalog whose
  /// backend is Supabase AND Supabase is actually configured. Falls back to
  /// Express if the flag is set but no URL/key is present (safe by default).
  bool get isSupabaseCatalog =>
      catalog.mode == DataMode.live &&
      catalog.backend == Backend.supabase &&
      isSupabaseConfigured;

  /// True when customer auth should run on Supabase Auth: the flag is supabase
  /// AND Supabase is configured. Falls back to the mock otherwise (safe default).
  bool get isSupabaseAuth =>
      authBackend == AuthBackend.supabase && isSupabaseConfigured;

  /// True when the technician path should use the Supabase `technician` Edge
  /// Function: the flag is supabase AND Supabase is configured. (The technician
  /// auth is a parallel custom JWT — it does NOT need a customer Supabase session,
  /// so this is independent of [isSupabaseAuth].) Falls back to Express otherwise.
  bool get isSupabaseTechnician =>
      technicianBackend == Backend.supabase && isSupabaseConfigured;
  bool get isMockBookings => bookings.mode == DataMode.mock;

  /// True when booking writes should go to the Supabase Edge Functions: a live
  /// bookings path whose backend is Supabase AND Supabase is configured. Falls
  /// back to Express otherwise. NOTE: the Supabase path's finalize step requires a
  /// signed-in Supabase session, so pair it with `AUTH_BACKEND=supabase`.
  bool get isSupabaseBookings =>
      bookings.mode == DataMode.live &&
      bookings.backend == Backend.supabase &&
      isSupabaseConfigured;
  bool get isMockPayments => payments.mode == PaymentsMode.mock;
  bool get isMockPush => push.mode == PushMode.mock;

  /// Whether a usable Supabase URL + anon key are present. The migrated paths
  /// require this; until it's true the app stays on the Express/mock fallbacks.
  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// A human-readable dump of the resolved config — used by the boot screen and
  /// logs to PROVE what the running build actually loaded. The anon key is only
  /// reported as present/absent (not printed), to keep logs tidy — it's not a
  /// secret, just noise.
  String describe() => [
        'appEnv        : ${appEnv.name}',
        'apiBaseUrl    : $apiBaseUrl',
        'supabaseUrl   : ${supabaseUrl.isEmpty ? '(unset)' : supabaseUrl}',
        'supabaseKey   : ${supabaseAnonKey.isEmpty ? '(unset)' : 'present'}',
        'supabaseReady : $isSupabaseConfigured',
        'authBackend   : ${authBackend.name}${isSupabaseAuth ? ' (active)' : ''}',
        'techBackend   : ${technicianBackend.name}${isSupabaseTechnician ? ' (active)' : ''}',
        'catalog.mode  : ${catalog.mode.name}',
        'catalog.backend: ${catalog.backend.name}${isSupabaseCatalog ? ' (active)' : ''}',
        'bookings.mode : ${bookings.mode.name}',
        'bookings.backend: ${bookings.backend.name}${isSupabaseBookings ? ' (active)' : ''}',
        'payments.mode : ${payments.mode.name}',
        'ngeniusEnv    : ${payments.ngeniusEnv.name}',
        'push.mode     : ${push.mode.name}',
      ].join('\n');
}

/// The single resolved config instance the whole app reads.
const AppConfig config = AppConfig(
  appEnv: _appEnv,
  apiBaseUrl: _apiBaseUrlRaw,
  supabaseUrl: _supabaseUrlRaw,
  supabaseAnonKey: _supabaseAnonKeyRaw,
  authBackend: _authBackend,
  technicianBackend: _technicianBackend,
  catalog: CatalogConfig(mode: _catalogMode, backend: _catalogBackend),
  bookings: BookingsConfig(mode: _bookingsMode, backend: _bookingsBackend),
  payments: PaymentsConfig(mode: _paymentsMode, ngeniusEnv: _ngeniusEnv),
  push: PushConfig(mode: _pushMode),
);

/// Whether [config.apiBaseUrl] looks usable. A loud dev-time check catches a
/// forgotten/empty config early instead of failing deep inside a network call.
bool get isApiBaseUrlValid => config.apiBaseUrl.trim().isNotEmpty;

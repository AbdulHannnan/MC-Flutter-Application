// lib/src/config/app_config.dart
//
// The single, TYPED access point for app configuration — the Flutter analog of
// the RN app's `src/lib/config.ts`.
//
// WHERE VALUES COME FROM:
// COMPILE-TIME environment values passed with `--dart-define-from-file=config/
// dev.json` (or individual `--dart-define`s). Each key is read once here via
// `String.fromEnvironment` and normalised to a typed value, so screens never read
// raw strings or risk a typo.
//
// The app talks to ONE backend: Supabase (Auth + RLS-guarded catalog reads + the
// booking/technician Edge Functions). Only a non-secret, client-safe URL + anon
// key live here. The anon key is FRONTEND-SAFE by design — it only identifies the
// project at the API gateway; Row-Level Security guards the data. No service_role
// key, no DB credentials, ever on the device.
//
// NOTE: every value below is `const`. The whole `config` object is resolved at
// compile time, so there is zero runtime parsing cost and the analyzer can see
// through it.

/// Which environment this build represents.
enum AppEnv { development, preview, production }

/// Whether REMOTE push-token registration is attempted. [mock] (default): local
/// notifications still work; no remote token is fetched or sent. [live]: attempt
/// real registration (also needs platform setup to actually succeed).
enum PushMode { mock, live }

// ── Raw values read from the build environment ─────────────────────────────

const String _appEnvRaw =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');

// Supabase project URL + anon/public key. Empty by default; supplied via
// config/dev.json. Empty ⇒ Supabase can't initialise (the app needs these).
const String _supabaseUrlRaw =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String _supabaseAnonKeyRaw =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

const String _pushModeRaw =
    String.fromEnvironment('PUSH_MODE', defaultValue: 'mock');

// ── Normalisation (anything not the expected token falls back to the SAFE value) ──

const AppEnv _appEnv = _appEnvRaw == 'production'
    ? AppEnv.production
    : (_appEnvRaw == 'preview' ? AppEnv.preview : AppEnv.development);

const PushMode _pushMode =
    _pushModeRaw == 'live' ? PushMode.live : PushMode.mock;

/// Push notifications: whether remote push-token registration is attempted.
class PushConfig {
  final PushMode mode;
  const PushConfig({required this.mode});
}

/// The typed, immutable configuration for this build.
class AppConfig {
  /// Which environment this build represents.
  final AppEnv appEnv;

  /// Supabase project URL (e.g. `https://<ref>.supabase.co`). Empty until
  /// configured; the whole backend targets this (`$supabaseUrl/functions/v1/<fn>`
  /// for Edge Functions, and supabase-js reads for the catalog).
  final String supabaseUrl;

  /// Supabase anon/public key — frontend-safe (RLS guards the data). Sent as the
  /// `apikey`/Bearer on Supabase calls. Empty until configured.
  final String supabaseAnonKey;

  final PushConfig push;

  const AppConfig({
    required this.appEnv,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.push,
  });

  bool get isDev => appEnv == AppEnv.development;
  bool get isProd => appEnv == AppEnv.production;
  bool get isMockPush => push.mode == PushMode.mock;

  /// Whether a usable Supabase URL + anon key are present. The app needs this to
  /// initialise its backend; a build without it boots but can't reach Supabase.
  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// A human-readable dump of the resolved config — used by the boot screen and
  /// logs to PROVE what the running build actually loaded. The anon key is only
  /// reported as present/absent (not printed) — it's not a secret, just noise.
  String describe() => [
        'appEnv        : ${appEnv.name}',
        'supabaseUrl   : ${supabaseUrl.isEmpty ? '(unset)' : supabaseUrl}',
        'supabaseKey   : ${supabaseAnonKey.isEmpty ? '(unset)' : 'present'}',
        'supabaseReady : $isSupabaseConfigured',
        'push.mode     : ${push.mode.name}',
      ].join('\n');
}

/// The single resolved config instance the whole app reads.
const AppConfig config = AppConfig(
  appEnv: _appEnv,
  supabaseUrl: _supabaseUrlRaw,
  supabaseAnonKey: _supabaseAnonKeyRaw,
  push: PushConfig(mode: _pushMode),
);

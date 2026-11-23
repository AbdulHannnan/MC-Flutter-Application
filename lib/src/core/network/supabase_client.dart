// lib/src/core/network/supabase_client.dart — the app's single Supabase client.
//
// The migrated backend (Postgres + RLS + Edge Functions + Supabase Auth) replaces
// the legacy Express server, one proven path at a time. This file owns the ONE
// shared `SupabaseClient` the whole app uses for:
//   • customer auth (email/password)  — `client.auth`
//   • catalog reads (RLS-guarded)     — `client.from(...)`
//   • booking writes + technician fns — `client.functions.invoke(...)`
//     (hit `<SUPABASE_URL>/functions/v1/<name>`; the client attaches the `apikey`
//      and the signed-in user's Bearer token automatically).
//
// Mirrors the booking website's `supabaseClient.js` init: a persisted, auto-
// refreshing session so a signed-in customer stays signed in across restarts.
//
// FOUNDATION-ONLY (this module): we initialise the client and expose it; NOTHING
// is re-pointed at it yet. Each later module flips one path (catalog, auth,
// bookings, technician) from the Express/mock fallback to this client, and only
// after it's proven on a device.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';

/// Initialise Supabase once at startup, BEFORE `runApp`. A no-op (returns false)
/// when the project URL + anon key aren't configured, so a build with no Supabase
/// config still boots on the Express/mock fallbacks instead of throwing — matching
/// the website's "preview without keys" behaviour.
///
/// Returns true when the client was initialised and is ready to use.
Future<bool> initSupabase() async {
  if (!config.isSupabaseConfigured) return false;
  await Supabase.initialize(
    url: config.supabaseUrl,
    // The classic project ANON key (a JWT), as the booking website uses and as
    // the user supplies. supabase_flutter 2.18 deprecates `anonKey` in favour of
    // `publishableKey` (the newer `sb_publishable_…` format), but a classic anon
    // key belongs on `anonKey` — so we keep it and silence the deprecation here.
    // ignore: deprecated_member_use
    anonKey: config.supabaseAnonKey,
    // Persist + auto-refresh the customer's session across app restarts (the
    // Flutter analog of the website's localStorage persistence). Uses
    // flutter_secure_storage under the hood on mobile.
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );
  return true;
}

/// The one [SupabaseClient] the app shares. Reads the already-initialised
/// singleton — so screens/repositories depend on THIS provider (overridable with a
/// fake in tests) rather than reaching for the global `Supabase.instance`.
///
/// Throws if read before [initSupabase] succeeded (i.e. Supabase isn't
/// configured): callers must gate on `config.isSupabaseConfigured` the same way
/// the mode flags gate the Express/mock paths — no path reads this yet.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

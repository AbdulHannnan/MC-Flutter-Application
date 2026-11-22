// lib/src/features/technician/technician_session.dart — the TECHNICIAN session:
// the app-wide source of truth for "which technician is signed in".
//
// A parallel, separate auth from the customer `sessionProvider` (mock/Clerk): a
// technician authenticates against the real backend and holds a JWT. The router
// treats a signed-in technician as its own experience (the staff area), taking
// precedence over any customer session.
//
// State maps onto `AsyncValue<Technician?>` exactly like the customer session:
//   • loading   → restoring a saved token on cold start (show the splash).
//   • data(null)→ signed out (show the technician login).
//   • data(t)   → signed in as technician t.
// Cold start restores from the cached token+profile (no blocking network); an
// invalid/expired token is caught on the first real request (Modules 2+) and ends
// the session there.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/technician.dart';
import 'data/technician_api.dart';
import 'data/technician_token_store.dart';

class TechnicianSessionController extends AsyncNotifier<Technician?> {
  TechnicianTokenStore get _store => ref.read(technicianTokenStoreProvider);

  /// Cold-start restore. A stored token means "signed in"; prefer the cached
  /// profile (instant) and fall back to `/me` only when the profile is missing.
  /// Any failure resolves to signed-out (null), never an error state that would
  /// trap the app on the splash.
  @override
  FutureOr<Technician?> build() async {
    try {
      final token = await _store.readToken();
      if (token == null || token.isEmpty) return null;

      final cached = await _store.readTechnician();
      if (cached != null) return cached;

      // Token but no cached profile — validate it to recover the profile.
      return await ref.read(technicianApiProvider).me();
    } catch (_) {
      return null;
    }
  }

  /// Sign in against the backend. On success the token + profile are persisted
  /// securely and the session flips to signed-in. Throws (e.g. [ApiException] on
  /// bad credentials) for the screen to surface; leaves the session unchanged.
  Future<Technician> login({
    required String username,
    required String password,
  }) async {
    final result = await ref.read(technicianApiProvider).login(
          username: username.trim(),
          password: password,
        );
    await _store.save(token: result.token, technician: result.technician);
    state = AsyncData(result.technician);
    return result.technician;
  }

  /// End the technician session: wipe the stored token + profile.
  Future<void> logout() async {
    await _store.clear();
    state = const AsyncData(null);
  }
}

/// The app-wide technician session. Screens read this; only the controller writes it.
final technicianSessionProvider =
    AsyncNotifierProvider<TechnicianSessionController, Technician?>(
  TechnicianSessionController.new,
);

/// Backend-agnostic reads of the technician session (mirrors the customer SessionX).
extension TechnicianSessionX on AsyncValue<Technician?> {
  /// True only when a technician is confirmed signed in.
  bool get isSignedIn => value != null;

  /// True while still restoring a saved token on cold start.
  bool get isRestoring => isLoading;

  /// The signed-in technician, or null.
  Technician? get technician => value;
}

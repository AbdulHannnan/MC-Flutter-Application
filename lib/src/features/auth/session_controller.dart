// lib/src/features/auth/session_controller.dart — the app's session state.
//
// Consolidates what the RN app spread across a zustand store (the session mirror),
// AuthProvider (cold-start restore) and four flow hooks (login/signup/reset/logout)
// into ONE idiomatic Riverpod AsyncNotifier. It restores a saved session on build,
// and exposes the sign-in / sign-up / reset / sign-out actions. Screens hold their
// own submitting/error UI state and call these; the notifier owns "who is signed
// in", the app-wide source of truth.
//
// SESSION STATE maps onto Riverpod's `AsyncValue<AuthUser?>` — the tri-state the RN
// `SessionStatus` had:
//   • loading   → `AsyncLoading` (still restoring on cold start → show a splash).
//   • signedOut → `AsyncData(null)`.
//   • signedIn  → `AsyncData(user)`.
// Read it through the [SessionX] helpers below so screens don't re-derive that.
//
// THE SEAM: this talks to [mockAuthApiProvider] only. Swap the backend later and
// only the provider changes; every screen that reads [sessionProvider] keeps
// working — exactly the point of the provider-agnostic session model.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/cart.dart';
import 'auth_user.dart';
import 'mock_auth_api.dart';

class SessionController extends AsyncNotifier<AuthUser?> {
  MockAuthApi get _api => ref.read(mockAuthApiProvider);

  /// Cold-start restore: ask the mock backend whether a session is saved. A read
  /// failure means "we can't prove a session" → signed out (null), never an error
  /// state (which would block the app on a splash).
  @override
  FutureOr<AuthUser?> build() async {
    try {
      return await _api.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  /// Sign in against the mock backend. On success the session flips to signedIn and
  /// the caller navigates. A wrong-credentials [AuthError] is rethrown for the
  /// screen to show as a form-level error (the session state is left unchanged).
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _api.signIn(email: email, password: password);
    state = AsyncData(user);
    return user;
  }

  /// Create an account and sign in. Throws [AuthError] (e.g. email taken) for the
  /// screen to surface; leaves the session unchanged on failure.
  Future<AuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final user = await _api.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
    state = AsyncData(user);
    return user;
  }

  /// Set a new password for an existing email and sign that user in. Throws
  /// [AuthError] (e.g. no account) for the screen to surface.
  Future<AuthUser> resetPassword({
    required String email,
    required String password,
  }) async {
    final user = await _api.resetPassword(email: email, password: password);
    state = AsyncData(user);
    return user;
  }

  /// End the session (users are kept). The cart is the previous user's, so it's
  /// cleared here (Module 13); routing follows the state change (Module 8).
  Future<void> signOut() async {
    await _api.signOut();
    ref.read(cartProvider.notifier).clear();
    state = const AsyncData(null);
  }
}

/// The app-wide session. Screens read this; only [SessionController] writes it.
final sessionProvider =
    AsyncNotifierProvider<SessionController, AuthUser?>(SessionController.new);

/// Backend-agnostic reads of the session — the analog of the RN `useSession()`
/// shape (`isSignedIn` / `isLoading` / `user`), derived from the AsyncValue.
extension SessionX on AsyncValue<AuthUser?> {
  /// True only when we have a confirmed signed-in user. (Signed-out is
  /// `AsyncData(null)` and restoring is `AsyncLoading`, so a non-null value means
  /// signed in.)
  bool get isSignedIn => value != null;

  /// True while we still don't know (restoring on cold start) — show a splash, not
  /// the login screen. (Only the initial restore is loading; the flow actions keep
  /// their submitting state on the screens, not here.)
  bool get isRestoring => isLoading;

  /// The signed-in user, or null when signed out / still restoring.
  AuthUser? get user => value;
}

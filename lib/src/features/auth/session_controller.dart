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
// THE SEAM: this talks to [customerAuthApiProvider] (Supabase Auth) only. Every
// screen reads [sessionProvider], not the backend — the point of the
// provider-agnostic session model (and what lets tests inject a fake auth api).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client.dart';
import '../cart/cart.dart';
import '../orders/orders_repository.dart';
import 'auth_user.dart';
import 'customer_auth_api.dart';
import 'supabase_auth_api.dart';

/// The customer-auth backend: Supabase Auth. Exposed as the [CustomerAuthApi]
/// seam so tests can override it with an in-memory fake.
final customerAuthApiProvider = Provider<CustomerAuthApi>(
  (ref) => SupabaseAuthApi(ref.watch(supabaseClientProvider)),
);

class SessionController extends AsyncNotifier<AuthUser?> {
  CustomerAuthApi get _api => ref.read(customerAuthApiProvider);

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

  /// Begin a password reset: the backend emails a recovery link the user
  /// completes outside the app. Does NOT change the session (they return and sign
  /// in). Throws [AuthError] for the screen to surface. Resolves without revealing
  /// whether the email has an account.
  Future<void> sendPasswordReset({required String email}) =>
      _api.sendPasswordReset(email: email);

  /// End the session (users are kept). The cart (Module 13) and local order
  /// history (Module 14) belong to the previous user, so both are cleared here;
  /// routing follows the state change (Module 8).
  Future<void> signOut() async {
    await _api.signOut();
    ref.read(cartProvider.notifier).clear();
    await ref.read(ordersRepositoryProvider).clear();
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

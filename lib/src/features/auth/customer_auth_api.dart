// lib/src/features/auth/customer_auth_api.dart — the customer-auth contract the
// session layer depends on, so the backend can be swapped behind it.
//
// [SupabaseAuthApi] implements this (real Supabase Auth); [customerAuthApiProvider]
// wires it, and [SessionController] speaks only this interface so tests can override
// it with an in-memory fake. Failures surface as [AuthError] (a user-facing message)
// so the screens' `on AuthError` handling stays backend-agnostic.

import 'auth_user.dart';

/// A typed auth failure carrying a user-facing message (mirrors a backend 4xx).
/// Thrown by [CustomerAuthApi] implementations; screens catch it to show a
/// form-level error.
class AuthError implements Exception {
  final String message;
  const AuthError(this.message);

  @override
  String toString() => 'AuthError: $message';
}

/// The backend-agnostic customer-auth operations. Returns the provider-agnostic
/// [AuthUser]; throws [AuthError] on failure.
abstract interface class CustomerAuthApi {
  /// The signed-in user restored from a persisted session, or null if none.
  Future<AuthUser?> getCurrentUser();

  /// Sign in with email + password. Throws [AuthError] on bad credentials.
  Future<AuthUser> signIn({required String email, required String password});

  /// Create an account and sign in. [fullName] is split into first/last names.
  /// Throws [AuthError] (e.g. email already registered).
  Future<AuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// Begin a password reset for [email]: the backend emails a recovery link the
  /// user completes outside the app, then signs in. Does NOT change the session.
  /// Resolves whether or not the email has an account (never reveals existence).
  Future<void> sendPasswordReset({required String email});

  /// End the current session.
  Future<void> signOut();
}

/// Split a free-text full name into first/last parts (+ a display fullName),
/// tolerating extra spaces. Shared by the backends so a signup name is stored
/// the same way regardless of who persists it.
({String? firstName, String? lastName, String? fullName}) splitFullName(
    String fullName) {
  final parts =
      fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return (
    firstName: parts.isNotEmpty ? parts.first : null,
    lastName: parts.length > 1 ? parts.sublist(1).join(' ') : null,
    fullName: parts.isEmpty ? null : parts.join(' '),
  );
}

/// A generated placeholder avatar so [AuthUser.imageUrl] is always a real URL
/// (Supabase Auth email/password accounts have no avatar).
String avatarUrlFor(String name) {
  final trimmed = name.trim();
  final encoded = Uri.encodeComponent(trimmed.isEmpty ? 'User' : trimmed);
  return 'https://ui-avatars.com/api/?name=$encoded&background=random';
}

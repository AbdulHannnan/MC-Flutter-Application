// lib/src/features/auth/supabase_auth_api.dart — customer auth on SUPABASE AUTH
// (email/password). The real replacement for the local [MockAuthApi].
//
// A faithful port of the booking website's AuthProvider (the proven client of the
// same project): sign-up stashes {firstName, lastName} in user_metadata so the
// backend can read them from the verified JWT; sign-in uses password grant;
// session is the one persisted + auto-refreshed by Supabase.initialize(); reset
// emails a recovery link the user completes outside the app.
//
// "Confirm email" is OFF on this project, so a fresh sign-up returns a session
// immediately (we still guard the null-session case loudly, in case that changes).
//
// All failures are normalised to [AuthError] (a user-facing message), so the
// screens' `on AuthError` handling is identical to the mock path. Because this
// uses the SHARED [SupabaseClient], a successful sign-in makes the user's access
// token available to every other Supabase call (Edge Functions / RLS reads) — the
// token is carried automatically, no manual wiring.

// Hide Supabase's own `AuthUser` so our domain [AuthUser] is unambiguous; we map
// from Supabase's `User` type instead.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'auth_user.dart';
import 'customer_auth_api.dart';
import 'mock_auth_api.dart' show AuthError;

/// Map a Supabase [User] → our provider-agnostic [AuthUser]. first/last names come
/// from the metadata set at sign-up; the display name is derived; the avatar is a
/// generated placeholder (email/password accounts have none). Role is always
/// customer — technicians authenticate on the separate technician JWT path.
AuthUser mapSupabaseUser(User user) {
  final meta = user.userMetadata ?? const {};
  final firstName = (meta['firstName'] as String?)?.trim();
  final lastName = (meta['lastName'] as String?)?.trim();

  final fullName = [firstName, lastName]
      .where((p) => p != null && p.isNotEmpty)
      .join(' ')
      .trim();
  final display = fullName.isNotEmpty ? fullName : (user.email ?? 'User');

  return AuthUser(
    id: user.id,
    email: user.email,
    firstName: (firstName != null && firstName.isNotEmpty) ? firstName : null,
    lastName: (lastName != null && lastName.isNotEmpty) ? lastName : null,
    fullName: fullName.isNotEmpty ? fullName : null,
    imageUrl: avatarUrlFor(display),
    role: UserRole.customer,
  );
}

/// Normalise a Supabase [AuthException] into a user-facing [AuthError], softening
/// the few messages worth rewording and passing the rest through.
AuthError authErrorFrom(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('invalid login credentials')) {
    return const AuthError('Invalid email or password.');
  }
  if (msg.contains('already registered') || msg.contains('already been registered')) {
    return const AuthError('An account with this email already exists.');
  }
  if (msg.contains('password') && msg.contains('at least')) {
    return AuthError(e.message); // Supabase's own min-length wording is fine.
  }
  return AuthError(e.message);
}

class SupabaseAuthApi implements CustomerAuthApi {
  SupabaseAuthApi(this._sb);

  final SupabaseClient _sb;

  GoTrueClient get _auth => _sb.auth;

  @override
  Future<AuthUser?> getCurrentUser() async {
    // Supabase.initialize() has already restored any persisted session, so the
    // current user is available synchronously. Null = signed out.
    final user = _auth.currentUser;
    return user == null ? null : mapSupabaseUser(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) throw const AuthError('Invalid email or password.');
      return mapSupabaseUser(user);
    } on AuthException catch (e) {
      throw authErrorFrom(e);
    }
  }

  @override
  Future<AuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final parts = splitFullName(fullName);
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          if (parts.firstName != null) 'firstName': parts.firstName,
          if (parts.lastName != null) 'lastName': parts.lastName,
        },
      );
      final user = res.user;
      // With email-confirmation OFF the session+user come back immediately. A
      // null session would mean confirmation is on again — surface it clearly
      // instead of silently appearing signed-out.
      if (user == null || res.session == null) {
        throw const AuthError(
            'Please check your email to confirm your account, then sign in.');
      }
      return mapSupabaseUser(user);
    } on AuthException catch (e) {
      throw authErrorFrom(e);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      // Emails a recovery link (to the project's Site URL / hosted reset page).
      // Resolves regardless of whether the email has an account.
      await _auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw authErrorFrom(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// lib/src/features/auth/mock_auth_api.dart — a LOCAL, in-app fake auth backend.
// Dart port of the RN app's `src/features/auth/mockAuthApi.ts`.
//
// There is no external auth provider. This module stands in for "the auth server":
// it stores users and the current session in the device's own key-value store
// (shared_preferences — the analog of RN's AsyncStorage) — no network, no external
// service. It's a seam: the rest of the app speaks only [AuthUser] and never learns
// how auth is implemented, so a real provider can replace THIS one file.
//
// ⚠️ IT IS A MOCK — NOT SECURE. Passwords live in plain storage; there is no
// hashing or server. It exists to make the flow work end-to-end in development. Do
// not ship it as real authentication.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/util/ids.dart';
import 'auth_user.dart';
import 'customer_auth_api.dart';

// Storage keys, namespaced like the cart's key will be (Module 13).
const String _usersKey = 'microcare-mock-users';
const String _sessionKey = 'microcare-mock-session';

/// Fake network delay so loading spinners are visible in development. Overridable
/// (set to [Duration.zero] in tests).
const Duration kMockAuthLatency = Duration(milliseconds: 400);

/// A typed auth failure carrying a user-facing message (mirrors a backend 4xx).
class AuthError implements Exception {
  final String message;
  const AuthError(this.message);

  @override
  String toString() => 'AuthError: $message';
}

/// A stored user is the public [AuthUser] plus the password we check against. Only
/// this file ever sees the password; callers always get a password-free [AuthUser].
class _StoredUser {
  final AuthUser user;
  final String password;

  const _StoredUser(this.user, this.password);

  factory _StoredUser.fromJson(Map<String, dynamic> json) => _StoredUser(
        AuthUser.fromJson(json),
        json['password'] as String,
      );

  Map<String, dynamic> toJson() => {
        ...user.toJson(),
        'password': password,
      };
}

/// The local mock auth backend — the same call sites a real provider would expose.
class MockAuthApi implements CustomerAuthApi {
  MockAuthApi({this.latency = kMockAuthLatency});

  /// Simulated network latency; [Duration.zero] in tests.
  final Duration latency;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> _delay() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  // ── storage helpers ──────────────────────────────────────────────────────────

  Future<List<_StoredUser>> _readUsers() async {
    final raw = (await _prefs).getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _StoredUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeUsers(List<_StoredUser> users) async {
    final raw = jsonEncode(users.map((u) => u.toJson()).toList());
    await (await _prefs).setString(_usersKey, raw);
  }

  // ── the public "API" ─────────────────────────────────────────────────────────

  /// Create an account and make it the active session. Throws if the email exists.
  /// [role] defaults to [UserRole.customer]; self-signup never creates staff.
  @override
  Future<AuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
    UserRole role = UserRole.customer,
  }) async {
    await _delay();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsers();

    if (users.any((u) => u.user.email?.toLowerCase() == normalizedEmail)) {
      throw const AuthError('An account with this email already exists.');
    }

    final user = _buildUser(
      email: normalizedEmail,
      fullName: fullName,
      role: role,
    );

    await _writeUsers([...users, _StoredUser(user, password)]);
    await (await _prefs).setString(_sessionKey, user.id);
    return user;
  }

  /// Sign in with email + password. Throws a single generic error on any mismatch.
  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await _delay();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsers();
    final match = users
        .where((u) => u.user.email?.toLowerCase() == normalizedEmail)
        .toList();

    // Never reveal WHICH half was wrong (unknown email vs. bad password).
    if (match.isEmpty || match.first.password != password) {
      throw const AuthError('Invalid email or password.');
    }

    await (await _prefs).setString(_sessionKey, match.first.user.id);
    return match.first.user;
  }

  /// Begin a password reset. The mock has no email to send to, so this simply
  /// resolves — standing in for "a recovery link has been sent" without changing
  /// the session (the real flow completes outside the app). Never reveals whether
  /// the email has an account.
  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _delay();
    // No-op in the mock: there is nowhere to send a recovery email. The Supabase
    // backend performs the real send.
  }

  /// End the current session (users are kept).
  @override
  Future<void> signOut() async {
    await (await _prefs).remove(_sessionKey);
  }

  /// The signed-in user restored from a saved session, or null if none.
  @override
  Future<AuthUser?> getCurrentUser() async {
    final id = (await _prefs).getString(_sessionKey);
    if (id == null) return null;
    final users = await _readUsers();
    for (final u in users) {
      if (u.user.id == id) return u.user;
    }
    return null;
  }

  // ── tiny helpers ──────────────────────────────────────────────────────────────

  /// Build an [AuthUser] from a name + email + role (shared by signUp and the
  /// seed path), deriving the name parts and a placeholder avatar.
  AuthUser _buildUser({
    required String email,
    required String fullName,
    required UserRole role,
  }) {
    final parts = _nameParts(fullName);
    final displayName = parts.fullName ?? email;
    return AuthUser(
      id: _newId(),
      email: email,
      firstName: parts.firstName,
      lastName: parts.lastName,
      fullName: parts.fullName,
      imageUrl: _avatarUrl(displayName),
      role: role,
    );
  }

  // Web-safe unique id (a raw `Random().nextInt(1 << 32)` throws on the web; see
  // core/util/ids.dart).
  String _newId() => uniqueId(prefix: 'user');

  // Split "Jane Doe" → first/last (+ a display fullName), tolerating extra spaces.
  ({String? firstName, String? lastName, String? fullName}) _nameParts(
      String fullName) {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return (
      firstName: parts.isNotEmpty ? parts.first : null,
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : null,
      fullName: parts.isEmpty ? null : parts.join(' '),
    );
  }

  // A generated placeholder avatar so AuthUser.imageUrl is always a real URL.
  String _avatarUrl(String name) {
    final encoded = Uri.encodeComponent(name.trim().isEmpty ? 'User' : name.trim());
    return 'https://ui-avatars.com/api/?name=$encoded&background=random';
  }
}

/// The single [MockAuthApi] the auth layer reads. Overridable in tests.
final mockAuthApiProvider = Provider<MockAuthApi>((ref) => MockAuthApi());

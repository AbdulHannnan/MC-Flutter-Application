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
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_user.dart';

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
class MockAuthApi {
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
  Future<AuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _delay();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsers();

    if (users.any((u) => u.user.email?.toLowerCase() == normalizedEmail)) {
      throw const AuthError('An account with this email already exists.');
    }

    final parts = _nameParts(fullName);
    final displayName = parts.fullName ?? normalizedEmail;
    final user = AuthUser(
      id: _newId(),
      email: normalizedEmail,
      firstName: parts.firstName,
      lastName: parts.lastName,
      fullName: parts.fullName,
      imageUrl: _avatarUrl(displayName),
    );

    await _writeUsers([...users, _StoredUser(user, password)]);
    await (await _prefs).setString(_sessionKey, user.id);
    return user;
  }

  /// Sign in with email + password. Throws a single generic error on any mismatch.
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

  /// Set a new password for an existing email and sign that user in.
  Future<AuthUser> resetPassword({
    required String email,
    required String password,
  }) async {
    await _delay();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsers();
    final index =
        users.indexWhere((u) => u.user.email?.toLowerCase() == normalizedEmail);

    if (index == -1) {
      throw const AuthError('No account found for that email.');
    }

    final updated = _StoredUser(users[index].user, password);
    final next = [...users]..[index] = updated;
    await _writeUsers(next);
    await (await _prefs).setString(_sessionKey, updated.user.id);
    return updated.user;
  }

  /// End the current session (users are kept).
  Future<void> signOut() async {
    await (await _prefs).remove(_sessionKey);
  }

  /// The signed-in user restored from a saved session, or null if none.
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

  String _newId() {
    final rand = Random().nextInt(1 << 32).toRadixString(36);
    return 'user_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

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

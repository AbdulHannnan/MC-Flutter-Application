// test/support/fake_customer_auth.dart — an in-memory [CustomerAuthApi] for tests.
//
// This was the app's production mock auth backend before the Supabase cutover; it
// now lives here so the shipping app ships only Supabase Auth while tests keep a
// controllable, offline auth backend. Users + the current session persist in
// shared_preferences (set `SharedPreferences.setMockInitialValues({})` per test),
// so a seed via one instance and the provider override share state — exactly the
// old pattern. NOT secure; test-only.
//
// Use via: `customerAuthApiProvider.overrideWithValue(FakeCustomerAuthApi(latency:
// Duration.zero))`.

import 'dart:convert';

import 'package:microcare/src/features/auth/auth_user.dart';
import 'package:microcare/src/features/auth/customer_auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _usersKey = 'microcare-mock-users';
const String _sessionKey = 'microcare-mock-session';

class _StoredUser {
  final AuthUser user;
  final String password;
  const _StoredUser(this.user, this.password);

  factory _StoredUser.fromJson(Map<String, dynamic> json) =>
      _StoredUser(AuthUser.fromJson(json), json['password'] as String);

  Map<String, dynamic> toJson() => {...user.toJson(), 'password': password};
}

class FakeCustomerAuthApi implements CustomerAuthApi {
  FakeCustomerAuthApi({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  Future<void> _delay() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<List<_StoredUser>> _readUsers() async {
    final raw = (await _prefs).getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _StoredUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeUsers(List<_StoredUser> users) async {
    await (await _prefs)
        .setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
  }

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
        email: normalizedEmail, fullName: fullName, role: role);
    await _writeUsers([...users, _StoredUser(user, password)]);
    await (await _prefs).setString(_sessionKey, user.id);
    return user;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await _delay();
    final normalizedEmail = email.trim().toLowerCase();
    final match = (await _readUsers())
        .where((u) => u.user.email?.toLowerCase() == normalizedEmail)
        .toList();
    if (match.isEmpty || match.first.password != password) {
      throw const AuthError('Invalid email or password.');
    }
    await (await _prefs).setString(_sessionKey, match.first.user.id);
    return match.first.user;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _delay(); // no-op: nowhere to send mail in tests
  }

  @override
  Future<void> signOut() async {
    await (await _prefs).remove(_sessionKey);
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final id = (await _prefs).getString(_sessionKey);
    if (id == null) return null;
    for (final u in await _readUsers()) {
      if (u.user.id == id) return u.user;
    }
    return null;
  }

  AuthUser _buildUser({
    required String email,
    required String fullName,
    required UserRole role,
  }) {
    final parts = splitFullName(fullName);
    final displayName = parts.fullName ?? email;
    return AuthUser(
      id: 'user_${DateTime.now().microsecondsSinceEpoch}',
      email: email,
      firstName: parts.firstName,
      lastName: parts.lastName,
      fullName: parts.fullName,
      imageUrl: avatarUrlFor(displayName),
      role: role,
    );
  }
}

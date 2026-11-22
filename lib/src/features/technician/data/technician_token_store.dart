// lib/src/features/technician/data/technician_token_store.dart — secure storage
// for the technician's JWT + cached profile.
//
// The JWT is a bearer credential, so it lives in OS-backed secure storage (iOS
// Keychain / Android Keystore) via flutter_secure_storage — never a plain file,
// never shared_preferences, never logged. The technician's public profile is
// cached alongside it so a cold start can restore the session without a network
// round-trip (the token is re-validated on the first real request).
//
// It's behind an interface + provider so tests inject an in-memory fake instead
// of touching the platform keystore.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'technician.dart';

/// What the session layer needs from secure storage: read/write/clear the token
/// and the cached profile, as one unit.
abstract class TechnicianTokenStore {
  Future<String?> readToken();
  Future<Technician?> readTechnician();

  /// Persist a freshly-issued token + its profile (after a successful login).
  Future<void> save({required String token, required Technician technician});

  /// Wipe both (on logout or an invalidated token).
  Future<void> clear();
}

/// Default implementation on flutter_secure_storage.
class SecureTechnicianTokenStore implements TechnicianTokenStore {
  SecureTechnicianTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'microcare.technician.token';
  static const _profileKey = 'microcare.technician.profile';

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<Technician?> readTechnician() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Technician.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt blob → treat as no cached profile
    }
  }

  @override
  Future<void> save({
    required String token,
    required Technician technician,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
        key: _profileKey, value: jsonEncode(technician.toJson()));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _profileKey);
  }
}

/// The single token store the technician auth layer reads. Overridden in tests
/// with an in-memory fake so no real keystore is touched.
final technicianTokenStoreProvider = Provider<TechnicianTokenStore>(
  (ref) => SecureTechnicianTokenStore(),
);

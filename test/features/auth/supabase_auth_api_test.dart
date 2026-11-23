// Tests the pure pieces of the Supabase customer-auth adapter without a live
// project: the Supabase User → domain AuthUser mapping (metadata → names, derived
// display name, generated avatar, customer role) and the AuthException → AuthError
// message normalisation. The thin signIn/signUp/signOut/reset wiring is proven
// on-device (it just forwards to supabase.auth).

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/auth/auth_user.dart';
import 'package:microcare/src/features/auth/customer_auth_api.dart' show AuthError;
import 'package:microcare/src/features/auth/supabase_auth_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

User _user({Map<String, dynamic>? metadata, String? email}) => User.fromJson({
      'id': 'uid_1',
      'app_metadata': <String, dynamic>{},
      'user_metadata': metadata ?? <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2024-01-01T00:00:00Z',
      'email': email,
    })!;

void main() {
  group('mapSupabaseUser', () {
    test('maps metadata names, email, and a customer role', () {
      final u = mapSupabaseUser(_user(
        metadata: {'firstName': 'Jane', 'lastName': 'Doe'},
        email: 'jane@example.com',
      ));
      expect(u.id, 'uid_1');
      expect(u.email, 'jane@example.com');
      expect(u.firstName, 'Jane');
      expect(u.lastName, 'Doe');
      expect(u.fullName, 'Jane Doe');
      expect(u.role, UserRole.customer); // never technician on this path
      expect(u.imageUrl, startsWith('https://ui-avatars.com/'));
    });

    test('tolerates missing names (null fields, avatar from email)', () {
      final u = mapSupabaseUser(_user(email: 'nobody@example.com'));
      expect(u.firstName, isNull);
      expect(u.lastName, isNull);
      expect(u.fullName, isNull);
      // displayName falls back to the email, so the avatar encodes it.
      expect(u.imageUrl, contains('nobody%40example.com'));
    });

    test('first name only still yields a fullName of just that name', () {
      final u = mapSupabaseUser(_user(metadata: {'firstName': 'Cher'}));
      expect(u.firstName, 'Cher');
      expect(u.lastName, isNull);
      expect(u.fullName, 'Cher');
    });
  });

  group('authErrorFrom', () {
    test('softens invalid credentials', () {
      final e = authErrorFrom(const AuthException('Invalid login credentials'));
      expect(e, isA<AuthError>());
      expect(e.message, 'Invalid email or password.');
    });

    test('softens an already-registered email', () {
      final e = authErrorFrom(const AuthException('User already registered'));
      expect(e.message, 'An account with this email already exists.');
    });

    test('passes other messages through', () {
      final e = authErrorFrom(const AuthException('Email rate limit exceeded'));
      expect(e.message, 'Email rate limit exceeded');
    });
  });
}

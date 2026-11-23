// Pure validation rules — ported from the RN validation tests. No widgets, no
// storage: given field values, assert which fields error.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/auth/auth_validation.dart';

void main() {
  group('validateSignUp', () {
    test('accepts a well-formed form', () {
      final e = validateSignUp(
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        password: 'supersecret',
        confirmPassword: 'supersecret',
      );
      expect(e.hasErrors, isFalse);
    });

    test('flags a missing name, bad email, short password, mismatch', () {
      final e = validateSignUp(
        fullName: '   ',
        email: 'not-an-email',
        password: 'short',
        confirmPassword: 'different',
      );
      expect(e.fullName, isNotNull);
      expect(e.email, 'Enter a valid email address.');
      expect(e.password, contains('$kMinPasswordLength'));
      expect(e.confirmPassword, 'Passwords do not match.');
    });

    test('requires the password to be confirmed', () {
      final e = validateSignUp(
        fullName: 'Jane',
        email: 'jane@example.com',
        password: 'supersecret',
        confirmPassword: '',
      );
      expect(e.confirmPassword, isNotNull);
    });
  });

  group('validateLogin', () {
    test('accepts a plausible email + any non-empty password', () {
      final e = validateLogin(email: 'jane@example.com', password: 'x');
      expect(e.hasErrors, isFalse); // no min-length on login
    });

    test('flags empty email and password', () {
      final e = validateLogin(email: '', password: '');
      expect(e.email, 'Please enter your email.');
      expect(e.password, 'Please enter your password.');
    });

    test('flags a malformed email', () {
      final e = validateLogin(email: 'jane@', password: 'x');
      expect(e.email, 'Enter a valid email address.');
    });
  });

  group('validateResetRequest', () {
    test('accepts a plausible email (email-only reset)', () {
      final e = validateResetRequest(email: 'jane@example.com');
      expect(e.hasErrors, isFalse);
    });

    test('requires the email and rejects a malformed one', () {
      expect(validateResetRequest(email: '').email, 'Please enter your email.');
      expect(validateResetRequest(email: 'jane@').email,
          'Enter a valid email address.');
    });
  });
}

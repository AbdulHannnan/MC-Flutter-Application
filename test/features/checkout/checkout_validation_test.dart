// Checkout form validation (Module 14): Phone (required) + Email (validated).

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/checkout/checkout_validation.dart';

void main() {
  test('accepts a valid phone + email', () {
    final e = validateCheckout(phone: '+971 50 123 4567', email: 'a@b.com');
    expect(e.hasErrors, isFalse);
  });

  test('requires a phone', () {
    final e = validateCheckout(phone: '  ', email: 'a@b.com');
    expect(e.phone, isNotNull);
    expect(e.email, isNull);
  });

  test('rejects a too-short / non-numeric phone', () {
    expect(validateCheckout(phone: '123', email: 'a@b.com').phone, isNotNull);
    expect(validateCheckout(phone: 'not a phone', email: 'a@b.com').phone,
        isNotNull);
  });

  test('requires and validates the email', () {
    expect(validateCheckout(phone: '0501234567', email: '').email, isNotNull);
    expect(validateCheckout(phone: '0501234567', email: 'nope').email, isNotNull);
    expect(validateCheckout(phone: '0501234567', email: 'a@b.com').email, isNull);
  });
}

// lib/src/features/checkout/checkout_validation.dart — pure checkout-form
// validation, in the same spirit as auth_validation.dart.
//
// The checkout collects a Phone (required) and an Email (prefilled from the
// session, validated). Pure functions → trivially unit-testable; the screen feeds
// each message into the matching field's `errorText`.

/// Reuse the auth email shape (obvious-typo check; the backend is authoritative).
final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Digits, spaces and a few separators, at least 7 digits — a light sanity check,
/// not full E.164 validation.
final RegExp _phoneAllowed = RegExp(r'^[0-9+()\-\s]+$');

/// Field → error for the checkout form. A null field is valid.
class CheckoutErrors {
  final String? phone;
  final String? email;

  const CheckoutErrors({this.phone, this.email});

  bool get hasErrors => phone != null || email != null;
}

CheckoutErrors validateCheckout({
  required String phone,
  required String email,
}) {
  String? phoneError;
  final trimmedPhone = phone.trim();
  final digits = trimmedPhone.replaceAll(RegExp(r'[^0-9]'), '');
  if (trimmedPhone.isEmpty) {
    phoneError = 'Please enter a phone number.';
  } else if (!_phoneAllowed.hasMatch(trimmedPhone) || digits.length < 7) {
    phoneError = 'Enter a valid phone number.';
  }

  String? emailError;
  final trimmedEmail = email.trim();
  if (trimmedEmail.isEmpty) {
    emailError = 'Please enter your email.';
  } else if (!_emailRe.hasMatch(trimmedEmail)) {
    emailError = 'Enter a valid email address.';
  }

  return CheckoutErrors(phone: phoneError, email: emailError);
}

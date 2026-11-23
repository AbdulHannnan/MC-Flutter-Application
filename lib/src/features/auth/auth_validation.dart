// lib/src/features/auth/auth_validation.dart — pure form validation. Dart port of
// the RN app's `src/features/auth/validation.ts`.
//
// Pure functions: given the field values, return a typed errors object where a
// null field means "that field is fine". No side effects — so the rules are
// obvious to read and trivial to unit-test. The screen calls this on submit and
// feeds each message straight into the matching field's `errorText`.
//
// This is CLIENT-side validation only — a fast first check for good UX. The auth
// backend (a local mock today) enforces its own rules — e.g. email uniqueness —
// which come back as errors and are shown separately (a top-of-form banner).

/// A deliberately simple email shape check. We don't try to fully validate email
/// (near-impossible with a regex, and the backend verifies it anyway) — we just
/// catch obvious typos before hitting the "network".
final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Minimum password length we ask for up front.
const int kMinPasswordLength = 8;

bool _isValidEmail(String value) => _emailRe.hasMatch(value.trim());

// ── Sign up ────────────────────────────────────────────────────────────────

/// Field → error for the sign-up form. A null field is valid.
class SignUpErrors {
  final String? fullName;
  final String? email;
  final String? password;
  final String? confirmPassword;

  const SignUpErrors({
    this.fullName,
    this.email,
    this.password,
    this.confirmPassword,
  });

  bool get hasErrors =>
      fullName != null ||
      email != null ||
      password != null ||
      confirmPassword != null;
}

SignUpErrors validateSignUp({
  required String fullName,
  required String email,
  required String password,
  required String confirmPassword,
}) {
  String? nameError;
  if (fullName.trim().isEmpty) nameError = 'Please enter your name.';

  String? emailError;
  final trimmedEmail = email.trim();
  if (trimmedEmail.isEmpty) {
    emailError = 'Please enter your email.';
  } else if (!_isValidEmail(trimmedEmail)) {
    emailError = 'Enter a valid email address.';
  }

  String? passwordError;
  if (password.isEmpty) {
    passwordError = 'Please choose a password.';
  } else if (password.length < kMinPasswordLength) {
    passwordError = 'Password must be at least $kMinPasswordLength characters.';
  }

  String? confirmError;
  if (confirmPassword.isEmpty) {
    confirmError = 'Please re-enter your password.';
  } else if (password != confirmPassword) {
    confirmError = 'Passwords do not match.';
  }

  return SignUpErrors(
    fullName: nameError,
    email: emailError,
    password: passwordError,
    confirmPassword: confirmError,
  );
}

// ── Login ────────────────────────────────────────────────────────────────────

/// Field → error for the login form. A null field is valid.
class LoginErrors {
  final String? email;
  final String? password;

  const LoginErrors({this.email, this.password});

  bool get hasErrors => email != null || password != null;
}

/// Login is a lighter check than signup: only confirm the fields are present and
/// the email looks plausible. We deliberately DON'T enforce a min length here — an
/// existing account's password just needs to match, and "is this correct?" is the
/// backend's job. Wrong credentials come back as an error banner.
LoginErrors validateLogin({
  required String email,
  required String password,
}) {
  String? emailError;
  final trimmedEmail = email.trim();
  if (trimmedEmail.isEmpty) {
    emailError = 'Please enter your email.';
  } else if (!_isValidEmail(trimmedEmail)) {
    emailError = 'Enter a valid email address.';
  }

  String? passwordError;
  if (password.isEmpty) passwordError = 'Please enter your password.';

  return LoginErrors(email: emailError, password: passwordError);
}

// ── Password reset ─────────────────────────────────────────────────────────────

/// Field → error for the reset-request form. A null field is valid.
class ResetRequestErrors {
  final String? email;

  const ResetRequestErrors({this.email});

  bool get hasErrors => email != null;
}

/// The password reset is EMAIL-ONLY: the user enters the account email and the
/// backend sends a recovery link they complete outside the app (Supabase Auth
/// cannot set a new password inline from the client). So we only check the email
/// is present and plausible — no new-password fields here.
ResetRequestErrors validateResetRequest({required String email}) {
  String? emailError;
  final trimmedEmail = email.trim();
  if (trimmedEmail.isEmpty) {
    emailError = 'Please enter your email.';
  } else if (!_isValidEmail(trimmedEmail)) {
    emailError = 'Enter a valid email address.';
  }
  return ResetRequestErrors(email: emailError);
}

// lib/src/features/auth/auth_user.dart — the SESSION MODEL. Dart port of the RN
// app's `src/features/auth/types.ts`.
//
// Our own, provider-agnostic vocabulary for "who is signed in." The auth backend
// (a local mock today; see mock_auth_api.dart) may have a richer user shape, but
// we do NOT let that leak across the app — the whole codebase speaks [AuthUser],
// and the auth layer maps the backend's user → this. Swap the backend later and
// only that mapping changes; screens keep working.

/// Which app experience an account gets. A [customer] books services (the main
/// app); a [technician] sees the staff/job area instead. Role is a property of the
/// ACCOUNT — set when the account is created, never chosen at login — so the app
/// branches on `user.role` after authentication rather than asking at sign-in.
enum UserRole {
  customer,
  technician;

  /// The stored/wire token for this role, e.g. `'technician'`.
  String get code => name;

  /// Parse a role token, defaulting to [customer] for anything unrecognised (an
  /// old record with no role, or a bad value, is a customer — never silently a
  /// technician).
  static UserRole fromCode(String? value) =>
      value == technician.name ? UserRole.technician : UserRole.customer;
}

/// The normalized shape of the logged-in user the app uses everywhere — only the
/// fields the UI actually needs. Anything richer is fetched from OUR backend as a
/// profile later (server data), not piled in here.
class AuthUser {
  /// Stable unique id from the auth provider. Our backend keys the user by this.
  final String id;

  /// Primary email, if the provider exposes one.
  final String? email;
  final String? firstName;
  final String? lastName;

  /// Provider-computed display name; may be null if the user set no name.
  final String? fullName;

  /// Avatar URL — the mock generates one; a real provider would supply it.
  final String imageUrl;

  /// Which experience this account gets. Defaults to [UserRole.customer] so every
  /// existing/self-signup account is a customer unless explicitly made staff.
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.imageUrl,
    this.role = UserRole.customer,
  });

  /// True when this account is a technician (staff), i.e. gets the job area.
  bool get isTechnician => role == UserRole.technician;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        fullName: json['fullName'] as String?,
        imageUrl: json['imageUrl'] as String,
        role: UserRole.fromCode(json['role'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'imageUrl': imageUrl,
        'role': role.code,
      };

  /// A short label for greetings — the first name, else the full name, else the
  /// email, else a neutral fallback.
  String get displayName =>
      firstName ?? fullName ?? email ?? 'there';

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.fullName == fullName &&
      other.imageUrl == imageUrl &&
      other.role == role;

  @override
  int get hashCode =>
      Object.hash(id, email, firstName, lastName, fullName, imageUrl, role);
}

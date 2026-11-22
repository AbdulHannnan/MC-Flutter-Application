// lib/src/features/technician/data/technician.dart — the authenticated TECHNICIAN
// (staff) profile returned by the backend.
//
// Separate from the customer `AuthUser` (Clerk/mock): technicians are a distinct
// user type with their own backend JWT auth. This is the public, password-free
// shape the backend sends as `technician` on login and `/me`:
//   { id, code, name, username, phone }

class Technician {
  /// Backend id (cuid) — what jobs are scoped to on the server.
  final String id;

  /// Human-readable code, e.g. "MC0001TEC".
  final String code;
  final String name;

  /// Login identifier.
  final String username;

  /// Optional contact number.
  final String? phone;

  const Technician({
    required this.id,
    required this.code,
    required this.name,
    required this.username,
    required this.phone,
  });

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
        id: json['id'] as String,
        code: (json['code'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        username: (json['username'] ?? '') as String,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'username': username,
        'phone': phone,
      };

  /// A short label for greetings — the first word of the name, else the username.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return username;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  bool operator ==(Object other) =>
      other is Technician &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.username == username &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, code, name, username, phone);
}

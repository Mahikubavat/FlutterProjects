enum UserRole { user, admin }

class AppUser {
  final String id;
  final String email;
  final UserRole role;
  final String displayName;
  final String? photoBase64;

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName = '',
    this.photoBase64,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'role': role.name,
    'display_name': displayName,
    'photo_base64': photoBase64,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    email: map['email'] as String,
    role: UserRole.values.byName(map['role'] as String),
    displayName: (map['display_name'] as String?) ?? '',
    photoBase64: map['photo_base64'] as String?,
  );
}

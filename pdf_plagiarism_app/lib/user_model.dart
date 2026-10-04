class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // "Instructor" or "TA"
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  // Convert User object to Map to save in Firestore Database
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create User object from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'TA',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
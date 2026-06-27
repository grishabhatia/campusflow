class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // "student", "admin", "security"
  final String organization;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.organization = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'organization': organization,
    };
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      organization: map['organization'] ?? '',
    );
  }
}

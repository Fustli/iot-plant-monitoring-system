import 'auth_models.dart';

/// User model matching backend User entity
/// Includes role field for RBAC
class User {
  final int id;
  final String email;
  final String username;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      username: json['username'] as String,
      role: UserRole.fromString(json['role'] as String?),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  /// Get role display name in Hungarian
  String get roleDisplayHu => role.displayNameHu;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'role': role.name,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'is_active': isActive,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
        'last_login': lastLogin?.toIso8601String(),
      };

  User copyWith({
    int? id,
    String? email,
    String? username,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  String toString() => 'User($username, role: ${role.name})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

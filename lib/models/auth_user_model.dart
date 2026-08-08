import 'package:supabase_flutter/supabase_flutter.dart'
    show User; // ignore: depend_on_referenced_packages

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? birthDate;
  final String? department;
  final bool isAdmin;
  final bool isBaskan;
  final String role;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.birthDate,
    this.department,
    this.isAdmin = false,
    this.isBaskan = false,
    this.role = 'student',
    required this.createdAt,
  });

  factory AuthUser.fromProfileJson(
    User supabaseUser,
    Map<String, dynamic> profile,
  ) {
    final role = profile['role'] as String? ?? 'student';
    return AuthUser(
      id: supabaseUser.id,
      name:
          profile['name'] as String? ??
          supabaseUser.email?.split('@').first ??
          '',
      email: supabaseUser.email ?? '',
      birthDate: profile['birth_date'] as String? ?? '01.01.2002',
      department:
          profile['department'] as String? ?? 'Bilişim Sistemleri Mühendisliği',
      isAdmin: role == 'admin',
      isBaskan: role == 'baskan',
      role: role,
      createdAt: DateTime.parse(supabaseUser.createdAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'birthDate': birthDate,
        'department': department,
        'isAdmin': isAdmin,
        'isBaskan': isBaskan,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        birthDate: json['birthDate'] as String?,
        department: json['department'] as String?,
        isAdmin: json['isAdmin'] as bool? ?? false,
        isBaskan: json['isBaskan'] as bool? ?? false,
        role: json['role'] as String? ?? 'student',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

import 'package:supabase_flutter/supabase_flutter.dart'
    show User; // ignore: depend_on_referenced_packages

/// `profiles.department` bir TEXT[] kolonu; PostgREST onu List olarak döndürür.
/// Uygulama içinde virgülle ayrılmış String olarak taşınır.
String? departmentText(Object? raw) {
  if (raw == null) return null;
  if (raw is List) {
    final joined = raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .join(', ');
    return joined.isEmpty ? null : joined;
  }
  return raw.toString();
}

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? birthDate;
  final String? department; // Comma-separated list of departments
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

  /// Returns department as a list (splits comma-separated string)
  List<String> get departments {
    if (department == null || department!.isEmpty) return [];
    return department!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Returns the first department for display purposes
  String? get primaryDepartment {
    final depts = departments;
    return depts.isNotEmpty ? depts.first : null;
  }

  factory AuthUser.fromProfileJson(
    User supabaseUser,
    Map<String, dynamic> profile,
  ) {
    final role = profile['role'] as String? ?? 'student';
    final rawDept = departmentText(profile['department']);
    return AuthUser(
      id: supabaseUser.id,
      name:
          profile['name'] as String? ??
          supabaseUser.email?.split('@').first ??
          '',
      email: supabaseUser.email ?? '',
      birthDate: supabaseUser.userMetadata?['birth_date'] as String?,
      department: rawDept,
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
        department: departmentText(json['department']),
        isAdmin: json['isAdmin'] as bool? ?? false,
        isBaskan: json['isBaskan'] as bool? ?? false,
        role: json['role'] as String? ?? 'student',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

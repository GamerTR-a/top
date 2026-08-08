import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_user_model.dart';

class AppAuthException implements Exception {
  final String message;
  const AppAuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static const _usersKey = 'registered_users';
  static const _currentUserKey = 'current_user_id';
  // Salt cihaz kimliğiyle veya güvenli depoda saklanmalı; geçici lokal auth için.
  static const _salt = 'newgenc_local_salt_v1';

  static String _hashPassword(String password) {
    final bytes = utf8.encode('$password$_salt');
    return sha256.convert(bytes).toString();
  }

  static Future<List<AuthUser>> _getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AuthUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveUsers(List<AuthUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
  }

  static Future<AuthUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_currentUserKey);
    if (id == null) return null;
    final users = await _getUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } on StateError {
      return null;
    }
  }

  static Future<AuthUser> loginAsUser(String email, String password) async {
    final users = await _getUsers();
    try {
      final user = users.firstWhere(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, user.id);
      return user;
    } on StateError {
      throw const AppAuthException('E-posta veya şifre hatalı.');
    }
  }

  static Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) throw const AppAuthException('İsim boş olamaz.');
    final emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) throw const AppAuthException('Geçerli bir e-posta girin.');
    if (password.length < 6) throw const AppAuthException('Şifre en az 6 karakter olmalı.');

    final users = await _getUsers();
    final exists = users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase());
    if (exists) throw const AppAuthException('Bu e-posta zaten kayıtlı.');

    final newUser = AuthUser(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim().toLowerCase(),
      isAdmin: false,
      createdAt: DateTime.now(),
    );

    users.add(newUser);
    await _saveUsers(users);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, newUser.id);

    return newUser;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  static Future<void> changePassword(String email, String newPassword) async {
    if (newPassword.length < 6) throw const AppAuthException('Şifre en az 6 karakter olmalı.');
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _getUsers();
    final idx = users.indexWhere((u) => u.email == normalizedEmail);
    if (idx == -1) throw const AppAuthException('Bu e-posta ile kayıtlı kullanıcı bulunamadı.');
  }

  static Future<void> updateUserName(String userId, String newName) async {
    if (newName.trim().isEmpty) throw const AppAuthException('İsim boş olamaz.');
    final users = await _getUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final u = users[idx];
    users[idx] = AuthUser(
      id: u.id,
      name: newName.trim(),
      email: u.email,
      birthDate: u.birthDate,
      department: u.department,
      isAdmin: u.isAdmin,
      createdAt: u.createdAt,
    );
    await _saveUsers(users);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userId);
  }

  static Future<List<AuthUser>> getAllUsers() async {
    return _getUsers();
  }

  static Future<void> deleteUser(String userId) async {
    final users = await _getUsers();
    users.removeWhere((u) => u.id == userId);
    await _saveUsers(users);
  }

  static Future<void> saveQuickUser(AuthUser user) async {
    final users = await _getUsers();
    users.removeWhere((u) => u.id == user.id || u.email == user.email);
    users.add(user);
    await _saveUsers(users);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, user.id);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_user_model.dart';

/// Centralized Local Storage Service for Offline-First Mobile Persistence
/// Complies with Google Play Store Scoped Storage & Local Privacy Guidelines.
class LocalStorageService {
  static LocalStorageService? _instance;
  static SharedPreferences? _prefs;

  LocalStorageService._();

  static Future<LocalStorageService> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorageService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  /// Senkron erişim — `main()` içinde `getInstance()` çağrıldıktan sonra
  /// kullanılabilir. Önbellek okumalarını (ağ beklemeden) anında yapmak için.
  static LocalStorageService? get instance => _instance;

  // --- Keys ---
  static const String _keyPrivacyAccepted = 'privacy_policy_accepted_v1';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyCachedPosts = 'offline_cached_posts';
  static const String _keyCachedAuthUser = 'cached_auth_user';
  static const String _keyNotificationSettings = 'notification_settings';
  static const String _keyLastSyncTimestamp = 'last_sync_timestamp';

  // Liste önbelleği anahtarları — SupabaseDataService ile paylaşılır.
  static const String keyCachedKuponlar = 'offline_cached_kuponlar_v1';
  static const String keyCachedEtkinlikler = 'offline_cached_etkinlikler_v1';
  static const String keyCachedTopluluklar = 'offline_cached_topluluklar_v1';

  // --- Privacy Policy Acceptance ---
  bool get isPrivacyPolicyAccepted => _prefs?.getBool(_keyPrivacyAccepted) ?? false;

  Future<bool> setPrivacyPolicyAccepted(bool accepted) async {
    return await _prefs?.setBool(_keyPrivacyAccepted, accepted) ?? false;
  }

  // --- Theme & Notification Settings ---
  String? get themeMode => getString(_keyThemeMode);
  Future<bool> setThemeMode(String mode) async => setString(_keyThemeMode, mode);

  bool get notificationsEnabled => _prefs?.getBool(_keyNotificationSettings) ?? true;
  Future<bool> setNotificationsEnabled(bool enabled) async => _prefs?.setBool(_keyNotificationSettings,enabled) ?? false;

  // --- General String/JSON Storage ---
  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<bool> setJsonObject(String key, Map<String, dynamic> jsonMap) async {
    try {
      final jsonStr = jsonEncode(jsonMap);
      return await setString(key, jsonStr);
    } catch (e) {
      debugPrint('LocalStorageService error encoding JSON: $e');
      return false;
    }
  }

  Map<String, dynamic>? getJsonObject(String key) {
    final jsonStr = getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('LocalStorageService error decoding JSON: $e');
      return null;
    }
  }

  // --- Offline Caching Helpers ---

  /// Rastgele satır listesini JSON olarak önbelleğe yazar.
  Future<bool> cacheJsonList(String key, List<Map<String, dynamic>> rows) async {
    try {
      final jsonStr = jsonEncode(rows);
      await setString(key, jsonStr);
      await setString(_keyLastSyncTimestamp, DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      debugPrint('LocalStorageService error caching list ($key): $e');
      return false;
    }
  }

  /// Önbelleğe yazılmış satır listesini okur (yoksa boş liste).
  List<Map<String, dynamic>> getCachedJsonList(String key) {
    final jsonStr = getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('LocalStorageService error reading cached list ($key): $e');
      return [];
    }
  }

  Future<bool> cachePostsList(List<Map<String, dynamic>> posts) async {
    final ok = await cacheJsonList(_keyCachedPosts, posts);
    return ok;
  }

  List<Map<String, dynamic>> getCachedPostsList() {
    return getCachedJsonList(_keyCachedPosts);
  }

  // Kullanıcı bazlı profil önbelleği — çoklu kullanıcı çakışmasını önler.
  String _profileKey(String userId) => 'offline_cached_profile_$userId';

  Future<bool> cacheUserProfile(
    String userId,
    Map<String, dynamic> userProfile,
  ) async {
    return await setJsonObject(_profileKey(userId), userProfile);
  }

  Map<String, dynamic>? getCachedUserProfile(String userId) {
    return getJsonObject(_profileKey(userId));
  }

  // ── Oturum (AuthUser) önbelleği — çevrimdışı açılış için ──────────────
  Future<bool> saveAuthUser(AuthUser user) async {
    return await setJsonObject(_keyCachedAuthUser, user.toJson());
  }

  AuthUser? getAuthUser() {
    final json = getJsonObject(_keyCachedAuthUser);
    if (json == null) return null;
    try {
      return AuthUser.fromJson(json);
    } catch (e) {
      debugPrint('LocalStorageService error reading AuthUser: $e');
      return null;
    }
  }

  Future<bool> clearAuthUser() async {
    return await removeKey(_keyCachedAuthUser);
  }

  String? getLastSyncTimestamp() {
    return getString(_keyLastSyncTimestamp);
  }

  // --- Clear / Reset ---
  Future<bool> removeKey(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  Future<bool> clearAllCache() async {
    return await _prefs?.clear() ?? false;
  }
}

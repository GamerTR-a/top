import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_user_model.dart';
import '../models/memory_gallery_model.dart';

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
      await _instance!._runMigrationsIfNeeded();
    }
    return _instance!;
  }

  // ── Şema sürümü / migration ──────────────────────────────────────────────
  // Anahtar adlarındaki "_v1" son eki daha önce yalnızca isimlendirme kuralıydı
  // — biçim değiştiğinde eski veriyi yeni biçime çeviren gerçek bir kod yoktu,
  // bu yüzden `getCachedJsonList` gibi okuyucular sessizce boş listeye
  // düşerdi (bkz. kontrol.md Bölüm 24.1 / 30.7). Bu alan gelecekteki gerçek
  // bir şema değişikliğinde YAPILACAK dönüştürmeler için ayrılmış yer
  // tutucudur — şu an her anahtar zaten ilk (v1) biçiminde olduğundan
  // çalıştırılacak bir dönüştürme adımı yok, yalnızca sürüm damgalanıyor.
  static const String _keySchemaVersion = 'local_storage_schema_version';
  static const int _currentSchemaVersion = 1;

  Future<void> _runMigrationsIfNeeded() async {
    final stored = _prefs?.getInt(_keySchemaVersion) ?? 0;
    if (stored >= _currentSchemaVersion) return;
    // Gelecekte bir anahtar biçimi değiştiğinde buraya
    // `if (stored < N) { ...eski veriyi oku, dönüştür, yeni anahtara yaz... }`
    // adımları eklenmeli — böylece kullanıcı verisi sessizce kaybolmaz.
    await _prefs?.setInt(_keySchemaVersion, _currentSchemaVersion);
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
  static const String _keyCrashReportingEnabled = 'crash_reporting_enabled';
  static const String _keyLastSyncTimestamp = 'last_sync_timestamp';

  // Liste önbelleği anahtarları — SupabaseDataService ile paylaşılır.
  static const String keyCachedKuponlar = 'offline_cached_kuponlar_v1';
  static const String keyCachedEtkinlikler = 'offline_cached_etkinlikler_v1';
  static const String keyCachedTopluluklar = 'offline_cached_topluluklar_v1';
  static const String keyCachedNews = 'offline_cached_news_v1';
  static const String keyCachedJobListings = 'offline_cached_job_listings_v1';
  static const String keyCachedMenuItems = 'offline_cached_menu_items_v1';

  // --- Hatıra Galerisi (Memory Gallery) ---
  static const String _keyMemoryAlbums = 'memory_albums_v1';

  // --- Privacy Policy Acceptance ---
  bool get isPrivacyPolicyAccepted => _prefs?.getBool(_keyPrivacyAccepted) ?? false;

  Future<bool> setPrivacyPolicyAccepted(bool accepted) async {
    return await _prefs?.setBool(_keyPrivacyAccepted, accepted) ?? false;
  }

  // --- Theme & Notification Settings ---
  String? get themeMode => getString(_keyThemeMode);
  Future<bool> setThemeMode(String mode) async => setString(_keyThemeMode, mode);

  bool get notificationsEnabled => _prefs?.getBool(_keyNotificationSettings) ?? true;
  Future<bool> setNotificationsEnabled(bool enabled) async => await _prefs?.setBool(_keyNotificationSettings, enabled) ?? false;

  /// Kullanıcının Crashlytics çökme raporu gönderimine izin verip vermediği.
  /// Varsayılan `true` (mevcut davranışla uyumlu) — kullanıcı Ayarlar'dan
  /// kapatabilir (bkz. kontrol.md Bölüm 12.6).
  bool get crashReportingEnabled => _prefs?.getBool(_keyCrashReportingEnabled) ?? true;
  Future<bool> setCrashReportingEnabled(bool enabled) async =>
      await _prefs?.setBool(_keyCrashReportingEnabled, enabled) ?? false;

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

  /// Logout'ta çağrılır — paylaşılan bir cihazda bir sonraki kullanıcının
  /// önceki kullanıcının önbelleğe alınmış SUNUCU içeriğini (gönderiler,
  /// kuponlar, etkinlikler, topluluklar, haberler, iş ilanları, profil)
  /// görmesini engeller.
  ///
  /// [clearAllCache] (`_prefs.clear()`) BİLEREK kullanılmıyor — o, tema
  /// tercihi, gizlilik politikası onayı ve Hatıra Galerisi (tamamen yerel,
  /// cihaza özel kişisel içerik) gibi kullanıcıdan/oturumdan BAĞIMSIZ
  /// cihaz ayarlarını da silerdi (bkz. kontrol.md Bölüm 2.8).
  Future<void> clearUserSessionCache({String? userId}) async {
    await removeKey(_keyCachedPosts);
    await removeKey(keyCachedKuponlar);
    await removeKey(keyCachedEtkinlikler);
    await removeKey(keyCachedTopluluklar);
    await removeKey(keyCachedNews);
    await removeKey(keyCachedJobListings);
    await removeKey(keyCachedMenuItems);
    await removeKey(_keyCachedAuthUser);
    await removeKey(_keyLastSyncTimestamp);
    if (userId != null && userId.isNotEmpty) {
      await removeKey(_profileKey(userId));
    }
  }

  // ── Hatıra Galerisi (Memory Gallery) ─────────────────────────────────────

  /// Tüm albümleri getir (en yeni üstte)
  Future<List<MemoryAlbum>> getMemoryAlbums() async {
    final jsonStr = getString(_keyMemoryAlbums);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      final albums = decoded
          .map((e) => MemoryAlbum.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return albums;
    } catch (e) {
      debugPrint('LocalStorageService error reading memory albums: $e');
      return [];
    }
  }

  /// Albümleri kaydet
  Future<bool> saveMemoryAlbums(List<MemoryAlbum> albums) async {
    try {
      final jsonStr = jsonEncode(albums.map((a) => a.toJson()).toList());
      return await setString(_keyMemoryAlbums, jsonStr);
    } catch (e) {
      debugPrint('LocalStorageService error saving memory albums: $e');
      return false;
    }
  }

  /// Yeni albüm oluştur
  Future<MemoryAlbum?> createAlbum(String name) async {
    if (name.trim().isEmpty) return null;
    final albums = await getMemoryAlbums();
    final newAlbum = MemoryAlbum(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      photoPaths: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    albums.insert(0, newAlbum);
    await saveMemoryAlbums(albums);
    return newAlbum;
  }

  /// Albüm sil
  Future<bool> deleteAlbum(String albumId) async {
    final albums = await getMemoryAlbums();
    albums.removeWhere((a) => a.id == albumId);
    return await saveMemoryAlbums(albums);
  }

  /// Albüm adını güncelle
  Future<bool> renameAlbum(String albumId, String newName) async {
    if (newName.trim().isEmpty) return false;
    final albums = await getMemoryAlbums();
    final index = albums.indexWhere((a) => a.id == albumId);
    if (index == -1) return false;
    albums[index] = albums[index].copyWith(name: newName.trim(), updatedAt: DateTime.now());
    return await saveMemoryAlbums(albums);
  }

  /// Albüme fotoğraf ekle
  Future<bool> addPhotoToAlbum(String albumId, String photoPath) async {
    final albums = await getMemoryAlbums();
    final index = albums.indexWhere((a) => a.id == albumId);
    if (index == -1) return false;
    albums[index] = albums[index].addPhoto(photoPath);
    return await saveMemoryAlbums(albums);
  }

  /// Albümden fotoğraf sil
  Future<bool> removePhotoFromAlbum(String albumId, String photoPath) async {
    final albums = await getMemoryAlbums();
    final index = albums.indexWhere((a) => a.id == albumId);
    if (index == -1) return false;
    albums[index] = albums[index].removePhoto(photoPath);
    return await saveMemoryAlbums(albums);
  }
}

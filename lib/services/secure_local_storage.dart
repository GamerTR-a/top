import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase oturum verisini (access/refresh token içeren session JSON'ı)
/// düz metin SharedPreferences yerine platformun şifreli anahtarlığında
/// (iOS Keychain / Android Keystore — EncryptedSharedPreferences) saklayan
/// [LocalStorage] implementasyonu.
///
/// Cihaz yedeklerinde (adb backup, otomatik telefon yedeği) veya cihaza
/// fiziksel erişimde oturum token'larının düz metin olarak ele geçirilmesini
/// engellemek için kullanılır. Bkz. güvenlik denetimi bulgusu: "Hassas veri
/// saklama — Supabase oturum token'ı şifrelenmemiş SharedPreferences'ta".
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage();

  static const String _sessionKey = 'sb_secure_session';

  // flutter_secure_storage 11.x Android'de varsayılan olarak AES-GCM +
  // KeyStore tabanlı RSA anahtar sarmalama kullanır (encryptedSharedPreferences
  // bayrağı artık gerekli değil, bu davranış varsayılan) — Android tarafında
  // ek ayara gerek yok.
  //
  // iOS'ta ise varsayılan erişilebilirlik seviyesi `KeychainAccessibility.
  // unlocked`'tır — bu, kSecAttrAccessibleWhenUnlocked'a karşılık gelir ve
  // kullanıcı iCloud Keychain yedeğini YENİ bir cihazda geri yüklerse oturum
  // token'ı o cihaza da taşınır. `first_unlock_this_device` kullanarak hem bu
  // taşınmayı engelliyoruz (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
  // hem de arka planda (FCM handler gibi) cihaz en az bir kez açıldıktan sonra
  // erişime izin veriyoruz.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final value = await _storage.read(key: _sessionKey);
    return value != null;
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}

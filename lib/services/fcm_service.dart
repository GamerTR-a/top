import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

/// Push bildirimleri için ana anahtar.
/// v1'de Firebase (google-services.json / GoogleService-Info.plist / APNs)
/// henüz yapılandırılmadığı için kapalıdır. Yapılandırma tamamlanınca `true`
/// yapılması yeterlidir.
const bool kPushEnabled = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('[FCM] Arka plan bildirimi: ${message.notification?.title}');
  } catch (_) {}
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  String? _token;

  /// Uygulamanın başlangıcında çağrılır.
  /// google-services.json yoksa veya Firebase yapılandırılmamışsa sessizce geçilir.
  Future<void> initialize() async {
    if (!kPushEnabled) {
      debugPrint('[FCM] Push devre dışı (kPushEnabled=false).');
      return;
    }
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _token = await messaging.getToken();
        messaging.onTokenRefresh.listen(_onTokenRefresh);
        // Token kaydı giriş sonrasına bırakılır (kullanıcı oturumu açık değilse crash olmaması için)
        await _registerTokenSafely();
      } else {
        debugPrint(
          '[FCM] Bildirim izni verilmedi: ${settings.authorizationStatus}',
        );
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      debugPrint('[FCM] Başlatıldı. Token: $_token');
    } catch (e) {
      // Firebase yapılandırılmamışsa uygulama çalışmaya devam eder, push bildirimler devre dışı kalır.
      // Push bildirimleri etkinleştirmek için: Firebase Console'dan google-services.json (Android)
      // veya GoogleService-Info.plist (iOS) dosyasını projeye ekleyin.
      debugPrint(
        '[FCM] Firebase yapılandırılmamış, push bildirimler devre dışı: $e',
      );
    }
  }

  /// Kullanıcı giriş yaptıktan sonra çağrılarak token'ı Supabase'e kaydeder.
  Future<void> registerTokenForCurrentUser() async {
    if (!kPushEnabled) return;
    await _registerTokenSafely();
  }

  Future<void> _registerTokenSafely() async {
    if (_token == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final platform = defaultTargetPlatform.name.toLowerCase();
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': _token!,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[FCM] Token Supabase\'e kaydedildi.');
    } catch (e) {
      debugPrint('[FCM] Token kaydı başarısız: $e');
    }
  }

  void _onTokenRefresh(String newToken) {
    _token = newToken;
    _registerTokenSafely();
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isNotEmpty) {
      notificationService.add(title: title, body: body);
    }
    debugPrint('[FCM] Ön plan bildirimi: $title');
  }

  void _onMessageOpened(RemoteMessage message) {
    debugPrint('[FCM] Bildirime tıklandı: ${message.notification?.title}');
  }
}

final fcmService = FcmService();

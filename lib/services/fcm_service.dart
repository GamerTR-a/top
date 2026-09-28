import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/notification_center_screen.dart';
import '../utils/navigation_service.dart';
import 'local_notification_service.dart';
import 'supabase_auth_service.dart';

/// Push bildirimleri için ana anahtar.
/// Firebase yapılandırma dosyaları (google-services.json / GoogleService-Info.plist)
/// eklendi ve Gradle/Xcode proje dosyalarına bağlandı. iOS tarafında APNs
/// anahtarı Firebase Console'a yüklenmeden gerçek cihazda iOS push çalışmaz
/// (Android bundan etkilenmez) — bkz. görev 1 kurulum notları.
const bool kPushEnabled = true;

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

      // iOS ön planda banner'ı sistem gösterir; Android'de _onForegroundMessage
      // yerel bildirimle gösterir (ikisi birden olursa bildirim iki kez düşer).
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_navigateForMessage);

      // Güvenlik: push token'ın tamamı loglanmaz (ele geçirilirse sahte push
      // gönderimine izin verebilir) — yalnızca alınıp alınmadığı loglanır.
      debugPrint('[FCM] Başlatıldı. Token alındı: ${_token != null}');
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    // Sunucudan gelen tüm push'lar aynı anda `notifications` tablosuna da
    // yazılır (bkz. sendUpdateAnnouncement / send-community-notification);
    // burada yalnızca sistem bildirimi olarak gösterilir.
    debugPrint('[FCM] Ön plan bildirimi: ${message.notification?.title}');
    final n = message.notification;
    if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
    localNotificationService.showNow(
      title: n.title ?? 'NevGenç',
      body: n.body ?? '',
    );
  }

  /// Uygulama tamamen kapalıyken bir bildirime tıklanarak açıldıysa (cold
  /// start), bu durumu yakalayıp aynı yönlendirmeyi tetikler. `AuthGate`
  /// içinde, Navigator hazır olduktan (ilk frame) sonra çağrılmalı — bkz.
  /// kontrol.md Bölüm 25.4 (önceden bu senaryo hiç ele alınmıyordu).
  Future<void> checkInitialMessage() async {
    if (!kPushEnabled) return;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) _navigateForMessage(message);
    } catch (e) {
      debugPrint('[FCM] getInitialMessage kontrolü başarısız: $e');
    }
  }

  /// Bildirime tıklanınca (uygulama arka planda veya soğuk başlatmada)
  /// Bildirimler ekranına yönlendirir — bildirim türüne göre ayrıca ilgili
  /// içerik ekranına gitmek istenirse `message.data` burada okunabilir.
  void _navigateForMessage(RemoteMessage message) async {
    debugPrint('[FCM] Bildirime tıklandı: ${message.notification?.title}');
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final user = await SupabaseAuthService.getCurrentUser().catchError(
      (_) => null,
    );
    if (user == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(currentUser: user),
      ),
    );
  }
}

final fcmService = FcmService();

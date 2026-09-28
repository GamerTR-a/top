import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'local_storage_service.dart';

/// Uygulama kapalıyken de tetiklenen, cihazda zamanlanmış (yerel) bildirimler.
/// FCM (bkz. fcm_service.dart) sunucudan anlık push gönderir; bu servis ise
/// belirli bir tarih/saatte çalması gereken hatırlatıcılar için kullanılır
/// (Takvim hatırlatıcıları — görev 10 — bu servisi kullanır).
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._();

  static const String _reminderChannelId = 'nevgenc_reminders';

  /// FCM push bildirimlerinin varsayılan Android kanalı — AndroidManifest.xml'
  /// deki `com.google.firebase.messaging.default_notification_channel_id`
  /// meta-data'sıyla eşleşmeli. Tanımlanmazsa Firebase otomatik olarak
  /// jenerik "Miscellaneous" kanalını kullanır (bkz. kontrol.md Bölüm 25.5).
  static const String pushChannelId = 'nevgenc_general';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // NevGenç bir Türkiye üniversitesi uygulaması — tüm hatırlatıcılar
      // yerel (Europe/Istanbul) saat dilimine göre zamanlanır.
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      // iOS bildirim izni FCM tarafından zaten istendiği için (paylaşılan
      // UNUserNotificationCenter izni) burada tekrar istenmiyor.
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          'Hatırlatıcılar',
          description: 'Takvim notu ve görev hatırlatıcı bildirimleri',
          importance: Importance.high,
        ),
      );
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          pushChannelId,
          'Genel Bildirimler',
          description: 'Duyurular, topluluk gönderileri ve genel bildirimler',
          importance: Importance.high,
        ),
      );
      // FCM devre dışıysa (Firebase yapılandırılmamış) bildirim izni hiç
      // istenmemiş olabilir — burada da isteyelim ki hatırlatıcılar çalışsın.
      await androidImpl?.requestNotificationsPermission();

      _initialized = true;
      debugPrint('[LocalNotification] Başlatıldı.');
    } catch (e) {
      debugPrint('[LocalNotification] Başlatma hatası: $e');
    }
  }

  /// Belirli bir tarih/saatte tetiklenecek bildirim zamanlar.
  /// [id] aynı kayda ait güncelleme/iptal işlemlerinde kullanılmak üzere
  /// çağıran tarafından kararlı (stable) verilmelidir.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
  }) async {
    // Kullanıcı Ayarlar'dan bildirimleri kapattıysa hatırlatıcı da
    // zamanlanmaz (bkz. kontrol.md Bölüm 25.6 — bu tercih daha önce hiçbir
    // yerden okunmuyordu, ölü koddu).
    if (LocalStorageService.instance?.notificationsEnabled == false) {
      debugPrint('[LocalNotification] Bildirimler kapalı, zamanlama atlandı.');
      return;
    }
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final scheduled = tz.TZDateTime.from(dateTime, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      debugPrint('[LocalNotification] Geçmiş zaman için planlama atlandı: $dateTime');
      return;
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannelId,
            'Hatırlatıcılar',
            channelDescription: 'Takvim notu ve görev hatırlatıcı bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[LocalNotification] Zamanlandı (#$id): $scheduled');
    } catch (e) {
      debugPrint('[LocalNotification] Zamanlama hatası (#$id): $e');
    }
  }

  /// Uygulama ön plandayken gelen FCM push'unu hemen gösterir — Android,
  /// ön plandaki uygulamada `notification` mesajlarını kendisi göstermez.
  Future<void> showNow({
    required String title,
    required String body,
  }) async {
    if (LocalStorageService.instance?.notificationsEnabled == false) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            pushChannelId,
            'Genel Bildirimler',
            channelDescription:
                'Duyurular, topluluk gönderileri ve genel bildirimler',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[LocalNotification] Anlık gösterim hatası: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_initialized) await initialize();
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[LocalNotification] İptal hatası (#$id): $e');
    }
  }

  /// Serbest metin/ID'den kararlı bir 31-bit bildirim ID'si üretir
  /// (flutter_local_notifications int32 ID bekler).
  static int idFromString(String source) => source.hashCode & 0x7fffffff;
}

final localNotificationService = LocalNotificationService();

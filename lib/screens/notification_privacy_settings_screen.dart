import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/fcm_service.dart';
import '../services/local_storage_service.dart';

/// Bildirim ve çökme raporu tercihleri.
///
/// Daha önce Crashlytics kullanıcı onayı olmadan otomatik başlıyordu ve
/// "Bildirimleri Al" tercihi hiçbir ekrandan değiştirilemiyordu (altyapısı
/// vardı ama bağlı değildi) — bkz. kontrol.md Bölüm 12.6 / 25.6.
class NotificationPrivacySettingsScreen extends StatefulWidget {
  const NotificationPrivacySettingsScreen({super.key});

  @override
  State<NotificationPrivacySettingsScreen> createState() =>
      _NotificationPrivacySettingsScreenState();
}

class _NotificationPrivacySettingsScreenState
    extends State<NotificationPrivacySettingsScreen> {
  bool _notificationsEnabled = true;
  bool _crashReportingEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await LocalStorageService.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = store.notificationsEnabled;
      _crashReportingEnabled = store.crashReportingEnabled;
      _loading = false;
    });
  }

  Future<void> _onNotificationsChanged(bool value) async {
    setState(() => _notificationsEnabled = value);
    final store = await LocalStorageService.getInstance();
    await store.setNotificationsEnabled(value);
    if (value) {
      // Tercih yeniden açıldı — push token'ı yeniden kaydet.
      unawaited(fcmService.registerTokenForCurrentUser());
    } else {
      // Sunucudan gönderilen push'ları da durdurmak için bu cihazın
      // token kaydını sil (yalnızca istemci tarafı bayrak yeterli değil).
      await _unregisterPushToken();
    }
  }

  Future<void> _unregisterPushToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('[NotificationSettings] Push token silinemedi: $e');
    }
  }

  Future<void> _onCrashReportingChanged(bool value) async {
    setState(() => _crashReportingEnabled = value);
    final store = await LocalStorageService.getInstance();
    await store.setCrashReportingEnabled(value);
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        value && !kDebugMode,
      );
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        value && !kDebugMode,
      );
    } catch (e) {
      debugPrint('[NotificationSettings] Crashlytics ayarı değiştirilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bildirim ve Gizlilik Tercihleri',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionCard(
                    theme,
                    child: SwitchListTile(
                      title: const Text(
                        'Bildirimleri Al',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Duyurular, topluluk gönderileri ve takvim '
                        'hatırlatıcıları. Kapatırsan bu cihaza push '
                        'gönderilmez ve zamanlanmış hatırlatıcılar çalmaz.',
                      ),
                      value: _notificationsEnabled,
                      onChanged: _onNotificationsChanged,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    theme,
                    child: SwitchListTile(
                      title: const Text(
                        'Çökme Raporları Gönder',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Uygulama beklenmedik şekilde kapandığında anonim '
                        'teknik hata raporu (Firebase Crashlytics) ve açılış/ağ '
                        'süresi gibi performans verileri (Firebase Performance '
                        'Monitoring) gönderilir — hataları bulup düzeltmemize '
                        've uygulamayı hızlandırmamıza yardımcı olur, kişisel '
                        'veri (e-posta, isim vb.) içermez.',
                      ),
                      value: _crashReportingEnabled,
                      onChanged: _onCrashReportingChanged,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard(ThemeData theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kritik bir güvenlik açığı veya kırıcı bir sunucu değişikliği durumunda,
/// eski sürümdeki kullanıcıları güncellemeye zorlayabilmek için basit bir
/// sunucu-taraflı sürüm kontrolü (bkz. kontrol.md Bölüm 31.6 — bu mekanizma
/// hiç yoktu).
///
/// `public.app_settings` tablosundaki `min_supported_android_build` /
/// `min_supported_ios_build` değerleri, uygulamanın kendi build numarasından
/// (pubspec.yaml `version: x.y.z+BUILD`) büyükse, kullanıcı güncelleme
/// yapana kadar kapatılamayan bir uyarı gösterilir. Admin bu değeri
/// Supabase Dashboard'dan (veya ileride bir admin panel alanından)
/// yükselterek eski sürümleri devre dışı bırakabilir.
class ForceUpdateService {
  ForceUpdateService._();

  static Future<Map<String, String>> _fetchSettings() async {
    final rows = await Supabase.instance.client
        .from('app_settings')
        .select('key, value');
    return {
      for (final r in (rows as List))
        (r as Map)['key'] as String: r['value'] as String,
    };
  }

  /// Sunucudan minimum sürüm bilgisini çeker; gerekiyorsa kapatılamayan bir
  /// güncelleme dialogu gösterir. Ağ hatası/tablo eksikse SESSİZCE geçilir —
  /// bu kontrol asla uygulamanın normal açılışını engellememeli.
  static Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    try {
      final settings = await _fetchSettings();
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      if (currentBuild <= 0) return;

      final buildKey = Platform.isIOS
          ? 'min_supported_ios_build'
          : 'min_supported_android_build';
      final storeKey = Platform.isIOS ? 'ios_store_url' : 'android_store_url';
      final minBuild = int.tryParse(settings[buildKey] ?? '') ?? 0;
      if (minBuild <= 0 || currentBuild >= minBuild) return;

      final storeUrl = settings[storeKey] ?? '';
      if (!context.mounted) return;
      await _showForceUpdateDialog(context, storeUrl);
    } catch (e) {
      debugPrint('[ForceUpdateService] Kontrol edilemedi (yok sayılıyor): $e');
    }
  }

  static Future<void> _showForceUpdateDialog(
    BuildContext context,
    String storeUrl,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Güncelleme Gerekli'),
          content: const Text(
            'NevGenç için önemli bir güncelleme yayınlandı. Kullanmaya devam '
            'edebilmek için uygulamayı güncellemeniz gerekiyor.',
          ),
          actions: [
            ElevatedButton(
              onPressed: storeUrl.isEmpty
                  ? null
                  : () => launchUrl(
                      Uri.parse(storeUrl),
                      mode: LaunchMode.externalApplication,
                    ),
              child: const Text('Şimdi Güncelle'),
            ),
          ],
        ),
      ),
    );
  }
}

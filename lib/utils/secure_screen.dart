import 'dart:io';
import 'package:flutter/services.dart';

/// Kupon kodu, üye e-postası gibi hassas veri gösteren ekranlarda Android
/// `FLAG_SECURE`'ü açıp kapatan yardımcı sınıf — görev değiştirici
/// önizlemesinde ve ekran görüntüsü/kayıtta içeriğin sızmasını engeller.
///
/// Aynı anda birden fazla hassas ekran açık olabileceğinden (ör. bir hassas
/// ekran diğerinin üzerine push edilirse) basit bir referans sayacı kullanılır:
/// yalnızca son hassas ekran da kapandığında bayrak gerçekten temizlenir.
///
/// iOS'ta karşılığı yok (Apple bu API'yi sunmuyor), bu yüzden no-op'tur.
class SecureScreen {
  SecureScreen._();

  static const MethodChannel _channel = MethodChannel(
    'com.nevgenc/secure_screen',
  );
  static int _activeCount = 0;

  /// Bu ekran açıkken ekran görüntüsü/kaydı engellenir. `initState()`'te çağırın.
  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    _activeCount++;
    if (_activeCount == 1) {
      await _channel.invokeMethod('setSecure', true);
    }
  }

  /// `enable()` ile eşleşen kapanış. `dispose()`'ta çağırın.
  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    if (_activeCount > 0) _activeCount--;
    if (_activeCount == 0) {
      await _channel.invokeMethod('setSecure', false);
    }
  }
}

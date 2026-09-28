import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Uygulama genelinde çevrimdışı/çevrimiçi durumunu tek bir yerden takip eder
/// (bkz. kontrol.md Bölüm 16.3/16.4 — önceden bağlantı durumu hiç izlenmiyordu,
/// yalnızca manuel pull-to-refresh vardı).
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  void start() {
    if (_sub != null) return;
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = !results.every((r) => r == ConnectivityResult.none);
    });
    // Başlangıç durumu — stream ilk event'i geç gönderebilir.
    Connectivity().checkConnectivity().then((results) {
      isOnline.value = !results.every((r) => r == ConnectivityResult.none);
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// Basit üstel geri çekilmeli (exponential backoff) yeniden deneme yardımcısı.
/// Yalnızca ağ/geçici hatalarda anlamlıdır — RLS/yetki hatalarında (kalıcı
/// hatalar) tekrar denemek zaman kaybıdır, bu yüzden çağıran taraf hangi
/// hataların yeniden denenebilir olduğuna karar vermeli.
Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (e) {
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}

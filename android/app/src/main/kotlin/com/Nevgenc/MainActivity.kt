package com.Nevgenc

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Hassas ekranlarda (kupon kodu, üye e-posta listesi) görev değiştirici
// önizlemesinde ve ekran görüntüsünde/kayıtta içeriğin görünmesini engellemek
// için FLAG_SECURE'ü Dart tarafından açıp kapatmayı sağlayan köprü.
// Bkz. kontrol.md Bölüm 7 — "Hassas ekranlarda Android FLAG_SECURE aktif".
class MainActivity: FlutterActivity() {
    private val secureScreenChannel = "com.nevgenc/secure_screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureScreenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.arguments as? Boolean ?: false
                        if (secure) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

/// `MaterialApp.builder`'a sarılıp uygulamanın her ekranının üstünde,
/// navigasyondan bağımsız şekilde çevrimdışı durumunu gösteren ince bir
/// bant. (bkz. kontrol.md Bölüm 16.3 — önceden bağlantı durumu hiç
/// gösterilmiyordu.)
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, isOnline, _) {
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isOnline
                  ? const SizedBox(width: double.infinity)
                  : Material(
                      color: const Color(0xFFD32F2F),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Çevrimdışısınız — bağlantı bekleniyor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

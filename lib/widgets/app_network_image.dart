import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// http/https URL'leri disk önbellekli gösterir; asset yollarını da destekler.
///
/// `Image.network` kullanımını kaldırmak için yazıldı: her ekran açılışında
/// görseller yeniden indirilmek yerine `cached_network_image` önbelleğinden
/// anında gelir. Yükleme sırasında ve hata durumunda `fallback` gösterilir.
class AppNetworkImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget Function()? placeholder;
  final Widget Function()? fallback;

  const AppNetworkImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.placeholder,
    this.fallback,
  });

  Widget _placeholder() {
    if (placeholder != null) return placeholder!();
    if (fallback != null) return fallback!();
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return _placeholder();
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    if (!isNetwork) {
      // Yerel dosya yolu (profil fotoğrafı gibi) → Image.file
      if (!path.startsWith('assets/') && File(path).existsSync()) {
        return Image.file(
          File(path),
          fit: fit,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) =>
              fallback?.call() ?? const SizedBox.shrink(),
        );
      }
      return Image.asset(
        path,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) =>
            fallback?.call() ?? const SizedBox.shrink(),
      );
    }
    return CachedNetworkImage(
      imageUrl: path,
      fit: fit,
      memCacheWidth: cacheWidth,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) =>
          fallback?.call() ?? const SizedBox.shrink(),
    );
  }
}

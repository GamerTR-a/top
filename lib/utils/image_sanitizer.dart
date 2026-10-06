import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Kullanıcı fotoğraflarındaki EXIF meta verisini (GPS konumu dahil) temizler.
/// Görsel Supabase Storage'a yüklenmeden önce JPEG'e yeniden kodlanır — bu
/// işlem EXIF segmentini tamamen atar. Dönme bilgisini kaybetmemek için önce
/// EXIF orientation piksellere "pişirilir". Uzun kenar [maxDimension]'ı
/// aşıyorsa görsel küçültülür (depolama kotası için).
class ImageSanitizer {
  static Future<File> stripExifAndReencode(
    File source, {
    int quality = 85,
    int maxDimension = 1600,
  }) async {
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return source;

      var oriented = img.bakeOrientation(decoded);
      if (oriented.width > maxDimension || oriented.height > maxDimension) {
        oriented = oriented.width >= oriented.height
            ? img.copyResize(oriented, width: maxDimension)
            : img.copyResize(oriented, height: maxDimension);
      }
      final jpgBytes = img.encodeJpg(oriented, quality: quality);

      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/sanitized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = await File(outPath).writeAsBytes(jpgBytes);
      return outFile;
    } catch (e) {
      debugPrint('[ImageSanitizer] EXIF temizleme başarısız, orijinal kullanılıyor: $e');
      return source;
    }
  }
}

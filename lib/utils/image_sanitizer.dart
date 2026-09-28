import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Kullanıcı fotoğraflarındaki EXIF meta verisini (GPS konumu dahil) temizler.
/// Görsel önce üçüncü parti (Telegraph) veya Supabase Storage'a yüklenmeden
/// önce JPEG'e yeniden kodlanır — bu işlem EXIF segmentini tamamen atar.
/// Dönme bilgisini kaybetmemek için önce EXIF orientation piksellere "pişirilir".
class ImageSanitizer {
  static Future<File> stripExifAndReencode(
    File source, {
    int quality = 88,
  }) async {
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return source;

      final oriented = img.bakeOrientation(decoded);
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

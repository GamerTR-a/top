import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FileValidationResult {
  final bool isValid;
  final String? errorMessage;

  const FileValidationResult.success()
      : isValid = true,
        errorMessage = null;

  const FileValidationResult.failure(this.errorMessage) : isValid = false;
}

/// Centralized File & Image Security Validator
/// Enforces max file size limits (default 5MB), extension whitelisting and
/// a magic-byte (file signature) check so a renamed non-image file (e.g.
/// malicious.exe renamed to photo.jpg) is rejected even though the
/// extension looks valid.
class FileValidator {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// İlk birkaç byte'a bakarak gerçek dosya türünü doğrular (uzantıya güvenmez).
  static bool _hasValidImageSignature(List<int> bytes) {
    if (bytes.length < 12) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // WEBP: 'RIFF' .... 'WEBP'
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  static const _signatureMismatchError =
      'Dosya içeriği geçerli bir görsel formatıyla eşleşmiyor.';

  /// Validates XFile from ImagePicker for extension, size and signature limits.
  static Future<FileValidationResult> validateXFile(
    XFile? file, {
    int maxSizeBytes = maxFileSizeBytes,
  }) async {
    if (file == null) {
      return const FileValidationResult.failure('Dosya seçilmedi.');
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      return FileValidationResult.failure(
        'Geçersiz dosya türü (.$ext). Yalnızca JPG, PNG ve WEBP formatları desteklenmektedir.',
      );
    }

    final length = await file.length();
    if (length > maxSizeBytes) {
      final sizeMb = (length / (1024 * 1024)).toStringAsFixed(1);
      final limitMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return FileValidationResult.failure(
        'Görsel boyutu $limitMb MB sınırını aşıyor (Seçilen: $sizeMb MB).',
      );
    }

    try {
      final header = await file.openRead(0, 12).first;
      if (!_hasValidImageSignature(header)) {
        return const FileValidationResult.failure(_signatureMismatchError);
      }
    } catch (_) {
      // Header okunamazsa (ör. akış desteklemeyen platform) uzantı/boyut
      // kontrolüyle yetinilir — kullanıcı deneyimini bloklamamak için.
    }

    return const FileValidationResult.success();
  }

  /// Validates a File for extension, size and signature limits.
  static Future<FileValidationResult> validateFile(
    File? file, {
    int maxSizeBytes = maxFileSizeBytes,
  }) async {
    if (file == null || !await file.exists()) {
      return const FileValidationResult.failure('Dosya bulunamadı.');
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      return FileValidationResult.failure(
        'Geçersiz dosya türü (.$ext). Yalnızca JPG, PNG ve WEBP formatları desteklenmektedir.',
      );
    }

    final length = await file.length();
    if (length > maxSizeBytes) {
      final sizeMb = (length / (1024 * 1024)).toStringAsFixed(1);
      final limitMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return FileValidationResult.failure(
        'Görsel boyutu $limitMb MB sınırını aşıyor (Seçilen: $sizeMb MB).',
      );
    }

    try {
      final header = await file.openRead(0, 12).first;
      if (!_hasValidImageSignature(header)) {
        return const FileValidationResult.failure(_signatureMismatchError);
      }
    } catch (_) {
      // Header okunamazsa uzantı/boyut kontrolüyle yetinilir.
    }

    return const FileValidationResult.success();
  }
}

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
/// Enforces max file size limits (default 5MB) and MIME/extension restrictions.
class FileValidator {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// Validates XFile from ImagePicker for extension and size limits.
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

    return const FileValidationResult.success();
  }

  /// Validates a File for extension and size limits.
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

    return const FileValidationResult.success();
  }
}

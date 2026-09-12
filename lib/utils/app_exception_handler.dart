import 'dart:async';
import 'package:flutter/material.dart';

class AppExceptionHandler {
  /// Converts any dynamic exception into a user-friendly Turkish message.
  static String parseErrorMessage(dynamic error) {
    if (error == null) return "Bilinmeyen bir hata oluştu.";

    final errString = error.toString().toLowerCase();

    if (error is TimeoutException || errString.contains('timeout')) {
      return "Sunucu yanıt vermedi. İnternet bağlantınızı kontrol edip tekrar deneyin.";
    }
    if (errString.contains('socketexception') || errString.contains('network') || errString.contains('connection failed')) {
      return "İnternet bağlantısı bulunamadı. Lütfen ağ ayarlarınızı kontrol edin.";
    }
    if (errString.contains('invalid login credentials') || errString.contains('invalid_credentials')) {
      return "E-posta adresi veya şifre hatalı.";
    }
    if (errString.contains('user_not_found') || errString.contains('user not found')) {
      return "Bu e-posta adresine ait bir kullanıcı bulunamadı.";
    }
    if (errString.contains('email_already_in_use') || errString.contains('already registered')) {
      return "Bu e-posta adresi zaten kullanımda.";
    }
    if (errString.contains('row-level security') || errString.contains('permission denied') || errString.contains('403')) {
      return "Bu işlemi gerçekleştirmek için gerekli yetkiniz bulunmuyor.";
    }
    if (errString.contains('404') || errString.contains('not found')) {
      return "İstenen kaynak bulunamadı.";
    }

    // Clean up raw error string if short
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.length < 80 && !message.contains('{')) {
      return message;
    }

    return "İşlem gerçekleştirilirken bir hata oluştu. Lütfen tekrar deneyin.";
  }

  /// Displays a standardized SnackBar with error message and optional retry action.
  static void showErrorSnackBar(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    final message = parseErrorMessage(error);
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Yeniden Dene',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}

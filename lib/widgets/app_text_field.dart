import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_spacing.dart';

/// Tüm formlarda kullanılan tek tip metin girişi.
/// Daha önce login/register/profile/dialog ekranlarında kopyalanan stil
/// burada tek kaynakta toplanmıştır (DRY).
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final AppTheme theme;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.theme,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textMuted),
        prefixIcon: Icon(icon, color: theme.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: theme.surface.withValues(alpha: 0.6),
        border: _border(theme.primary.withValues(alpha: 0.2)),
        enabledBorder: _border(theme.primary.withValues(alpha: 0.2)),
        focusedBorder: _border(theme.primary, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
      ),
    );
  }
}

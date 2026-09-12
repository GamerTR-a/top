import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import '../models/auth_user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/animated_theme_background.dart';
import 'register_screen.dart';

void _showForgotPasswordDialog(BuildContext context, AppTheme theme) {
  final emailCtrl = TextEditingController();
  bool loading = false;
  String? msg;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Şifre Sıfırla',
          style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'E-posta adresinize sıfırlama bağlantısı göndereceğiz.',
                style: TextStyle(color: theme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildDialogField(
                emailCtrl,
                'E-posta',
                Icons.email_outlined,
                theme,
              ),
              if (msg != null) ...[
                const SizedBox(height: 10),
                Text(
                  msg!,
                  style: TextStyle(color: theme.primary, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: loading
                ? null
                : () async {
                    setDialogState(() {
                      loading = true;
                      msg = null;
                    });
                    try {
                      await SupabaseAuthService.resetPassword(
                        emailCtrl.text.trim(),
                      );
                      setDialogState(() {
                        loading = false;
                        msg = 'Bağlantı gönderildi! E-postanızı kontrol edin.';
                      });
                    } catch (e) {
                      setDialogState(() {
                        loading = false;
                        msg = e.toString();
                      });
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Gönder'),
          ),
        ],
      ),
    ),
  ).whenComplete(emailCtrl.dispose);
}

Widget _buildDialogField(
  TextEditingController ctrl,
  String hint,
  IconData icon,
  AppTheme theme, {
  bool obscure = false,
}) {
  return AppTextField(
    controller: ctrl,
    hint: hint,
    icon: icon,
    theme: theme,
    obscure: obscure,
  );
}

class LoginScreen extends StatefulWidget {
  final void Function(AuthUser user) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _errorMsg;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'E-posta ve şifre alanları boş bırakılamaz.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final user = await SupabaseAuthService.login(
        email: email,
        password: password,
      );
      widget.onLoginSuccess(user);
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Giriş ekranında daima Geometrik teması görünsün
    final theme = AppTheme.geometric;
    return Scaffold(
      backgroundColor: theme.background,
      body: AnimatedThemeBackground(
        themeOverride: AppTheme.geometric,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                _Logo(),
                const SizedBox(height: 8),
                const Text(
                  'NevGenç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'NevGenç platformuna hoş geldin',
                  style: TextStyle(color: theme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 28),
                // ── E-posta ile giriş formu ────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _Field(
                          controller: _emailCtrl,
                          hint: 'E-posta adresiniz',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          controller: _passCtrl,
                          hint: 'Şifre',
                          icon: Icons.lock_outline,
                          obscure: !_passVisible,
                          theme: theme,
                          suffix: IconButton(
                            icon: Icon(
                              _passVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: theme.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _passVisible = !_passVisible),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: TextStyle(color: theme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showForgotPasswordDialog(context, theme),
                  child: Text(
                    'Şifremi Unuttum',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hesabın yok mu? ',
                      style: TextStyle(color: theme.textMuted),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final user = await Navigator.push<AuthUser>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                        if (user != null) widget.onLoginSuccess(user);
                      },
                      child: Text(
                        'Kayıt Ol',
                        style: TextStyle(
                          color: theme.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final AppTheme theme;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.theme,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hint: hint,
      icon: icon,
      theme: theme,
      obscure: obscure,
      keyboardType: keyboardType,
      suffix: suffix,
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.geometric;
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/app_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Color(0xFF023E8A),
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
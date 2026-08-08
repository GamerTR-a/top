import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _passVisible = false;
  bool _passConfirmVisible = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _birthDateCtrl.dispose();
    _departmentCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2002, 5, 15),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Doğum Tarihi Seçin',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        _birthDateCtrl.text = '$day.$month.$year';
      });
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Ad soyad boş olamaz.');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _errorMsg = 'Geçerli bir e-posta adresi girin.');
      return;
    }
    if (_birthDateCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Lütfen doğum tarihinizi girin.');
      return;
    }
    if (_departmentCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Lütfen bölüm bilginizi girin.');
      return;
    }
    if (_passCtrl.text.length < 8) {
      setState(() => _errorMsg = 'Şifre en az 8 karakter olmalıdır.');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(_passCtrl.text)) {
      setState(() => _errorMsg = 'Şifre en az bir büyük harf içermelidir.');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(_passCtrl.text)) {
      setState(() => _errorMsg = 'Şifre en az bir rakam içermelidir.');
      return;
    }
    if (_passCtrl.text != _passConfirmCtrl.text) {
      setState(() => _errorMsg = 'Şifreler eşleşmiyor.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final user = await SupabaseAuthService.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        birthDate: _birthDateCtrl.text.trim(),
        department: _departmentCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, user);
    } catch (e) {
      final msg = e.toString();
      if (msg.startsWith('Kayıt başarılı')) {
        if (mounted) _showEmailVerificationDialog(msg);
      } else {
        if (mounted) setState(() => _errorMsg = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEmailVerificationDialog(String message) {
    final theme = themeNotifier.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              color: theme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Kayıt Başarılı!',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Giriş Sayfasına Dön'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kayıt Ol',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/app_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              color: Color(0xFF023E8A),
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Hesap Oluştur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Topluluğa katılmak için kaydol',
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 28),
              _buildLabel('Ad Soyad', theme),
              _buildField(
                controller: _nameCtrl,
                hint: 'Adınız ve soyadınız',
                icon: Icons.person_outline,
                theme: theme,
              ),
              const SizedBox(height: 16),
              _buildLabel('E-posta', theme),
              _buildField(
                controller: _emailCtrl,
                hint: 'ornek@subu.edu.tr',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                theme: theme,
              ),
              const SizedBox(height: 16),
              _buildLabel('Doğum Tarihi', theme),
              GestureDetector(
                onTap: _selectBirthDate,
                child: AbsorbPointer(
                  child: _buildField(
                    controller: _birthDateCtrl,
                    hint: 'GG.AA.YYYY (Örn: 15.05.2002)',
                    icon: Icons.cake_outlined,
                    theme: theme,
                    suffix: IconButton(
                      icon: Icon(Icons.calendar_month_outlined, color: theme.primary, size: 20),
                      onPressed: _selectBirthDate,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel('Bölüm', theme),
              _buildField(
                controller: _departmentCtrl,
                hint: 'Örn: Bilişim Sistemleri Mühendisliği',
                icon: Icons.school_outlined,
                theme: theme,
              ),
              const SizedBox(height: 16),
              _buildLabel('Şifre', theme),
              _buildField(
                controller: _passCtrl,
                hint: 'En az 8 karakter, büyük harf ve rakam',
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
              const SizedBox(height: 16),
              _buildLabel('Şifre Tekrar', theme),
              _buildField(
                controller: _passConfirmCtrl,
                hint: 'Şifrenizi tekrar girin',
                icon: Icons.lock_outline,
                obscure: !_passConfirmVisible,
                theme: theme,
                suffix: IconButton(
                  icon: Icon(
                    _passConfirmVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: theme.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _passConfirmVisible = !_passConfirmVisible,
                  ),
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
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
                          'Kayıt Ol',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Zaten hesabın var mı? ',
                      style: TextStyle(color: theme.textMuted),
                      children: [
                        TextSpan(
                          text: 'Giriş Yap',
                          style: TextStyle(
                            color: theme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: theme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required AppTheme theme,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
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

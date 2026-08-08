import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import '../services/auth_service.dart';
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  bool _googleLoading = false;
  String? _errorMsg;

  final _userEmailCtrl = TextEditingController();
  final _userPassCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  bool _userPassVisible = false;
  bool _adminPassVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _errorMsg = null));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userEmailCtrl.dispose();
    _userPassCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final isAdmin = _tabController.index == 1;
    final email = isAdmin
        ? _adminEmailCtrl.text.trim()
        : _userEmailCtrl.text.trim();
    final password = isAdmin ? _adminPassCtrl.text : _userPassCtrl.text;

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
        isAdminLogin: isAdmin,
      );
      if (isAdmin && !user.isAdmin) {
        await SupabaseAuthService.logout();
        throw const SupabaseAuthException('Bu hesabın admin yetkisi yok.');
      }
      widget.onLoginSuccess(user);
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMsg = null;
    });
    try {
      final user = await SupabaseAuthService.signInWithGoogle();
      if (mounted) {
        setState(() => _googleLoading = false);
        widget.onLoginSuccess(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _showQuickProfileDialog(BuildContext context, AppTheme theme) {
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bolt, color: theme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hızlı Profil Oluştur',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parola hatırlama derdi yok! Ad, bölüm ve sınıf bilgilerinizi girerek doğrudan uygulamaya giriş yapın.',
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildDialogField(nameCtrl, 'Ad Soyad', Icons.person_outline, theme),
                const SizedBox(height: 12),
                _buildDialogField(deptCtrl, 'Bölüm (Örn: Bilişim Sistemleri Müh.)', Icons.school_outlined, theme),
                const SizedBox(height: 12),
                _buildDialogField(gradeCtrl, 'Sınıf (Örn: 1. Sınıf / 2. Sınıf)', Icons.class_outlined, theme),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final dept = deptCtrl.text.trim();
                final grade = gradeCtrl.text.trim();

                if (name.isEmpty || dept.isEmpty || grade.isEmpty) {
                  setDialogState(() {
                    dialogError = 'Lütfen tüm alanları doldurun.';
                  });
                  return;
                }

                final quickUser = AuthUser(
                  id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  email: '${name.toLowerCase().replaceAll(' ', '.')}@subu.edu.tr',
                  department: dept,
                  birthDate: grade,
                  isAdmin: false,
                  createdAt: DateTime.now(),
                );

                await AuthService.saveQuickUser(quickUser);
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onLoginSuccess(quickUser);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kayıt Ol ve Başla 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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

                // ⚡ "Tek Seferlik Profil Oluşturma" Bilgilendirme Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primary.withValues(alpha: 0.25),
                        theme.secondary.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Tek Seferlik Profil Oluşturma',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Parola hatırlama derdi olmadan; adınızı, bölümünüzü ve sınıfınızı girerek saniyeler içinde profilinizi oluşturun ve doğrudan uygulamaya giriş yapın.',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () => _showQuickProfileDialog(context, theme),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: const Text(
                            'Kayıt Ol ve Başla 🚀',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primary,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Google ile şifresiz giriş ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _googleLoading ? null : _loginWithGoogle,
                    icon: _googleLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF4285F4),
                            ),
                          )
                        : const _GoogleIcon(),
                    label: Text(
                      _googleLoading
                          ? 'Google ile giriş yapılıyor…'
                          : 'Google ile Giriş Yap',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4285F4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'veya e-posta ile',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      labelColor: theme.primary,
                      unselectedLabelColor: theme.textMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: 'Kullanıcı Girişi'),
                        Tab(text: 'Admin Girişi'),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: 220,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _LoginForm(
                              emailCtrl: _userEmailCtrl,
                              passCtrl: _userPassCtrl,
                              passVisible: _userPassVisible,
                              onTogglePass: () => setState(
                                () => _userPassVisible = !_userPassVisible,
                              ),
                              emailHint: 'E-posta adresiniz',
                              theme: theme,
                            ),
                            _LoginForm(
                              emailCtrl: _adminEmailCtrl,
                              passCtrl: _adminPassCtrl,
                              passVisible: _adminPassVisible,
                              onTogglePass: () => setState(
                                () => _adminPassVisible = !_adminPassVisible,
                              ),
                              emailHint: 'Admin e-postası',
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
              if (_tabController.index == 0) ...[
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
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _LoginForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool passVisible;
  final VoidCallback onTogglePass;
  final String emailHint;
  final AppTheme theme;

  const _LoginForm({
    required this.emailCtrl,
    required this.passCtrl,
    required this.passVisible,
    required this.onTogglePass,
    required this.emailHint,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          controller: emailCtrl,
          hint: emailHint,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          theme: theme,
        ),
        const SizedBox(height: 16),
        _Field(
          controller: passCtrl,
          hint: 'Şifre',
          icon: Icons.lock_outline,
          obscure: !passVisible,
          theme: theme,
          suffix: IconButton(
            icon: Icon(
              passVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: theme.textMuted,
              size: 20,
            ),
            onPressed: onTogglePass,
          ),
        ),
      ],
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

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFF4285F4), // Mavi
            Color(0xFFEA4335), // Kırmızı
            Color(0xFFFBBC05), // Sarı
            Color(0xFF34A853), // Yeşil
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          height: 1,
        ),
      ),
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

import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../constants/departments.dart';
import '../utils/turkish_text.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _deptSearchCtrl = TextEditingController();
  String? _selectedDepartment;
  bool _passVisible = false;
  bool _passConfirmVisible = false;
  bool _loading = false;
  String? _errorMsg;
  bool _showDepartmentDropdown = true;

  // Geri tuşuna basınca doldurulan form yanlışlıkla kaybolmasın (bkz.
  // kontrol.md Bölüm 23.7). Kayıt BAŞARILI olduğunda bu onay atlanmalı —
  // _skipUnsavedConfirmation başarı akışlarında true'ya çekilir ve
  // _pendingPopResult, onay sonrası (veya başarı sonrası) gerçekleşen
  // pop çağrısında caller'a döndürülecek değeri taşır. `PopScope.canPop`
  // resmi Flutter örneğindeki gibi (pop_scope.0.dart) sabit false kalabilir
  // ama burada hızlı yol için `!_hasUnsavedChanges` kullanılıyor — geri kalan
  // mantık, "engellenen ilk pop → onay/atla → tekrar pop çağır" örüntüsünü
  // izliyor; bu ikinci çağrı canPop'un anlık değerinden bağımsız başarılı olur.
  bool _skipUnsavedConfirmation = false;
  Object? _pendingPopResult;
  bool get _hasUnsavedChanges =>
      !_skipUnsavedConfirmation &&
      (_nameCtrl.text.trim().isNotEmpty ||
          _emailCtrl.text.trim().isNotEmpty ||
          _birthDateCtrl.text.trim().isNotEmpty ||
          _passCtrl.text.isNotEmpty ||
          _selectedDepartment != null);

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final theme = themeNotifier.value;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Kayıttan çık?', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Girdiğin bilgiler kaydedilmeden kaybolacak. Çıkmak istediğine emin misin?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: theme.error),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _backIfConfirmed() async {
    if (await _confirmDiscardChanges() && mounted) {
      Navigator.pop(context, _pendingPopResult);
    }
  }

  /// Başarılı kayıt/doğrulama sonrası çağrılır — onay dialogunu atlayarak
  /// [result] değeriyle ekrandan çıkar (bkz. yukarıdaki not).
  void _popWithSuccess(Object? result) {
    _pendingPopResult = result;
    _skipUnsavedConfirmation = true;
    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _birthDateCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    _deptSearchCtrl.dispose();
    super.dispose();
  }

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  static bool _isValidEduEmail(String email) {
    final normalizedEmail = email.toLowerCase().trim();
    return normalizedEmail.endsWith('.edu') ||
        normalizedEmail.endsWith('.edu.tr');
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
    if (!_isValidEduEmail(email)) {
      setState(() => _errorMsg =
          'Kayıt için sadece .edu veya .edu.tr uzantılı öğrenci e-postası kullanılabilir.');
      return;
    }
    if (_birthDateCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Lütfen doğum tarihinizi girin.');
      return;
    }
    if (_selectedDepartment == null || _selectedDepartment!.trim().isEmpty) {
      setState(() => _errorMsg = 'Lütfen bir bölüm seçin.');
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
        department: _selectedDepartment!,
      );
      if (mounted) _popWithSuccess(user);
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
              _popWithSuccess(null);
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
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _backIfConfirmed();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
            onPressed: _backIfConfirmed,
            tooltip: 'Geri',
          ),
          title: Text(
            'Kayıt Ol',
            style:
                TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
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
                Center(
                  child: Text(
                    'Hesap Oluştur',
                    style: TextStyle(
                      color: theme.textColor,
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
                  hint: 'ornek@subu.edu.tr / ornek@uni.edu',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  theme: theme,
                  autofillHints: const [AutofillHints.email],
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
                        icon: Icon(Icons.calendar_month_outlined,
                            color: theme.primary, size: 20),
                        onPressed: _selectBirthDate,
                        tooltip: 'Doğum Tarihi Seç',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Bölümünüz', theme),
                _buildDepartmentSelector(theme),
                const SizedBox(height: 16),
                _buildLabel('Şifre', theme),
                _buildField(
                  controller: _passCtrl,
                  hint: 'En az 8 karakter, büyük harf ve rakam',
                  icon: Icons.lock_outline,
                  obscure: !_passVisible,
                  theme: theme,
                  autofillHints: const [AutofillHints.newPassword],
                  suffix: IconButton(
                    icon: Icon(
                      _passVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: theme.textMuted,
                      size: 20,
                    ),
                    tooltip: _passVisible ? 'Şifreyi Gizle' : 'Şifreyi Göster',
                    onPressed: () =>
                        setState(() => _passVisible = !_passVisible),
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
                  autofillHints: const [AutofillHints.newPassword],
                  suffix: IconButton(
                    icon: Icon(
                      _passConfirmVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: theme.textMuted,
                      size: 20,
                    ),
                    tooltip: _passConfirmVisible
                        ? 'Şifreyi Gizle'
                        : 'Şifreyi Göster',
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
    Iterable<String>? autofillHints,
  }) {
    return AppTextField(
      controller: controller,
      hint: hint,
      icon: icon,
      theme: theme,
      obscure: obscure,
      keyboardType: keyboardType,
      suffix: suffix,
      autofillHints: autofillHints,
    );
  }

  Widget _buildDepartmentSelector(AppTheme theme) {
    final filterQuery = turkishToLower(_deptSearchCtrl.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seçim Alanı Başlığı / Seçilen Bölüm
        InkWell(
          onTap: () => setState(
              () => _showDepartmentDropdown = !_showDepartmentDropdown),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDepartment != null
                    ? theme.primary
                    : theme.primary.withValues(alpha: 0.2),
                width: _selectedDepartment != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedDepartment != null
                      ? Icons.radio_button_checked
                      : Icons.school_outlined,
                  color: theme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDepartment ?? 'Bölümünüzü seçin (Radio listesi)',
                    style: TextStyle(
                      color: _selectedDepartment != null
                          ? theme.textColor
                          : theme.textMuted,
                      fontSize: 14,
                      fontWeight: _selectedDepartment != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _showDepartmentDropdown ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: theme.textMuted, size: 24),
                ),
              ],
            ),
          ),
        ),
        // Radio Button Listesi Container
        if (_showDepartmentDropdown) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                // Bölüm Arama Kutusu
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    controller: _deptSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: theme.textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Bölüm ara...',
                      hintStyle:
                          TextStyle(color: theme.textMuted, fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search, color: theme.primary, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      filled: true,
                      fillColor: theme.background.withValues(alpha: 0.5),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: theme.primary.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: theme.primary.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.primary),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Radio Butonları Listesi
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: kDepartmentsByCategory.entries.map((entry) {
                        final filteredDepts = entry.value.where((dept) {
                          if (filterQuery.isEmpty) return true;
                          return turkishToLower(dept).contains(filterQuery);
                        }).toList();

                        if (filteredDepts.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                              color: theme.primary.withValues(alpha: 0.05),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...filteredDepts.map((dept) {
                              final isSelected = _selectedDepartment == dept;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDepartment = dept;
                                    _showDepartmentDropdown = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.primary
                                            .withValues(alpha: 0.04),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? theme.primary
                                            : theme.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dept,
                                          style: TextStyle(
                                            color: isSelected
                                                ? theme.primary
                                                : theme.textColor,
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

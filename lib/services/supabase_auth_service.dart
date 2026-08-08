import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../models/auth_user_model.dart';
import 'local_storage_service.dart';

class SupabaseAuthException implements Exception {
  final String message;
  const SupabaseAuthException(this.message);
  @override
  String toString() => message;
}

class SupabaseAuthService {
  static final _client = Supabase.instance.client;

  static void _validateEduEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw const SupabaseAuthException('Geçerli bir e-posta adresi giriniz.');
    }
    final domain = parts[1].toLowerCase();
    if (!domain.endsWith('.edu.tr') && !domain.endsWith('.edu')) {
      throw const SupabaseAuthException(
        'Sadece kurumsal öğrenci e-postalarıyla (.edu veya .edu.tr) kayıt olabilirsiniz.',
      );
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 8) {
      throw const SupabaseAuthException('Şifre en az 8 karakter olmalıdır.');
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      throw const SupabaseAuthException(
        'Şifre en az bir büyük harf içermelidir.',
      );
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      throw const SupabaseAuthException('Şifre en az bir rakam içermelidir.');
    }
  }

  static String _mapError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (msg.contains('email not confirmed')) {
      return 'E-posta adresinizi doğrulamanız gerekiyor. Lütfen gelen kutunuzu kontrol edin.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'Bu e-posta adresi zaten kayıtlı.';
    }
    if (msg.contains('password should be at least')) {
      return 'Şifre en az 8 karakter olmalıdır.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return 'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.';
    }
    if (msg.contains('row-level security') ||
        msg.contains('rls') ||
        msg.contains('violates')) {
      return 'Yetki hatası. Lütfen tekrar giriş yapın.';
    }
    if (msg.contains('cancel') ||
        msg.contains('cancelled') ||
        msg.contains('canceled')) {
      return 'Google ile giriş iptal edildi.';
    }
    if (msg.contains('provider is not enabled')) {
      return 'Google ile giriş henüz sunucuda etkinleştirilmemiş. Lütfen yöneticiyle iletişime geçin.';
    }
    if (msg.contains('invalid state') || msg.contains('invalid redirect')) {
      return 'Giriş bağlantısı geçersiz. Lütfen tekrar deneyin.';
    }
    return e.toString();
  }

  static Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    String? birthDate,
    String? department,
    String? grade,
  }) async {
    try {
      _validateEduEmail(email);
      _validatePassword(password);
      final res = await _client.auth.signUp(email: email, password: password);

      if (res.user == null) {
        throw const SupabaseAuthException(
          'Kayıt başarısız. Lütfen tekrar deneyin.',
        );
      }

      // Session varsa (e-posta doğrulama kapalı) profili hemen oluştur
      if (res.session != null) {
        await _insertProfile(
          userId: res.user!.id,
          name: name,
          birthDate: birthDate,
          department: department,
          grade: grade,
        );
        await _grantFirstBadge(res.user!.id);
      } else {
        // E-posta doğrulama açık: profil oluşturulamıyor (RLS)
        // Kullanıcı doğruladıktan sonra ilk girişte profil oluşturulacak.
        throw const SupabaseAuthException(
          'Kayıt başarılı! E-posta adresinize bir doğrulama bağlantısı gönderdik. '
          'Lütfen e-postanızı doğruladıktan sonra giriş yapın.',
        );
      }

      return AuthUser(
        id: res.user!.id,
        name: name,
        email: email,
        birthDate: birthDate,
        department: department,
        isAdmin: false,
        createdAt: DateTime.now(),
      );
    } on SupabaseAuthException {
      rethrow;
    } catch (e) {
      throw SupabaseAuthException(_mapError(e));
    }
  }

  static Future<void> _insertProfile({
    required String userId,
    required String name,
    String? birthDate,
    String? department,
    String? grade,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'name': name,
      'role': 'student',
      if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
      if (department != null && department.isNotEmpty) 'department': department,
      if (grade != null && grade.isNotEmpty) 'grade': grade,
    });
  }

  static Future<void> _grantFirstBadge(String userId) async {
    try {
      final badge = await _client
          .from('badges')
          .select('id')
          .eq('name', 'İlk Adım')
          .maybeSingle();
      if (badge != null) {
        await _client.from('user_badges').upsert({
          'user_id': userId,
          'badge_id': badge['id'],
        });
      }
    } catch (_) {}
  }

  /// Oturum açan kullanıcıyı cihaza önbelleğe alır (çevrimdışı açılış için).
  static Future<void> _cacheAuthUser(AuthUser user) async {
    try {
      final store = await LocalStorageService.getInstance();
      await store.saveAuthUser(user);
    } catch (_) {}
  }

  static Future<AuthUser> login({
    required String email,
    required String password,
    bool isAdminLogin = false,
  }) async {
    try {
      if (!isAdminLogin) _validateEduEmail(email);
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        throw const SupabaseAuthException('E-posta veya şifre hatalı.');
      }

      // Profil yoksa oluştur (e-posta doğrulama sonrası ilk giriş)
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', res.user!.id)
          .maybeSingle();

      final AuthUser authUser;
      if (profile == null) {
        await _insertProfile(
          userId: res.user!.id,
          name: res.user!.email?.split('@').first ?? 'Kullanıcı',
        );
        await _grantFirstBadge(res.user!.id);
        final newProfile = await _client
            .from('profiles')
            .select()
            .eq('id', res.user!.id)
            .single();
        authUser = AuthUser.fromProfileJson(res.user!, newProfile);
      } else {
        authUser = AuthUser.fromProfileJson(res.user!, profile);
      }
      await _cacheAuthUser(authUser);
      return authUser;
    } on SupabaseAuthException {
      rethrow;
    } catch (e) {
      throw SupabaseAuthException(_mapError(e));
    }
  }

  /// Google ile şifresiz giriş. Supabase OAuth (PKCE) akışını kullanır:
  /// tarayıcıda Google hesap seçici açılır, `supabase://login` derin linkiyle
  /// uygulamaya geri dönülür. İlk girişte profil Google bilgileriyle otomatik
  /// oluşturulur — hesap, `auth.uid()` ile tektir (aynı Google hesabı hep aynı
  /// kullanıcıya bağlanır).
  static Future<AuthUser> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'supabase://login',
      );

      final user = _client.auth.currentUser;
      if (user == null) {
        throw const SupabaseAuthException(
          'Google ile giriş tamamlanamadı. Lütfen tekrar deneyin.',
        );
      }

      // Google hesabı da aynı eğitim e-postası kısıtına tabi
      // (Google girişi yalnızca alternatif bir yöntemdir).
      final email = user.email ?? '';
      try {
        _validateEduEmail(email);
      } on SupabaseAuthException {
        // Geçersiz hesap: oturumu hemen kapat, uygulamaya giriş yapma.
        await _client.auth.signOut();
        throw const SupabaseAuthException(
          'Bu Google hesabı kurumsal bir öğrenci e-postasıyla '
          '(.edu veya .edu.tr) açılmadığı için giriş yapılamaz. '
          'Lütfen okul e-postanızla açılmış bir Google hesabı kullanın '
          'veya e-posta ile giriş yapın.',
        );
      }

      // İlk girişte profil yoksa Google bilgileriyle oluştur
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final AuthUser authUser;
      if (profile == null) {
        await _insertProfile(userId: user.id, name: _googleName(user));
        await _grantFirstBadge(user.id);
        final newProfile = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        authUser = AuthUser.fromProfileJson(user, newProfile);
      } else {
        authUser = AuthUser.fromProfileJson(user, profile);
      }
      await _cacheAuthUser(authUser);
      return authUser;
    } on SupabaseAuthException {
      rethrow;
    } catch (e) {
      throw SupabaseAuthException(_mapError(e));
    }
  }

  /// Google hesabından gösterilebilir bir ad çıkarır.
  static String _googleName(User user) {
    final fullName = user.userMetadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) return fullName;
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Kullanıcı';
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
    try {
      final store = await LocalStorageService.getInstance();
      await store.clearAuthUser();
    } catch (_) {}
  }

  static Future<AuthUser?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) return null;
      final authUser = AuthUser.fromProfileJson(user, profile);
      await _cacheAuthUser(authUser);
      return authUser;
    } catch (_) {
      // Çevrimdışı: yerel önbellekteki son oturumu döndür
      try {
        final store = await LocalStorageService.getInstance();
        return store.getAuthUser();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> changePassword({required String newPassword}) async {
    try {
      final res = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (res.user == null) {
        throw const SupabaseAuthException('Şifre güncellenemedi.');
      }
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException(_mapError(e));
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw SupabaseAuthException(_mapError(e));
    }
  }

  /// Kullanıcının hesabını ve ilişkili verilerini kalıcı olarak siler.
  /// Apple App Store yönergesi 5.1.1(v) gereği uygulama içi hesap silme zorunludur.
  ///
  /// Sunucu tarafında `delete_account` adlı bir Postgres fonksiyonu (SECURITY
  /// DEFINER) gerektirir; bkz. supabase/delete_account.sql.
  static Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SupabaseAuthException('Oturum bulunamadı.');
    }
    try {
      await _client.rpc('delete_account');
      await _client.auth.signOut();
    } catch (e) {
      throw SupabaseAuthException(_mapError(e));
    }
  }
}

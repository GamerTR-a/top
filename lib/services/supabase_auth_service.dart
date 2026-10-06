import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../models/auth_user_model.dart';
import 'fcm_service.dart';
import 'local_storage_service.dart';

class SupabaseAuthException implements Exception {
  final String message;
  const SupabaseAuthException(this.message);
  @override
  String toString() => message;
}

class SupabaseAuthService {
  static final _client = Supabase.instance.client;

  // Not: bu iki doğrulama fonksiyonu bilerek public — pub Dart'ta bir
  // library-private (`_`) üye başka bir dosyadaki (ör. test/) koddan asla
  // çağrılamaz, `@visibleForTesting` bunu değiştirmez. Birim testi
  // yazılabilmesi için (bkz. kontrol.md Bölüm 30.1) public yapıldı.
  static void validateEduEmail(String email) {
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

  static void validatePassword(String password) {
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
    // Not: "invalid credentials" ve "email not confirmed" bilerek AYNI mesajı
    // döndürür — aksi halde bu iki durum arasındaki fark, bir e-postanın
    // sistemde kayıtlı olup olmadığını dışarıya sızdırır (enumeration).
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password') ||
        msg.contains('email not confirmed')) {
      return 'E-posta veya şifre hatalı, ya da hesabınız henüz doğrulanmamış olabilir. '
          'Doğrulama e-postası gönderildiyse gelen kutunuzu kontrol edin.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      // Not: "zaten kayıtlı" gibi net bir mesaj yerine bilerek kayıt başarılı
      // akışıyla AYNI genel mesaj döndürülüyor — aksi halde bu mesaj bir
      // e-postanın sistemde kayıtlı olup olmadığını dışarıya sızdırır
      // (enumeration). "Kayıt başarılı" öneki register_screen.dart'ta
      // doğrulama dialog'unu tetikliyor (bkz. _showEmailVerificationDialog).
      return 'Kayıt başarılı! Eğer bu e-posta adresiyle daha önce hesap '
          'oluşturmadıysanız, gelen kutunuzu kontrol edip doğrulama '
          'bağlantısına tıklayın. Zaten bir hesabınız varsa doğrudan giriş '
          'yapmayı deneyebilirsiniz.';
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
      validateEduEmail(email);
      validatePassword(password);
      // Profil bilgileri user_metadata'ya da yazılır: e-posta doğrulaması
      // açıkken profil ilk girişte oluşturulur ve bu bilgiler oradan okunur.
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
          if (department != null && department.isNotEmpty) 'department': department,
          if (grade != null && grade.isNotEmpty) 'grade': grade,
        },
      );

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
    String? department, // Comma-separated string
    String? grade,
  }) async {
    // Convert comma-separated string to array for TEXT[] column
    List<String>? deptArray;
    if (department != null && department.isNotEmpty) {
      deptArray = department.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    await _client.from('profiles').upsert({
      'id': userId,
      'name': name,
      'role': 'student',
      if (deptArray != null && deptArray.isNotEmpty) 'department': deptArray,
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
    } catch (e) {
      // İlk rozet ikincil bir yan etki — kayıt akışını engellememesi için
      // yutuluyor, yalnızca gözlemlenebilir olsun diye logluyoruz.
      debugPrint('İlk rozet verilemedi: $e');
    }
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
  }) async {
    try {
      validateEduEmail(email);
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
        final meta = res.user!.userMetadata ?? const {};
        String? metaStr(String key) {
          final v = meta[key];
          return v is String && v.trim().isNotEmpty ? v.trim() : null;
        }

        await _insertProfile(
          userId: res.user!.id,
          name: metaStr('name') ??
              res.user!.email?.split('@').first ??
              'Kullanıcı',
          department: metaStr('department'),
          grade: metaStr('grade'),
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

  static Future<void> logout() async {
    // Oturum kapanmadan önce: RLS, token satırını yalnızca sahibine sildirir.
    await fcmService.unregisterTokenForCurrentUser();
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
      // Şifre değişince diğer cihaz/oturumlardaki eski refresh token'lar
      // geçersiz kılınır (bkz. kontrol.md Bölüm 4.9). Bu çağrı başarısız olsa
      // bile şifre zaten güncellendiği için kullanıcıya hata gösterilmez.
      try {
        await _client.auth.signOut(scope: SignOutScope.others);
      } catch (e) {
        if (kDebugMode) debugPrint('signOut(others) başarısız: $e');
      }
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException(_mapError(e));
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      // Öğrenci e-posta doğrulaması
      validateEduEmail(email);
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
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
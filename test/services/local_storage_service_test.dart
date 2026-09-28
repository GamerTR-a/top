import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:newgenc/models/auth_user_model.dart';
import 'package:newgenc/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Her testten önce bellek-içi sahte SharedPreferences'ı sıfırla.
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalStorageService — AuthUser önbelleği (kontrol.md Bölüm 30.1)', () {
    test('kaydedilen AuthUser aynı alanlarla geri okunur (JSON round-trip)', () async {
      final store = await LocalStorageService.getInstance();
      final user = AuthUser(
        id: 'user-123',
        name: 'Ayşe Yılmaz',
        email: 'ayse@sakarya.edu.tr',
        birthDate: '15.05.2002',
        department: 'Bilgisayar Mühendisliği',
        isAdmin: false,
        isBaskan: true,
        role: 'baskan',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final saved = await store.saveAuthUser(user);
      expect(saved, isTrue);

      final loaded = store.getAuthUser();
      expect(loaded, isNotNull);
      expect(loaded!.id, user.id);
      expect(loaded.name, user.name);
      expect(loaded.email, user.email);
      expect(loaded.birthDate, user.birthDate);
      expect(loaded.department, user.department);
      expect(loaded.isBaskan, user.isBaskan);
      expect(loaded.role, user.role);
      expect(loaded.createdAt, user.createdAt);
    });

    test('hiçbir kullanıcı kaydedilmemişse null döner', () async {
      final store = await LocalStorageService.getInstance();
      await store.clearAuthUser();
      expect(store.getAuthUser(), isNull);
    });

    test('clearAuthUser sonrası kullanıcı artık okunamaz', () async {
      final store = await LocalStorageService.getInstance();
      await store.saveAuthUser(
        AuthUser(
          id: 'u1',
          name: 'Test',
          email: 'test@sakarya.edu.tr',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      expect(store.getAuthUser(), isNotNull);

      await store.clearAuthUser();
      expect(store.getAuthUser(), isNull);
    });
  });

  group('LocalStorageService — bildirim tercihi', () {
    test('varsayılan olarak bildirimler açık', () async {
      final store = await LocalStorageService.getInstance();
      // Önceki testlerden kalan durumu temizle.
      await store.setNotificationsEnabled(true);
      expect(store.notificationsEnabled, isTrue);
    });

    test('kapatılan tercih doğru okunur', () async {
      final store = await LocalStorageService.getInstance();
      await store.setNotificationsEnabled(false);
      expect(store.notificationsEnabled, isFalse);
      await store.setNotificationsEnabled(true); // sıradaki testler için geri al
    });
  });
}

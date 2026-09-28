import 'package:flutter_test/flutter_test.dart';
import 'package:newgenc/services/supabase_auth_service.dart';

void main() {
  group('SupabaseAuthService.validateEduEmail', () {
    test('.edu.tr uzantılı e-posta kabul edilir', () {
      expect(() => SupabaseAuthService.validateEduEmail('ali@sakarya.edu.tr'),
          returnsNormally);
    });

    test('.edu uzantılı e-posta kabul edilir', () {
      expect(() => SupabaseAuthService.validateEduEmail('ali@mit.edu'),
          returnsNormally);
    });

    test('.edu.tr olmayan e-posta reddedilir', () {
      expect(
        () => SupabaseAuthService.validateEduEmail('ali@gmail.com'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('@ işareti olmayan e-posta reddedilir', () {
      expect(
        () => SupabaseAuthService.validateEduEmail('gecersiz-eposta'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('birden fazla @ içeren e-posta reddedilir', () {
      expect(
        () => SupabaseAuthService.validateEduEmail('a@b@sakarya.edu.tr'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('boş yerel kısım reddedilir', () {
      expect(
        () => SupabaseAuthService.validateEduEmail('@sakarya.edu.tr'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('büyük harfli uzantı da kabul edilir (case-insensitive)', () {
      expect(() => SupabaseAuthService.validateEduEmail('ali@sakarya.EDU.TR'),
          returnsNormally);
    });
  });

  group('SupabaseAuthService.validatePassword', () {
    test('geçerli şifre (8+ karakter, büyük harf, rakam) kabul edilir', () {
      expect(() => SupabaseAuthService.validatePassword('Sifre123'),
          returnsNormally);
    });

    test('8 karakterden kısa şifre reddedilir', () {
      expect(
        () => SupabaseAuthService.validatePassword('Ab1'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('büyük harf içermeyen şifre reddedilir', () {
      expect(
        () => SupabaseAuthService.validatePassword('sifre123'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('rakam içermeyen şifre reddedilir', () {
      expect(
        () => SupabaseAuthService.validatePassword('SifreSifre'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('tam olarak 8 karakter olan sınır durumu kabul edilir', () {
      expect(() => SupabaseAuthService.validatePassword('Abcdefg1'),
          returnsNormally);
    });
  });
}

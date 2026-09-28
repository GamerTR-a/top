import 'package:flutter_test/flutter_test.dart';
import 'package:newgenc/utils/turkish_text.dart';

void main() {
  group('turkishToLower', () {
    test('İ (noktȧlı büyük I) doğru şekilde ı-siz i\'ye döner', () {
      expect(turkishToLower('İstanbul'), 'istanbul');
    });

    test('I (noktasız büyük I) doğru şekilde ı\'ya döner', () {
      expect(turkishToLower('IĞDIR'), 'ığdır');
    });

    test('standart toLowerCase ile turkishToLower farklı sonuç verir (asıl hata)', () {
      // Dart'ın locale-bağımsız toLowerCase()'i ASCII "I"yı Türkçe kuralına
      // göre "ı" yerine "i" yapar — "IĞDIR" arandığında "iğdir" bulunur,
      // "ığdır" ile EŞLEŞMEZ. Bu, turkishToLower()'ın var olma sebebi.
      expect('IĞDIR'.toLowerCase() == 'ığdır', isFalse);
      expect(turkishToLower('IĞDIR') == 'ığdır', isTrue);
    });

    test('ASCII metinlerde davranış değişmez', () {
      expect(turkishToLower('Bilgisayar Mühendisliği'), 'bilgisayar mühendisliği');
    });

    test('boş string için boş string döner', () {
      expect(turkishToLower(''), '');
    });

    test('karışık büyük/küçük harf ve rakamlar', () {
      expect(turkishToLower('SAÜ Bilişim2024'), 'saü bilişim2024');
    });
  });
}

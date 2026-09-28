/// Türkçe metin arama/karşılaştırma yardımcıları.
///
/// Dart'ın standart `String.toLowerCase()`'i locale-bağımsızdır ve ASCII
/// büyük "I" harfini (noktasız, U+0049) Türkçe kuralına göre "ı" yerine "i"
/// harfine çevirir — kullanıcı "ığdır" yazdığında "IĞDIR" içeren bir kayıtla
/// eşleşmez (test edildi: `'IĞDIR'.toLowerCase()` → `'iğdir'`, doğrusu
/// `'ığdır'`). Büyük "İ" (noktalı, U+0130) için Dart'ın varsayılanı zaten
/// doğru sonucu ("i") veriyor — yine de açıkça ele alınıyor. Bu fonksiyon bu
/// iki Türkçe'ye özgü eşlemeyi elle uygulayıp geri kalanı `toLowerCase()`'e
/// bırakır (bkz. kontrol.md Bölüm 22.2, test: `test/utils/turkish_text_test.dart`).
String turkishToLower(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    switch (rune) {
      case 0x0130: // İ (LATIN CAPITAL LETTER I WITH DOT ABOVE)
        buffer.write('i');
        break;
      case 0x0049: // I (LATIN CAPITAL LETTER I)
        buffer.write('ı');
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().toLowerCase();
}

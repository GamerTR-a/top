import 'package:flutter_test/flutter_test.dart';
import 'package:newgenc/services/supabase_data_service.dart';

void main() {
  group('SupabaseDataService.isoWeek', () {
    // Not: haftalık destek limitinin güvenliği artık sunucu tarafında
    // (EXTRACT(WEEK FROM NOW())) sağlanıyor — bkz. kontrol.md Bölüm 8.8.
    // Bu testler yalnızca istemci tarafı anlık gösterimin doğruluğunu
    // (ISO-8601 hafta numaralandırması) doğrular.

    test('yılın ilk haftası 1 döner', () {
      expect(SupabaseDataService.isoWeek(DateTime(2026, 1, 1)), 1);
    });

    test('bilinen bir ISO hafta numarasını doğru hesaplar (2026-09-27 Pazar)', () {
      // 2026-09-27 Pazar, ISO'ya göre 2026'nın 39. haftasının son günü.
      expect(SupabaseDataService.isoWeek(DateTime(2026, 9, 27)), 39);
    });

    test('aynı ISO haftasındaki ardışık günler aynı hafta numarasını verir', () {
      final monday = DateTime(2026, 9, 21);
      final sunday = DateTime(2026, 9, 27);
      expect(
        SupabaseDataService.isoWeek(monday),
        SupabaseDataService.isoWeek(sunday),
      );
    });

    test('bir sonraki haftaya geçişte numara artar', () {
      final thisWeek = SupabaseDataService.isoWeek(DateTime(2026, 9, 27));
      final nextWeek = SupabaseDataService.isoWeek(DateTime(2026, 9, 28));
      expect(nextWeek, thisWeek + 1);
    });

    test('yıl sonu/başı geçişinde (ISO hafta önceki yıla ait olabilir) çökmez', () {
      // 2027-01-01 Cuma — ISO takvimine göre hâlâ 2026'nın son haftasında
      // olabilir; fonksiyonun negatif/hatalı değer üretmeden çalıştığını
      // doğrular (asıl amaç: sonsuz özyinelemeye girmemesi).
      expect(() => SupabaseDataService.isoWeek(DateTime(2027, 1, 1)),
          returnsNormally);
      expect(SupabaseDataService.isoWeek(DateTime(2027, 1, 1)), greaterThan(0));
    });
  });
}

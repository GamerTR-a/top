import 'package:flutter_test/flutter_test.dart';
import 'package:newgenc/services/connectivity_service.dart';

void main() {
  group('retryWithBackoff', () {
    test('ilk denemede başarılı olursa tekrar denemez', () async {
      var calls = 0;
      final result = await retryWithBackoff<int>(() async {
        calls++;
        return 42;
      });
      expect(result, 42);
      expect(calls, 1);
    });

    test('geçici hatalarda başarılı olana kadar tekrar dener', () async {
      var calls = 0;
      final result = await retryWithBackoff<int>(
        () async {
          calls++;
          if (calls < 3) throw Exception('geçici hata');
          return 7;
        },
        initialDelay: const Duration(milliseconds: 1),
      );
      expect(result, 7);
      expect(calls, 3);
    });

    test('maxAttempts sonunda hâlâ başarısızsa son hatayı fırlatır', () async {
      var calls = 0;
      await expectLater(
        retryWithBackoff<int>(
          () async {
            calls++;
            throw Exception('kalıcı hata');
          },
          maxAttempts: 2,
          initialDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<Exception>()),
      );
      expect(calls, 2);
    });
  });
}

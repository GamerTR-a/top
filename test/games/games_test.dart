import 'package:flutter_test/flutter_test.dart';
import 'package:newgenc/models/quiz_question.dart';
import 'package:newgenc/screens/games/daily_word_game.dart';
import 'package:newgenc/screens/games/word_list.dart';

void main() {
  const c = LetterMark.correct;
  const p = LetterMark.present;
  const a = LetterMark.absent;

  group('evaluateGuess', () {
    test('tamamı doğru', () {
      expect(evaluateGuess('kitap', 'kitap'), [c, c, c, c, c]);
    });

    test('yeri yanlış ve olmayan harfler', () {
      expect(evaluateGuess('takip', 'kitap'), [p, p, p, p, c]);
      expect(evaluateGuess('deniz', 'kitap'), [a, a, a, p, a]);
    });

    test('tekrarlı harf cevaptaki adet kadar işaretlenir', () {
      // "kabak"ta iki a var, "araba"da üç: üçüncü a işaretlenmez.
      expect(evaluateGuess('araba', 'kabak'), [p, a, p, p, a]);
      // Doğru konumdaki harf önceliklidir.
      expect(evaluateGuess('kalem', 'kekik'), [c, a, a, p, a]);
    });

    test('ı ve i ayrı harflerdir', () {
      expect(evaluateGuess('sınıf', 'silgi'), [c, a, a, a, a]);
    });
  });

  group('dailyWordFor', () {
    test('aynı gün aynı kelime, liste içinden', () {
      final day = DateTime(2026, 10, 7, 15, 30);
      expect(dailyWordFor(day), dailyWordFor(DateTime(2026, 10, 7)));
      expect(dailyWordAnswers, contains(dailyWordFor(day)));
    });

    test('liste bitene kadar kelime tekrar etmez', () {
      final start = DateTime(2026, 1, 1);
      final words = {
        for (var i = 0; i < dailyWordAnswers.length; i++)
          dailyWordFor(DateTime(start.year, start.month, start.day + i)),
      };
      expect(words.length, dailyWordAnswers.length);
    });
  });

  test('kelime listesi: 5 harf, küçük harf, tekrarsız', () {
    final letters = RegExp(r'^[abcçdefgğhıijklmnoöprsştuüvyz]{5}$');
    for (final w in dailyWordAnswers) {
      expect(letters.hasMatch(w), isTrue, reason: w);
    }
    expect(dailyWordAnswers.toSet().length, dailyWordAnswers.length);
  });

  test('gömülü sorular: 4 farklı şık, geçerli doğru şık', () {
    expect(bundledQuizQuestions.length, greaterThanOrEqualTo(10));
    for (final q in bundledQuizQuestions) {
      expect(q.options.length, 4, reason: q.question);
      expect(q.options.toSet().length, 4, reason: q.question);
      expect(q.correctIndex, inInclusiveRange(0, 3), reason: q.question);
      expect(quizCategories, contains(q.category), reason: q.question);
    }
  });

  test('QuizQuestion.tryFromApiJson geçersiz kaydı reddeder', () {
    expect(
      QuizQuestion.tryFromApiJson({
        'id': 1,
        'question': 'Soru?',
        'options': ['a', 'b', 'c'],
        'correct_index': 0,
      }),
      isNull,
    );
    final ok = QuizQuestion.tryFromApiJson({
      'id': 2,
      'question': 'Soru?',
      'options': ['a', 'b', 'c', 'd'],
      'correct_index': 2,
      'category': 'Bilim',
    });
    expect(ok?.correctAnswer, 'c');
  });
}

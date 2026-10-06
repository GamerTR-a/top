import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_background.dart';
import 'word_list.dart';

enum LetterMark { absent, present, correct }

/// Tahmindeki her harfi işaretler. Tekrarlı harflerde cevaptaki adet kadar
/// harf işaretlenir (önce doğru konumdakiler).
List<LetterMark> evaluateGuess(String guess, String answer) {
  final g = guess.split('');
  final a = answer.split('');
  final marks = List.filled(g.length, LetterMark.absent);
  final remaining = <String, int>{};
  for (var i = 0; i < a.length; i++) {
    if (g[i] == a[i]) {
      marks[i] = LetterMark.correct;
    } else {
      remaining[a[i]] = (remaining[a[i]] ?? 0) + 1;
    }
  }
  for (var i = 0; i < g.length; i++) {
    if (marks[i] == LetterMark.correct) continue;
    final left = remaining[g[i]] ?? 0;
    if (left > 0) {
      marks[i] = LetterMark.present;
      remaining[g[i]] = left - 1;
    }
  }
  return marks;
}

/// Verilen günün kelimesi — herkes için aynıdır.
String dailyWordFor(DateTime day) {
  final dayNumber = DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(2026, 1, 1))
      .inDays;
  // 7919 asal ve liste uzunluğuyla aralarında asal olduğu sürece kelimeler
  // tekrar etmeden, alfabetik olmayan bir sırayla dolaşılır.
  final n = dailyWordAnswers.length;
  return dailyWordAnswers[((dayNumber * 7919) % n + n) % n];
}

String _upperTr(String s) => s
    .replaceAll('i', 'İ')
    .replaceAll('ı', 'I')
    .toUpperCase();

/// Günün Kelimesi — her gün herkese aynı 5 harfli kelime, 6 tahmin hakkı.
class DailyWordGame extends StatefulWidget {
  const DailyWordGame({super.key});

  @override
  State<DailyWordGame> createState() => _DailyWordGameState();
}

class _DailyWordGameState extends State<DailyWordGame> {
  static const _maxGuesses = 6;
  static const _wordLength = 5;
  static const _rows = [
    ['e', 'r', 't', 'y', 'u', 'ı', 'o', 'p', 'ğ', 'ü'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ş', 'i'],
    ['z', 'c', 'v', 'b', 'n', 'm', 'ö', 'ç'],
  ];

  static const _kDate = 'daily_word_date';
  static const _kGuesses = 'daily_word_guesses';
  static const _kPlayed = 'daily_word_played';
  static const _kWins = 'daily_word_wins';
  static const _kStreak = 'daily_word_streak';
  static const _kLastWin = 'daily_word_last_win';

  late final DateTime _today;
  late final String _answer;
  late final String _dateKey;

  final List<String> _guesses = [];
  String _current = '';
  bool _loading = true;
  int _played = 0;
  int _wins = 0;
  int _streak = 0;

  bool get _won => _guesses.isNotEmpty && _guesses.last == _answer;
  bool get _finished => _won || _guesses.length >= _maxGuesses;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _answer = dailyWordFor(_today);
    _dateKey = _fmt(_today);
    _restore();
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (prefs.getString(_kDate) == _dateKey) {
        _guesses.addAll(
          (prefs.getStringList(_kGuesses) ?? const [])
              .where((g) => g.runes.length == _wordLength)
              .take(_maxGuesses),
        );
      }
      _played = prefs.getInt(_kPlayed) ?? 0;
      _wins = prefs.getInt(_kWins) ?? 0;
      _streak = prefs.getInt(_kStreak) ?? 0;
      // Dün kazanılmadıysa seri bozulmuştur.
      final lastWin = prefs.getString(_kLastWin);
      final yesterday = _fmt(_today.subtract(const Duration(days: 1)));
      if (lastWin != _dateKey && lastWin != yesterday) _streak = 0;
      _loading = false;
    });
  }

  Future<void> _persist({required bool justFinished}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDate, _dateKey);
    await prefs.setStringList(_kGuesses, _guesses);
    if (justFinished) {
      await prefs.setInt(_kPlayed, _played);
      await prefs.setInt(_kWins, _wins);
      await prefs.setInt(_kStreak, _streak);
      if (_won) await prefs.setString(_kLastWin, _dateKey);
    }
  }

  void _type(String letter) {
    if (_finished || _current.length >= _wordLength) return;
    setState(() => _current += letter);
  }

  void _backspace() {
    if (_finished || _current.isEmpty) return;
    setState(() => _current = _current.substring(0, _current.length - 1));
  }

  void _submit() {
    if (_finished) return;
    if (_current.length < _wordLength) {
      _toast('Kelime 5 harfli olmalı.');
      return;
    }
    setState(() {
      _guesses.add(_current);
      _current = '';
      if (_finished) {
        _played++;
        if (_won) {
          _wins++;
          _streak++;
        } else {
          _streak = 0;
        }
      }
    });
    _persist(justFinished: _finished);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Klavyede her harfin şimdiye kadarki en iyi işareti.
  Map<String, LetterMark> get _keyMarks {
    final marks = <String, LetterMark>{};
    for (final guess in _guesses) {
      final eval = evaluateGuess(guess, _answer);
      for (var i = 0; i < guess.length; i++) {
        final prev = marks[guess[i]];
        if (prev == null || eval[i].index > prev.index) {
          marks[guess[i]] = eval[i];
        }
      }
    }
    return marks;
  }

  void _share() {
    const squares = {
      LetterMark.correct: '🟩',
      LetterMark.present: '🟨',
      LetterMark.absent: '⬜',
    };
    final grid = _guesses
        .map((g) => evaluateGuess(g, _answer).map((m) => squares[m]).join())
        .join('\n');
    final score = _won ? '${_guesses.length}/$_maxGuesses' : 'X/$_maxGuesses';
    Clipboard.setData(
      ClipboardData(text: 'NevGenç Günün Kelimesi $_dateKey  $score\n$grid'),
    );
    _toast('Sonuç panoya kopyalandı.');
  }

  Color _markColor(LetterMark mark, AppTheme theme) => switch (mark) {
        LetterMark.correct => const Color(0xFF43A047),
        LetterMark.present => const Color(0xFFF9A825),
        LetterMark.absent => theme.isDark
            ? const Color(0xFF475569)
            : const Color(0xFF94A3B8),
      };

  Widget _tile(String letter, LetterMark? mark, AppTheme theme, bool active) {
    final filled = mark != null;
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _markColor(mark, theme) : theme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : (letter.isNotEmpty || active)
                    ? theme.primary.withValues(alpha: 0.6)
                    : theme.textMuted.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              _upperTr(letter),
              style: TextStyle(
                color: filled ? Colors.white : theme.textColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _board(AppTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < _maxGuesses; row++)
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < _wordLength; col++)
                  Flexible(
                    child: () {
                      if (row < _guesses.length) {
                        final guess = _guesses[row];
                        return _tile(
                          guess[col],
                          evaluateGuess(guess, _answer)[col],
                          theme,
                          false,
                        );
                      }
                      final isActive = row == _guesses.length && !_finished;
                      final letter = isActive && col < _current.length
                          ? _current[col]
                          : '';
                      return _tile(letter, null, theme, isActive);
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _key(
    AppTheme theme, {
    required Widget child,
    required VoidCallback onTap,
    required String semanticLabel,
    Color? color,
    int flex = 2,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: Material(
            color: color ??
                (theme.isDark
                    ? theme.surface.withValues(alpha: 0.9)
                    : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox(height: 46, child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyboard(AppTheme theme) {
    final marks = _keyMarks;
    Widget letterKey(String l) {
      final mark = marks[l];
      return _key(
        theme,
        semanticLabel: _upperTr(l),
        color: mark == null ? null : _markColor(mark, theme),
        onTap: () => _type(l),
        child: Text(
          _upperTr(l),
          style: TextStyle(
            color: mark == null ? theme.textColor : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [for (final l in _rows[0]) letterKey(l)]),
        Row(children: [for (final l in _rows[1]) letterKey(l)]),
        Row(
          children: [
            _key(
              theme,
              flex: 3,
              semanticLabel: 'Tahmini gönder',
              color: theme.primary,
              onTap: _submit,
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
            for (final l in _rows[2]) letterKey(l),
            _key(
              theme,
              flex: 3,
              semanticLabel: 'Sil',
              onTap: _backspace,
              child: Icon(Icons.backspace_outlined,
                  color: theme.textColor, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultPanel(AppTheme theme) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
    final winRate = _played == 0 ? 0 : (_wins * 100 / _played).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _won ? 'Tebrikler!' : 'Bugünlük bitti',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _won
                ? '${_guesses.length}. tahminde buldun.'
                : 'Günün kelimesi: ${_upperTr(_answer)}',
            style: TextStyle(color: theme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('$_played', 'Oynanan'),
              stat('%$winRate', 'Kazanma'),
              stat('$_streak', 'Seri'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Yeni kelime gece yarısı gelir.',
            style: TextStyle(color: theme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _share,
              icon: Icon(Icons.copy_rounded, size: 18, color: theme.primary),
              label: Text(
                'Sonucu Kopyala',
                style: TextStyle(color: theme.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(AppTheme theme) {
    Widget legend(Color c, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: theme.textColor, fontSize: 13),
                ),
              ),
            ],
          ),
        );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nasıl Oynanır?',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5 harfli günün kelimesini 6 tahminde bul. Her tahminden sonra '
              'harflerin rengi ipucu verir:',
              style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            legend(_markColor(LetterMark.correct, theme),
                'Harf doğru ve yeri doğru'),
            legend(_markColor(LetterMark.present, theme),
                'Harf kelimede var ama yeri yanlış'),
            legend(_markColor(LetterMark.absent, theme), 'Harf kelimede yok'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: theme.textColor),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Text(
              'Günün Kelimesi',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.help_outline_rounded, color: theme.textColor),
                tooltip: 'Nasıl oynanır',
                onPressed: () => _showHelp(theme),
              ),
            ],
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.primary),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 340),
                                child: _board(theme),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_finished)
                            _resultPanel(theme)
                          else
                            _keyboard(theme),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

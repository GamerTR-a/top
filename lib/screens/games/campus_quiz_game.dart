import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/quiz_question.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_background.dart';

/// Oyunda gösterilen soru: şıkları karıştırılmış hâli.
class _Round {
  final QuizQuestion source;
  final List<String> options;
  final int correctIndex;

  _Round(this.source, this.options, this.correctIndex);

  factory _Round.shuffled(QuizQuestion q, Random rng) {
    final order = [0, 1, 2, 3]..shuffle(rng);
    return _Round(
      q,
      [for (final i in order) q.options[i]],
      order.indexOf(q.correctIndex),
    );
  }
}

enum _Phase { loading, intro, playing, finished }

/// Kampüs Bilgi Yarışması — 10 soru, soru başına 20 saniye.
/// Sorular: uygulamayla gelenler + admin panelinden eklenenler.
class CampusQuizGame extends StatefulWidget {
  const CampusQuizGame({super.key});

  @override
  State<CampusQuizGame> createState() => _CampusQuizGameState();
}

class _CampusQuizGameState extends State<CampusQuizGame> {
  static const _questionsPerGame = 10;
  static const _secondsPerQuestion = 20;
  static const _kBest = 'campus_quiz_best_score';

  final _rng = Random();
  List<QuizQuestion> _pool = bundledQuizQuestions;
  List<_Round> _rounds = [];
  _Phase _phase = _Phase.loading;

  int _index = 0;
  int _score = 0;
  int _correctCount = 0;
  int _best = 0;
  bool _newBest = false;
  int _secondsLeft = _secondsPerQuestion;
  int? _picked; // -1: süre doldu
  Timer? _timer;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var remote = const <QuizQuestion>[];
    try {
      remote = await SupabaseDataService()
          .getRemoteQuizQuestions()
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      // Ağ yok ya da tablo henüz yok: gömülü sorularla devam.
      debugPrint('[Quiz] Ek sorular alınamadı: $e');
    }
    if (!mounted) return;
    setState(() {
      _pool = [...remote, ...bundledQuizQuestions];
      _best = prefs.getInt(_kBest) ?? 0;
      _phase = _Phase.intro;
    });
  }

  void _start() {
    final picked = [..._pool]..shuffle(_rng);
    setState(() {
      _rounds = [
        for (final q in picked.take(_questionsPerGame)) _Round.shuffled(q, _rng),
      ];
      _index = 0;
      _score = 0;
      _correctCount = 0;
      _newBest = false;
      _phase = _Phase.playing;
    });
    _startQuestion();
  }

  void _startQuestion() {
    _timer?.cancel();
    setState(() {
      _picked = null;
      _secondsLeft = _secondsPerQuestion;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _answer(-1);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _answer(int choice) {
    if (_picked != null || _phase != _Phase.playing) return;
    _timer?.cancel();
    final correct = choice == _rounds[_index].correctIndex;
    setState(() {
      _picked = choice;
      if (choice == -1) _secondsLeft = 0;
      if (correct) {
        _correctCount++;
        _score += 10 + _secondsLeft ~/ 2;
      }
    });
    _advanceTimer = Timer(
      Duration(milliseconds: correct ? 900 : 1800),
      _next,
    );
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 < _rounds.length) {
      setState(() => _index++);
      _startQuestion();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final isBest = _score > _best;
    setState(() {
      _phase = _Phase.finished;
      _newBest = isBest;
      if (isBest) _best = _score;
    });
    if (isBest) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kBest, _score);
    }
  }

  Future<bool> _confirmQuit(AppTheme theme) async {
    if (_phase != _Phase.playing) return true;
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Yarışmadan çık?', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Bu turdaki puanın kaydedilmeyecek.',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam Et'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Çık', style: TextStyle(color: theme.error)),
          ),
        ],
      ),
    );
    return quit == true;
  }

  Widget _primaryButton(AppTheme theme, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _intro(AppTheme theme) {
    Widget rule(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, color: theme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: theme.textColor, fontSize: 13.5),
                ),
              ),
            ],
          ),
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.quiz_rounded, color: theme.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              'Kampüs Bilgi Yarışması',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'En yüksek puanın: $_best',
              style: TextStyle(color: theme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  rule(Icons.format_list_numbered_rounded,
                      '$_questionsPerGame soru: Sakarya, kampüs ve genel kültür'),
                  rule(Icons.timer_outlined,
                      'Her soru için $_secondsPerQuestion saniye'),
                  rule(Icons.bolt_rounded,
                      'Doğru cevap 10 puan; hızlı cevaplarsan ek puan'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _primaryButton(theme, 'Başla', _start),
          ],
        ),
      ),
    );
  }

  Widget _option(AppTheme theme, _Round round, int i) {
    final answered = _picked != null;
    final isCorrect = i == round.correctIndex;
    final isPicked = i == _picked;

    Color border = theme.textMuted.withValues(alpha: 0.25);
    Color fill = theme.surface;
    IconData? icon;
    if (answered && isCorrect) {
      border = const Color(0xFF43A047);
      fill = const Color(0xFF43A047).withValues(alpha: 0.15);
      icon = Icons.check_circle_rounded;
    } else if (answered && isPicked) {
      border = theme.error;
      fill = theme.error.withValues(alpha: 0.12);
      icon = Icons.cancel_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: answered ? null : () => _answer(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'ABCD'[i],
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    round.options[i],
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (icon != null) Icon(icon, color: border, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playing(AppTheme theme) {
    final round = _rounds[_index];
    final lowTime = _secondsLeft <= 5;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Row(
          children: [
            Text(
              'Soru ${_index + 1}/${_rounds.length}',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.star_rounded, color: theme.warning, size: 18),
            const SizedBox(width: 4),
            Text(
              '$_score',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _secondsLeft / _secondsPerQuestion,
                  minHeight: 6,
                  backgroundColor: theme.textMuted.withValues(alpha: 0.2),
                  color: lowTime ? theme.error : theme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Text(
                '$_secondsLeft sn',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: lowTime ? theme.error : theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          round.source.category,
          style: TextStyle(
            color: theme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          round.source.question,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 19,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < 4; i++) _option(theme, round, i),
        if (_picked == -1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Süre doldu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.error, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _finished(AppTheme theme) {
    final total = _rounds.length;
    final message = _correctCount == total
        ? 'Kusursuz!'
        : _correctCount >= total * 0.7
            ? 'Çok iyi!'
            : _correctCount >= total * 0.4
                ? 'Fena değil'
                : 'Bir tur daha dene';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.emoji_events_rounded, color: theme.warning, size: 60),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '$_score',
              style: TextStyle(
                color: theme.primary,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            Text('puan', style: TextStyle(color: theme.textMuted, fontSize: 13)),
            const SizedBox(height: 14),
            Text(
              '$total sorudan $_correctCount doğru',
              style: TextStyle(color: theme.textColor, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _newBest ? 'Yeni rekor!' : 'En yüksek puanın: $_best',
              style: TextStyle(
                color: _newBest ? theme.warning : theme.textMuted,
                fontSize: 13,
                fontWeight: _newBest ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 28),
            _primaryButton(theme, 'Tekrar Oyna', _start),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Oyun Odasına Dön',
                style: TextStyle(color: theme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return PopScope(
          canPop: _phase != _Phase.playing,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmQuit(theme)) {
              _timer?.cancel();
              _advanceTimer?.cancel();
              navigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: theme.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: theme.textColor),
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Geri',
              ),
              title: Text(
                'Bilgi Yarışması',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
            body: AnimatedThemeBackground(
              child: SafeArea(
                child: switch (_phase) {
                  _Phase.loading => Center(
                      child: CircularProgressIndicator(color: theme.primary),
                    ),
                  _Phase.intro => _intro(theme),
                  _Phase.playing => _playing(theme),
                  _Phase.finished => _finished(theme),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

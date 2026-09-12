import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_background.dart';

/// Baloncuk Patlatma — klasik Bubble Shooter.
///
/// Mekanikler:
/// - Eşleştirme: Aynı renkten ≥3 balon yan yana gelince patlar ve kaybolur.
/// - Nişan Alıp Fırlatma: Alttaki fırlatıcıdan nişan alıp balonu yukarı
///   fırlatırsın; duvarlara çarptırarak banko (açılı) atış yapılabilir.
/// - Serbest Düşme: Bağlı oldukları balonlar patlayınca havada kalan
///   balonlar düşer → ekstra puan.
/// - Aşağı İnme: Her N başarısız atışta tavan bir sıra aşağı iner.
/// - Kazanma: Tüm balonları temizle. Kaybetme: Balonlar kırmızı çizgiye
///   ulaşırsa oyun biter.
class BubbleShooterGame extends StatefulWidget {
  const BubbleShooterGame({super.key});

  @override
  State<BubbleShooterGame> createState() => _BubbleShooterGameState();
}

const int _cols = 12;
const int _maxRows = 14;
const int _initialRows = 5;
const int _shotsPerDescent = 5;
const double _rowOverlap = 0.866; // sqrt(3)/2 — altıgen sıkı dizilim
const double _ballSpeed = 800.0; // px/sn
const Color _dangerColor = Color(0xFFFF5252);
const List<Color> _palette = [
  Color(0xFFFF3B5C), // kırmızı
  Color(0xFF38BDF8), // mavi
  Color(0xFF4CAF50), // yeşil
  Color(0xFFFFD700), // sarı
  Color(0xFF9D4EDD), // mor
];

class _Ball {
  Offset pos;
  Offset vel;
  int color;

  _Ball(this.pos, this.vel, this.color);
}

class _BubbleShooterGameState extends State<BubbleShooterGame>
    with TickerProviderStateMixin {
  final math.Random _rng = math.Random();
  late final Ticker _ticker;

  // Oyun alanı geometrisi (LayoutBuilder'dan hesaplanır)
  List<List<int>> _grid = [];
  int _maxRowsNow = 0;
  double _cellW = 0;
  double _rowH = 0;
  double _pad = 0;
  double _playW = 0;
  double _playH = 0;
  double _launcherY = 0;
  int _dangerRow = 0;
  double _dangerY = 0;

  // Durum
  int _level = 1;
  int _colorsInPlay = 4;
  int _score = 0;
  int _combo = 0;
  int _shotsSinceDescent = 0;
  int _highScore = 0;
  int _curColor = 1;
  int _nextColor = 2;
  bool _running = false;
  bool _gameOver = false;
  bool _won = false;

  _Ball? _flying;
  Offset? _aim;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _loadHighScore();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final hs = prefs.getInt('bubble_shooter_high_score') ?? 0;
    if (mounted) setState(() => _highScore = hs);
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bubble_shooter_high_score', _highScore);
  }

  // ---------- Geometri ----------

  void _computeGeometry() {
    _cellW = _playW / (_cols + 1);
    _rowH = _cellW * _rowOverlap;
    _pad = _cellW / 2;
    _launcherY = _playH - _cellW * 1.15;
    _maxRowsNow = math.max(
      3,
      math.min(_maxRows, ((_launcherY - _pad) / _rowH).floor()),
    );
    _dangerRow = _maxRowsNow - 1;
    _dangerY = _pad + _dangerRow * _rowH + _cellW / 2;
  }

  Offset _cellCenter(int r, int c) =>
      Offset(_pad + c * _cellW + (r.isOdd ? _cellW / 2 : 0), _pad + r * _rowH);

  Offset get _launcherPos => Offset(_playW / 2, _launcherY);

  List<(int, int)> _hexNeighbors(int r, int c) {
    final out = <(int, int)>[];
    void add(int rr, int cc) {
      if (rr >= 0 && rr < _maxRowsNow && cc >= 0 && cc < _cols) {
        out.add((rr, cc));
      }
    }

    add(r, c - 1);
    add(r, c + 1);
    if (r.isOdd) {
      add(r - 1, c);
      add(r - 1, c + 1);
      add(r + 1, c);
      add(r + 1, c + 1);
    } else {
      add(r - 1, c - 1);
      add(r - 1, c);
      add(r + 1, c - 1);
      add(r + 1, c);
    }
    return out;
  }

  // ---------- Yardımcı: tahtadaki aktif renkler ----------

  List<int> _activeColorsOnBoard() {
    final colors = <int>{};
    for (final row in _grid) {
      for (final v in row) {
        if (v != 0) colors.add(v);
      }
    }
    return colors.toList()..sort();
  }

  int _pickRandomActiveColor() {
    final active = _activeColorsOnBoard();
    if (active.isEmpty) return 1; // fallback
    return active[_rng.nextInt(active.length)];
  }

  // ---------- Oyun akışı ----------

  void _generateBoard() {
    _grid = List.generate(
      _maxRowsNow,
      (_) => List<int>.filled(_cols, 0),
    );
    final fillRows =
        math.min(_initialRows + (_level - 1), _maxRowsNow - 2);
    for (var r = 0; r < fillRows; r++) {
      for (var c = 0; c < _cols; c++) {
        _grid[r][c] = 1 + _rng.nextInt(_colorsInPlay);
      }
    }
  }

  void _startGame() {
    _computeGeometry();
    _generateBoard();
    final activeColors = _activeColorsOnBoard();
    final firstColor = activeColors.isNotEmpty
        ? activeColors[_rng.nextInt(activeColors.length)]
        : 1 + _rng.nextInt(_colorsInPlay);
    final nextColor = activeColors.isNotEmpty
        ? activeColors[_rng.nextInt(activeColors.length)]
        : 1 + _rng.nextInt(_colorsInPlay);
    setState(() {
      _level = 1;
      _colorsInPlay = 4;
      _score = 0;
      _combo = 0;
      _shotsSinceDescent = 0;
      _gameOver = false;
      _won = false;
      _flying = null;
      _aim = null;
      _curColor = firstColor;
      _nextColor = nextColor;
      _running = true;
    });
  }

  void _nextLevel() {
    _generateBoard();
    final activeColors = _activeColorsOnBoard();
    final firstColor = activeColors.isNotEmpty
        ? activeColors[_rng.nextInt(activeColors.length)]
        : 1 + _rng.nextInt(_colorsInPlay);
    final nextColor = activeColors.isNotEmpty
        ? activeColors[_rng.nextInt(activeColors.length)]
        : 1 + _rng.nextInt(_colorsInPlay);
    setState(() {
      _level++;
      if (_colorsInPlay < _palette.length) _colorsInPlay++;
      _combo = 0;
      _shotsSinceDescent = 0;
      _gameOver = false;
      _won = false;
      _flying = null;
      _aim = null;
      _curColor = firstColor;
      _nextColor = nextColor;
      _running = true;
    });
  }

  // ---------- Fırlatma & uçuş ----------

  void _onAim(Offset local) {
    if (!_running || _gameOver || _flying != null) return;
    setState(() => _aim = local);
  }

  void _fire(Offset target) {
    if (!_running || _gameOver || _flying != null) return;
    final launcher = _launcherPos;
    var dir = target - launcher;
    if (dir.distance < _cellW) return;
    // Aşağı nişan alınamaz (yalnız yukarı atış)
    if (dir.dy > 0) return;
    dir = dir / dir.distance;
    setState(() {
      _flying = _Ball(launcher, dir * _ballSpeed, _curColor);
      _aim = null;
      _curColor = _nextColor;
      // Sıradaki renk: tahtada hala kalan renklerden biri
      _nextColor = _pickRandomActiveColor();
    });
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 60);
    _lastTick = elapsed;
    if (!_running || _gameOver || _flying == null) return;
    if (dt <= 0) return;
    setState(() => _stepFlight(dt));
  }

  void _stepFlight(double dt) {
    final b = _flying;
    if (b == null) return;
    b.pos += b.vel * dt;
    final r = _cellW / 2;

    // Sol/sağ duvara sekme (banko atış)
    if (b.pos.dx < r) {
      b.pos = Offset(r, b.pos.dy);
      b.vel = Offset(-b.vel.dx, b.vel.dy);
    } else if (b.pos.dx > _playW - r) {
      b.pos = Offset(_playW - r, b.pos.dy);
      b.vel = Offset(-b.vel.dx, b.vel.dy);
    }

    // Üst duvara ulaşınca en üst satıra yerleştir
    if (b.pos.dy <= _pad) {
      _snapAndPlace();
      return;
    }

    // Mevcut balonlara çarpma kontrolü
    for (var row = 0; row < _maxRowsNow; row++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[row][c] != 0) {
          if ((b.pos - _cellCenter(row, c)).distance < _cellW - 1) {
            _snapAndPlace();
            return;
          }
        }
      }
    }
  }

  void _snapAndPlace() {
    final b = _flying;
    if (b == null) return;
    _flying = null;
    // Temas noktasına en yakın boş hücreyi bul
    var bestR = -1;
    var bestC = -1;
    var bestD = double.infinity;
    for (var row = 0; row < _maxRowsNow; row++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[row][c] == 0) {
          final d = (b.pos - _cellCenter(row, c)).distance;
          if (d < bestD) {
            bestD = d;
            bestR = row;
            bestC = c;
          }
        }
      }
    }
    if (bestR < 0) return;
    _grid[bestR][bestC] = b.color;
    _resolveMatch(bestR, bestC);
  }

  // ---------- Eşleştirme & düşme ----------

  void _resolveMatch(int r, int c) {
    final color = _grid[r][c];
    final cluster = _floodFill(r, c, color);
    if (cluster.length >= 3) {
      _combo++;
      for (final p in cluster) {
        _grid[p.r][p.c] = 0;
      }
      _score += cluster.length * 10 * _combo;
      _shotsSinceDescent = 0;

      // Serbest düşen (bağlantısı kopan) balonlar
      final floating = _findFloating();
      if (floating.isNotEmpty) {
        for (final p in floating) {
          _grid[p.r][p.c] = 0;
        }
        _score += floating.length * 20;
      }

      if (_isEmpty()) {
        _endGame(true);
      }
    } else {
      _combo = 0;
      _shotsSinceDescent++;
      if (_shotsSinceDescent >= _shotsPerDescent) {
        _shotsSinceDescent = 0;
        _descend();
      }
    }
  }

  List<({int r, int c})> _floodFill(int r0, int c0, int color) {
    final seen = <String>{};
    final queue = <(int, int)>[(r0, c0)];
    final res = <({int r, int c})>[];
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeLast();
      final key = '$r,$c';
      if (seen.contains(key)) continue;
      if (_grid[r][c] != color) continue;
      seen.add(key);
      res.add((r: r, c: c));
      for (final (nr, nc) in _hexNeighbors(r, c)) {
        if (!seen.contains('$nr,$nc')) queue.add((nr, nc));
      }
    }
    return res;
  }

  List<({int r, int c})> _findFloating() {
    final seen = <String>{};
    final queue = <(int, int)>[];
    for (var c = 0; c < _cols; c++) {
      if (_grid[0][c] != 0) {
        queue.add((0, c));
        seen.add('0,$c');
      }
    }
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeLast();
      for (final (nr, nc) in _hexNeighbors(r, c)) {
        final key = '$nr,$nc';
        if (!seen.contains(key) && _grid[nr][nc] != 0) {
          seen.add(key);
          queue.add((nr, nc));
        }
      }
    }
    final floating = <({int r, int c})>[];
    for (var r = 0; r < _maxRowsNow; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != 0 && !seen.contains('$r,$c')) {
          floating.add((r: r, c: c));
        }
      }
    }
    return floating;
  }

  void _descend() {
    _grid.insert(0, List<int>.filled(_cols, 0));
    if (_grid.length > _maxRowsNow) _grid.removeLast();
    // En alttaki dolu satır kırmızı çizgiye ulaştı mı?
    for (var rr = _maxRowsNow - 1; rr >= 0; rr--) {
      if (_grid[rr].any((v) => v != 0)) {
        if (rr >= _dangerRow) _endGame(false);
        return;
      }
    }
  }

  bool _isEmpty() {
    for (final row in _grid) {
      for (final v in row) {
        if (v != 0) return false;
      }
    }
    return true;
  }

  Future<void> _endGame(bool win) async {
    _running = false;
    _gameOver = true;
    _won = win;
    if (_score > _highScore) {
      _highScore = _score;
      await _saveHighScore();
    }
    if (mounted) setState(() {});
    _showResultDialog();
  }

  // ---------- UI ----------

  void _showResultDialog() {
    final theme = themeNotifier.value;
    final isRecord = _score >= _highScore && _score > 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_won ? const Color(0xFF4CAF50) : theme.primary)
                      .withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (_won ? const Color(0xFF4CAF50) : theme.primary)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  _won
                      ? Icons.emoji_events_rounded
                      : (isRecord
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_dissatisfied_rounded),
                  color: _won ? const Color(0xFF4CAF50) : theme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _won ? 'Seviyeyi Geçtin! 🎉' : 'Oyun Bitti! 😵',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _scoreRow(theme, 'Skor', '$_score'),
              _scoreRow(theme, 'Seviye', '$_level'),
              if (isRecord && !_won)
                _scoreRow(theme, 'Yeni Rekor!', '$_highScore'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Çık'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textMuted,
                        side: BorderSide(
                          color: theme.textMuted.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _won ? _nextLevel() : _startGame();
                      },
                      icon: Icon(
                        _won ? Icons.arrow_upward_rounded : Icons.refresh_rounded,
                        size: 18,
                      ),
                      label: Text(_won ? 'Sonraki Seviye' : 'Tekrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRow(AppTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.textMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
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
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Baloncuk Patlatma',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            centerTitle: true,
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _buildHud(theme),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? theme.surface.withValues(alpha: 0.5)
                                : const Color(0xFFE0F7FA),
                            border: Border.all(
                              color: theme.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              _playW = constraints.maxWidth;
                              _playH = constraints.maxHeight;
                              _computeGeometry();
                              return Stack(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanDown: (d) => _onAim(d.localPosition),
                                    onPanUpdate: (d) => _onAim(d.localPosition),
                                    onPanEnd: (_) {
                                      if (_aim != null) _fire(_aim!);
                                    },
                                    onTapUp: (d) => _fire(d.localPosition),
                                    child: CustomPaint(
                                      size: Size(_playW, _playH),
                                      painter: _ShooterPainter(
                                        grid: _grid,
                                        maxRows: _maxRowsNow,
                                        cols: _cols,
                                        cellW: _cellW,
                                        rowH: _rowH,
                                        pad: _pad,
                                        playW: _playW,
                                        playH: _playH,
                                        launcherPos: _launcherPos,
                                        dangerY: _dangerY,
                                        flying: _flying,
                                        curColor: _curColor,
                                        nextColor: _nextColor,
                                        aim: _aim,
                                        active: _running && !_gameOver,
                                        guideColor: theme.textColor
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                  if (!_running && !_gameOver)
                                    _buildStartOverlay(theme),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHud(AppTheme theme) {
    final shotsLeft = _shotsPerDescent - _shotsSinceDescent;
    return Row(
      children: [
        Expanded(
          child: _hudChip(
            theme,
            Icons.stars_rounded,
            'Skor',
            '$_score',
            theme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _hudChip(
            theme,
            Icons.flag_rounded,
            'Seviye',
            '$_level',
            const Color(0xFFFF9800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _hudChip(
            theme,
            Icons.keyboard_double_arrow_down_rounded,
            'İnme',
            '$shotsLeft/$_shotsPerDescent',
            shotsLeft <= 2 ? _dangerColor : theme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _hudChip(
    AppTheme theme,
    IconData icon,
    String label,
    String value,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartOverlay(AppTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bubble_chart_rounded,
                  color: Color(0xFF00ACC1), size: 48),
              const SizedBox(height: 12),
              Text(
                'Balonları Fırlat!',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Nişan al → fırlat. Aynı renkten 3+ balon patlar.\n'
                'Kopan balonlar düşer, bonus puan!\n'
                'Her 5 boş atışta tavan iner ⬇️\n'
                'Hepsini temizle, seviyeyi geç!',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: theme.textMuted, fontSize: 13, height: 1.5),
              ),
              if (_highScore > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Rekor: $_highScore',
                  style: TextStyle(
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Başla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShooterPainter extends CustomPainter {
  final List<List<int>> grid;
  final int maxRows;
  final int cols;
  final double cellW;
  final double rowH;
  final double pad;
  final double playW;
  final double playH;
  final Offset launcherPos;
  final double dangerY;
  final _Ball? flying;
  final int curColor;
  final int nextColor;
  final Offset? aim;
  final bool active;
  final Color guideColor;

  const _ShooterPainter({
    required this.grid,
    required this.maxRows,
    required this.cols,
    required this.cellW,
    required this.rowH,
    required this.pad,
    required this.playW,
    required this.playH,
    required this.launcherPos,
    required this.dangerY,
    required this.flying,
    required this.curColor,
    required this.nextColor,
    required this.aim,
    required this.active,
    required this.guideColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Mevcut balonlar
    for (var r = 0; r < maxRows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = grid[r][c];
        if (v == 0) continue;
        final center = Offset(
          pad + c * cellW + (r.isOdd ? cellW / 2 : 0),
          pad + r * rowH,
        );
        _paintBubble(canvas, center, cellW / 2 - 1, _palette[v - 1]);
      }
    }

    if (!active) return;

    // Kırmızı tehlike çizgisi + yumuşak uyarı bölgesi
    final dangerZone = Paint()
      ..color = _dangerColor.withValues(alpha: 0.08);
    canvas.drawRect(
      Rect.fromLTRB(0, dangerY, playW, playH),
      dangerZone,
    );
    final dangerPaint = Paint()
      ..color = _dangerColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(
      canvas,
      Offset(6, dangerY),
      Offset(playW - 6, dangerY),
      dangerPaint,
    );

    // Fırlatıcı + sıradaki balon
    _paintLauncher(canvas);

    // Nişan rehberi (kesikli çizgi)
    if (aim != null && flying == null) {
      var dir = aim! - launcherPos;
      if (dir.distance > 1 && dir.dy < 0) {
        dir = dir / dir.distance;
        final end = launcherPos + dir * (playH * 2);
        final guidePaint = Paint()
          ..color = guideColor
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        _drawDashedLine(canvas, launcherPos, end, guidePaint);
      }
    }

    // Uçan balon
    final ball = flying;
    if (ball != null) {
      _paintBubble(canvas, ball.pos, cellW / 2 - 1, _palette[ball.color - 1]);
    }
  }

  void _paintLauncher(Canvas canvas) {
    // Taban kapsülü
    final baseRect = Rect.fromCenter(
      center: launcherPos + Offset(0, cellW * 0.32),
      width: cellW * 2.7,
      height: cellW * 0.8,
    );
    final basePaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, Radius.circular(cellW * 0.4)),
      basePaint,
    );

    // Sıradaki balon (küçük, yanda)
    final nextPos = launcherPos + Offset(cellW * 0.95, 0);
    _paintBubble(canvas, nextPos, cellW * 0.32, _palette[nextColor - 1]);

    // Elindeki balon
    _paintBubble(canvas, launcherPos, cellW / 2 - 1, _palette[curColor - 1]);
  }

  void _paintBubble(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.9), color],
        stops: const [0.0, 0.55],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);

    // Parlama noktası
    canvas.drawCircle(
      center + Offset(-radius * 0.32, -radius * 0.32),
      radius * 0.2,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );

    // İnce kenar
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
  ) {
    final path = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy);
    final metric = path.computeMetrics().first;
    const dash = 9.0;
    const gap = 7.0;
    var dist = 0.0;
    while (dist < metric.length) {
      final end = math.min(dist + dash, metric.length);
      final t1 = metric.getTangentForOffset(dist);
      final t2 = metric.getTangentForOffset(end);
      if (t1 != null && t2 != null) {
        canvas.drawLine(t1.position, t2.position, paint);
      }
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ShooterPainter old) => true;
}

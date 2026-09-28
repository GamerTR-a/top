import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_background.dart';

/// Klasik Tetris — 7 tetromino, döndürme, satır temizleme, skor & seviye.
class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

const int _cols = 10;
const int _rows = 20;

const List<List<List<int>>> _shapes = [
  [[1, 1, 1, 1]], // I
  [[1, 1], [1, 1]], // O
  [[0, 1, 0], [1, 1, 1]], // T
  [[0, 1, 1], [1, 1, 0]], // S
  [[1, 1, 0], [0, 1, 1]], // Z
  [[1, 0, 0], [1, 1, 1]], // J
  [[0, 0, 1], [1, 1, 1]], // L
];

const List<Color> _pieceColors = [
  Color(0xFF00E5FF), // I
  Color(0xFFFFD700), // O
  Color(0xFFB388FF), // T
  Color(0xFF4CAF50), // S
  Color(0xFFFF5252), // Z
  Color(0xFF448AFF), // J
  Color(0xFFFF9800), // L
];

class _Piece {
  final int shapeIndex;
  final int rotation;
  final int row;
  final int col;

  const _Piece(this.shapeIndex, this.rotation, this.row, this.col);
}

class _TetrisGameState extends State<TetrisGame> {
  late final List<List<int?>> _grid;
  final Random _rng = Random();

  Timer? _dropTimer;
  _Piece _current = const _Piece(0, 0, 0, 3);
  int _nextShape = 0;
  int _score = 0;
  int _lines = 0;
  int _level = 1;
  int _gridVersion = 0;
  bool _paused = false;
  bool _gameOver = false;
  bool _started = false;

  List<List<int?>> _emptyGrid() =>
      List.generate(_rows, (_) => List<int?>.filled(_cols, null));

  @override
  void initState() {
    super.initState();
    _grid = _emptyGrid();
  }

  @override
  void dispose() {
    _dropTimer?.cancel();
    super.dispose();
  }

  List<List<int>> _matrix(int shape, int rotation) {
    var m = _shapes[shape];
    for (int r = 0; r < rotation % 4; r++) {
      m = _rotateMatrix(m);
    }
    return m;
  }

  List<List<int>> _rotateMatrix(List<List<int>> m) {
    final rows = m.length;
    final cols = m[0].length;
    final res = List.generate(cols, (_) => List<int>.filled(rows, 0));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        res[c][rows - 1 - r] = m[r][c];
      }
    }
    return res;
  }

  bool _collides(int shape, int rotation, int row, int col) {
    final m = _matrix(shape, rotation);
    for (int r = 0; r < m.length; r++) {
      for (int c = 0; c < m[r].length; c++) {
        if (m[r][c] == 0) continue;
        final rr = row + r;
        final cc = col + c;
        if (cc < 0 || cc >= _cols || rr >= _rows) return true;
        if (rr >= 0 && _grid[rr][cc] != null) return true;
      }
    }
    return false;
  }

  int _ghostRow() {
    var r = _current.row;
    while (!_collides(
        _current.shapeIndex, _current.rotation, r + 1, _current.col)) {
      r++;
    }
    return r;
  }

  void _startGame() {
    setState(() {
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          _grid[r][c] = null;
        }
      }
      _score = 0;
      _lines = 0;
      _level = 1;
      _gridVersion++;
      _paused = false;
      _gameOver = false;
      _started = true;
    });
    _nextShape = _rng.nextInt(7);
    _spawnPiece();
    _startTimer();
  }

  void _startTimer() {
    _dropTimer?.cancel();
    _dropTimer = Timer.periodic(
      Duration(milliseconds: _dropInterval()),
      (_) => _tick(),
    );
  }

  int _dropInterval() => max(100, 800 - (_level - 1) * 70);

  void _spawnPiece() {
    final shape = _nextShape;
    _nextShape = _rng.nextInt(7);
    final m = _matrix(shape, 0);
    final col = (_cols - m[0].length) ~/ 2;
    _current = _Piece(shape, 0, 0, col);
    if (_collides(shape, 0, _current.row, _current.col)) {
      _gameOver = true;
      _dropTimer?.cancel();
      // Tahtanın son halini çizdikten sonra diyaloğu göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOver();
      });
    }
  }

  void _tick() {
    if (_paused || _gameOver) return;
    if (!_collides(
        _current.shapeIndex, _current.rotation, _current.row + 1, _current.col)) {
      setState(() => _current =
          _Piece(_current.shapeIndex, _current.rotation, _current.row + 1, _current.col));
    } else {
      _lock();
    }
  }

  void _lock() {
    final m = _matrix(_current.shapeIndex, _current.rotation);
    for (int r = 0; r < m.length; r++) {
      for (int c = 0; c < m[r].length; c++) {
        if (m[r][c] == 0) continue;
        final rr = _current.row + r;
        final cc = _current.col + c;
        if (rr >= 0 && rr < _rows) {
          _grid[rr][cc] = _current.shapeIndex;
        }
      }
    }
    _gridVersion++;
    _clearLines();
    _spawnPiece();
    if (!_gameOver) _startTimer();
  }

  void _clearLines() {
    int cleared = 0;
    for (int r = _rows - 1; r >= 0; r--) {
      if (_grid[r].every((c) => c != null)) {
        _grid.removeAt(r);
        _grid.insert(0, List<int?>.filled(_cols, null));
        cleared++;
        r++; // aynı satırı tekrar kontrol et
      }
    }
    if (cleared > 0) {
      const points = [0, 100, 300, 500, 800];
      _lines += cleared;
      _score += points[cleared] * _level;
      _level = _lines ~/ 10 + 1;
    }
  }

  void _moveLeft() {
    if (_paused || _gameOver) return;
    if (!_collides(
        _current.shapeIndex, _current.rotation, _current.row, _current.col - 1)) {
      setState(() => _current =
          _Piece(_current.shapeIndex, _current.rotation, _current.row, _current.col - 1));
    }
  }

  void _moveRight() {
    if (_paused || _gameOver) return;
    if (!_collides(
        _current.shapeIndex, _current.rotation, _current.row, _current.col + 1)) {
      setState(() => _current =
          _Piece(_current.shapeIndex, _current.rotation, _current.row, _current.col + 1));
    }
  }

  void _rotate() {
    if (_paused || _gameOver) return;
    final newRot = (_current.rotation + 1) % 4;
    // Basit duvar kick: doğrudan, sol, sağ
    for (final kick in [0, -1, 1, -2, 2]) {
      if (!_collides(_current.shapeIndex, newRot, _current.row, _current.col + kick)) {
        setState(() => _current =
            _Piece(_current.shapeIndex, newRot, _current.row, _current.col + kick));
        return;
      }
    }
  }

  void _softDrop() {
    if (_paused || _gameOver) return;
    if (!_collides(
        _current.shapeIndex, _current.rotation, _current.row + 1, _current.col)) {
      setState(() => _current =
          _Piece(_current.shapeIndex, _current.rotation, _current.row + 1, _current.col));
      _score += 1;
    } else {
      _lock();
    }
  }

  void _hardDrop() {
    if (_paused || _gameOver) return;
    final target = _ghostRow();
    _score += (target - _current.row) * 2;
    setState(() =>
        _current = _Piece(_current.shapeIndex, _current.rotation, target, _current.col));
    _lock();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _dropTimer?.cancel();
    } else {
      _startTimer();
    }
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
              tooltip: 'Geri',
            ),
            title: Text(
              'Tetris',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            centerTitle: true,
            actions: [
              if (_started && !_gameOver)
                IconButton(
                  icon: Icon(
                    _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: theme.textColor,
                  ),
                  tooltip: _paused ? 'Devam Et' : 'Duraklat',
                  onPressed: _togglePause,
                ),
            ],
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: _started
                  ? _buildGame(theme)
                  : _buildIntro(theme),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntro(AppTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, color: _pieceColors[0], size: 64),
            const SizedBox(height: 14),
            Text(
              'Tetris',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Blokları istifle, satırları temizle.\nSeviye arttıkça hızlanır! ⚡',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Başla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame(AppTheme theme) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sol panel: skor / seviye / satır
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: _panelDecoration(theme),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stat(theme, 'Skor', '$_score', theme.primary),
                        const SizedBox(height: 10),
                        _stat(theme, 'Seviye', '$_level', const Color(0xFFFFD700)),
                        const SizedBox(height: 10),
                        _stat(theme, 'Satır', '$_lines', const Color(0xFF4CAF50)),
                        const Spacer(),
                        Text(
                          'SONRAKİ',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(child: _NextPiecePreview(shape: _nextShape)),
                      ],
                    ),
                  ),
                ),
                // Oyun tahtası — her cihazda 10:20 oranını korur (kırpılma/boşluk yok)
                Expanded(
                  flex: 2,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _cols / _rows,
                      child: Container(
                        decoration: _boardDecoration(theme),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _TetrisPainter(
                              grid: _grid,
                              current: _current,
                              ghostRow: _ghostRow(),
                              colors: _pieceColors,
                              isDark: theme.isDark,
                              version: _gridVersion,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Kontroller
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: _panelDecoration(theme),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ctrlButton(theme, Icons.arrow_back_rounded, _moveLeft),
                    _ctrlButton(theme, Icons.rotate_90_degrees_cw_rounded, _rotate),
                    _ctrlButton(theme, Icons.arrow_forward_rounded, _moveRight),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ctrlButton(theme, Icons.arrow_downward_rounded, _softDrop),
                    _ctrlButton(theme, Icons.south_west_rounded, _hardDrop),
                    _ctrlButton(
                      theme,
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      _togglePause,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration(AppTheme theme) => BoxDecoration(
        color: theme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
      );

  BoxDecoration _boardDecoration(AppTheme theme) => BoxDecoration(
        color: theme.isDark ? const Color(0xFF05070F) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );

  Widget _stat(AppTheme theme, String label, String value, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _ctrlButton(AppTheme theme, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 46,
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: theme.primary, size: 26),
      ),
    );
  }

  void _showGameOver() {
    final theme = themeNotifier.value;
    if (!mounted) return;
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
                Icon(Icons.sports_esports_rounded, color: theme.error, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Oyun Bitti!',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Skor: $_score\nSeviye: $_level | Satır: $_lines',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Çık'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textMuted,
                          side: BorderSide(color: theme.textMuted.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startGame();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Tekrar'),
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
}

class _TetrisPainter extends CustomPainter {
  final List<List<int?>> grid;
  final _Piece current;
  final int ghostRow;
  final List<Color> colors;
  final bool isDark;
  final int version;

  _TetrisPainter({
    required this.grid,
    required this.current,
    required this.ghostRow,
    required this.colors,
    required this.isDark,
    required this.version,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _cols;
    final boardHeight = cell * _rows;

    // Grid çizgileri
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int c = 0; c <= _cols; c++) {
      canvas.drawLine(
        Offset(c * cell, 0),
        Offset(c * cell, boardHeight),
        linePaint,
      );
    }
    for (int r = 0; r <= _rows; r++) {
      canvas.drawLine(
        Offset(0, r * cell),
        Offset(size.width, r * cell),
        linePaint,
      );
    }

    // Yerleşmiş bloklar
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final idx = grid[r][c];
        if (idx == null) continue;
        _drawCell(canvas, c, r, cell, colors[idx], 1.0);
      }
    }

    // Hayalet parça (iniş noktası)
    final ghostMat = _shapeMatrix(current.shapeIndex, current.rotation);
    for (int r = 0; r < ghostMat.length; r++) {
      for (int c = 0; c < ghostMat[r].length; c++) {
        if (ghostMat[r][c] == 0) continue;
        final rr = ghostRow + r;
        if (rr < 0) continue;
        _drawCell(
          canvas,
          current.col + c,
          rr,
          cell,
          colors[current.shapeIndex],
          0.22,
        );
      }
    }

    // Aktif parça
    final mat = _shapeMatrix(current.shapeIndex, current.rotation);
    for (int r = 0; r < mat.length; r++) {
      for (int c = 0; c < mat[r].length; c++) {
        if (mat[r][c] == 0) continue;
        final rr = current.row + r;
        final cc = current.col + c;
        if (rr < 0) continue;
        _drawCell(canvas, cc, rr, cell, colors[current.shapeIndex], 1.0);
      }
    }
  }

  List<List<int>> _shapeMatrix(int shape, int rotation) {
    var m = _shapes[shape];
    for (int r = 0; r < rotation % 4; r++) {
      final rows = m.length;
      final cols = m[0].length;
      final res = List.generate(cols, (_) => List<int>.filled(rows, 0));
      for (int rr = 0; rr < rows; rr++) {
        for (int cc = 0; cc < cols; cc++) {
          res[cc][rows - 1 - rr] = m[rr][cc];
        }
      }
      m = res;
    }
    return m;
  }

  void _drawCell(Canvas canvas, int c, int r, double cell, Color color, double alpha) {
    final rect = Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18));
    final paint = Paint()..color = color.withValues(alpha: alpha);
    canvas.drawRRect(rrect, paint);
    // Parlama efekti (üst kenar)
    if (alpha > 0.5) {
      final gloss = Paint()
        ..color = Colors.white.withValues(alpha: 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cell + 2, r * cell + 2, cell - 4, cell * 0.35),
          Radius.circular(cell * 0.12),
        ),
        gloss,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TetrisPainter old) =>
      old.version != version ||
      old.current != current ||
      old.ghostRow != ghostRow ||
      old.isDark != isDark;
}

class _NextPiecePreview extends StatelessWidget {
  final int shape;
  const _NextPiecePreview({required this.shape});

  @override
  Widget build(BuildContext context) {
    final mat = _shapes[shape];
    final color = _pieceColors[shape];
    final cell = 16.0;
    return Container(
      width: cell * 4,
      height: cell * 4,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int r = 0; r < mat.length; r++)
            for (int c = 0; c < mat[r].length; c++)
              if (mat[r][c] == 1)
                Positioned(
                  left: (c + (4 - mat[0].length) / 2) * cell,
                  top: (r + (4 - mat.length) / 2) * cell,
                  child: Container(
                    width: cell - 2,
                    height: cell - 2,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_background.dart';

/// Sudoku — 9×9 mantık bulmacası. Üç zorluk, hata vurgusu, zamanlayıcı.
class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key});

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _Puzzle {
  final String name;
  final List<List<int>> solution;
  final List<List<int>> puzzle; // 0 = boş
  const _Puzzle({
    required this.name,
    required this.solution,
    required this.puzzle,
  });
}

// Üç doğrulanmış bulmaca: kolay klasik + ondan türetilmiş orta ve zor.
const List<_Puzzle> _puzzles = [
  _Puzzle(
    name: 'Kolay',
    solution: [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
    puzzle: [
      [5, 3, 0, 0, 7, 0, 0, 0, 0],
      [6, 0, 0, 1, 9, 5, 0, 0, 0],
      [0, 9, 8, 0, 0, 0, 0, 6, 0],
      [8, 0, 0, 0, 6, 0, 0, 0, 3],
      [4, 0, 0, 8, 0, 3, 0, 0, 1],
      [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 6, 0, 0, 0, 0, 2, 8, 0],
      [0, 0, 0, 4, 1, 9, 0, 0, 5],
      [0, 0, 0, 0, 8, 0, 0, 7, 9],
    ],
  ),
  _Puzzle(
    name: 'Orta',
    solution: [
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
    ],
    puzzle: [
      [0, 4, 0, 2, 8, 0, 1, 0, 0],
      [2, 0, 0, 0, 1, 0, 6, 0, 0],
      [9, 6, 0, 5, 0, 7, 0, 8, 4],
      [0, 0, 3, 0, 2, 0, 8, 5, 0],
      [4, 0, 6, 0, 0, 0, 7, 0, 1],
      [0, 5, 9, 0, 6, 0, 0, 0, 3],
      [1, 0, 8, 3, 0, 2, 0, 6, 7],
      [0, 7, 2, 0, 9, 0, 0, 0, 8],
      [0, 0, 4, 0, 8, 0, 9, 0, 0],
    ],
  ),
  _Puzzle(
    name: 'Zor',
    solution: [
      [2, 1, 9, 8, 7, 6, 4, 3, 5],
      [8, 4, 3, 5, 9, 1, 2, 7, 6],
      [7, 6, 5, 2, 4, 3, 8, 9, 1],
      [3, 2, 4, 1, 6, 7, 9, 5, 8],
      [1, 9, 7, 3, 5, 8, 6, 2, 4],
      [6, 5, 8, 4, 2, 9, 3, 1, 7],
      [4, 8, 2, 7, 3, 5, 1, 6, 9],
      [5, 3, 6, 9, 1, 4, 7, 8, 2],
      [9, 7, 1, 6, 8, 2, 5, 4, 3],
    ],
    puzzle: [
      [0, 1, 0, 0, 7, 0, 4, 0, 0],
      [8, 0, 0, 0, 0, 0, 0, 7, 6],
      [0, 6, 5, 0, 4, 0, 0, 0, 1],
      [0, 0, 4, 0, 0, 7, 0, 5, 0],
      [0, 0, 0, 3, 5, 8, 0, 0, 0],
      [0, 5, 0, 4, 0, 0, 3, 0, 0],
      [4, 0, 0, 0, 3, 0, 1, 6, 0],
      [5, 3, 0, 0, 0, 0, 0, 0, 2],
      [0, 0, 1, 6, 0, 0, 0, 4, 0],
    ],
  ),
];

class _SudokuGameState extends State<SudokuGame> {
  late List<List<int>> _grid;
  late List<List<bool>> _given;
  late _Puzzle _current;

  int _puzzleIndex = 0;
  int? _selRow;
  int? _selCol;
  bool _won = false;

  final Stopwatch _watch = Stopwatch();
  Timer? _timerTick;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _loadPuzzle(0);
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    _watch.stop();
    super.dispose();
  }

  void _loadPuzzle(int index) {
    _current = _puzzles[index];
    _grid = _current.puzzle
        .map((row) => List<int>.from(row))
        .toList();
    _given = _current.puzzle
        .map((row) => row.map((v) => v != 0).toList())
        .toList();
    _puzzleIndex = index;
    _won = false;
    _elapsed = 0;
    _watch
      ..reset()
      ..start();
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _watch.elapsed.inSeconds);
    });
  }

  void _select(int r, int c) {
    setState(() {
      _selRow = r;
      _selCol = c;
    });
  }

  void _input(int value) {
    if (_won || _selRow == null || _selCol == null) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_given[r][c]) return;
    setState(() => _grid[r][c] = value);
    if (_isComplete()) _handleWin();
  }

  void _erase() {
    if (_won || _selRow == null || _selCol == null) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_given[r][c]) return;
    setState(() => _grid[r][c] = 0);
  }

  bool _isComplete() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_grid[r][c] != _current.solution[r][c]) return false;
      }
    }
    return true;
  }

  /// (r,c) hücresindeki değer satır/sütun/3×3 kutusunda çakışıyor mu?
  bool _hasConflict(int r, int c) {
    final v = _grid[r][c];
    if (v == 0) return false;
    for (int i = 0; i < 9; i++) {
      if (i != c && _grid[r][i] == v) return true;
      if (i != r && _grid[i][c] == v) return true;
    }
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int rr = br; rr < br + 3; rr++) {
      for (int cc = bc; cc < bc + 3; cc++) {
        if ((rr != r || cc != c) && _grid[rr][cc] == v) return true;
      }
    }
    return false;
  }

  bool _isPeer(int r, int c) {
    if (_selRow == null || _selCol == null) return false;
    if (r == _selRow && c == _selCol) return false;
    if (r == _selRow || c == _selCol) return true;
    return r ~/ 3 == _selRow! ~/ 3 && c ~/ 3 == _selCol! ~/ 3;
  }

  void _handleWin() {
    _watch.stop();
    _timerTick?.cancel();
    setState(() => _won = true);
    final theme = themeNotifier.value;
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
              const Icon(Icons.celebration_rounded,
                  color: Color(0xFFFFD700), size: 52),
              const SizedBox(height: 12),
              Text(
                'Tebrikler! 🎉',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sudokuyu ${_formatTime(_elapsed)} sürede çözdün.',
                style: TextStyle(color: theme.textMuted, fontSize: 14),
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
                        side: BorderSide(
                            color: theme.textMuted.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadPuzzle((_puzzleIndex + 1) % _puzzles.length);
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Sonraki'),
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

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
              'Sudoku',
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHud(theme),
                    const SizedBox(height: 14),
                    _buildBoard(theme),
                    const SizedBox(height: 14),
                    _buildNumberPad(theme),
                    const SizedBox(height: 12),
                    _buildActions(theme),
                    const SizedBox(height: 8),
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
    return Row(
      children: [
        _chip(theme, Icons.emoji_events_rounded, 'Zorluk',
            _current.name, const Color(0xFFFFD700)),
        const SizedBox(width: 10),
        _chip(theme, Icons.timer_rounded, 'Süre', _formatTime(_elapsed),
            theme.secondary),
        const SizedBox(width: 10),
        _chip(theme, Icons.restart_alt_rounded, 'Yeniden', 'Dokun',
            theme.primary,
            onTap: _restart),
      ],
    );
  }

  Widget _chip(
    AppTheme theme,
    IconData icon,
    String label,
    String value,
    Color accent, {
    VoidCallback? onTap,
  }) {
    final inner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(color: theme.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return Expanded(child: inner);
    return Expanded(
      child: GestureDetector(onTap: onTap, child: inner),
    );
  }

  Widget _buildBoard(AppTheme theme) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDark ? const Color(0xFF0B1020) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.primary.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: theme.primary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int r = 0; r < 9; r++)
              Expanded(
                child: Row(
                  children: [
                    for (int c = 0; c < 9; c++)
                      Expanded(
                        child: _Cell(
                          value: _grid[r][c],
                          isGiven: _given[r][c],
                          isSelected: _selRow == r && _selCol == c,
                          isPeer: _isPeer(r, c),
                          isConflict: _hasConflict(r, c),
                          isDark: theme.isDark,
                          accent: theme.primary,
                          // 3×3 kutu sınırlarında kalın çizgi
                          thickRight: c % 3 == 2 && c != 8,
                          thickBottom: r % 3 == 2 && r != 8,
                          onTap: () => _select(r, c),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(AppTheme theme) {
    return Column(
      children: [
        Row(
          children: [
            for (int n = 1; n <= 5; n++) _numKey(theme, n),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int n = 6; n <= 9; n++) _numKey(theme, n),
            _numKey(theme, 0, erase: true),
          ],
        ),
      ],
    );
  }

  Widget _numKey(AppTheme theme, int value, {bool erase = false}) {
    final enabled = _selRow != null && _selCol != null;
    return Expanded(
      child: GestureDetector(
        onTap: () => erase ? _erase() : _input(value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? theme.primary.withValues(alpha: 0.12)
                : theme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primary.withValues(alpha: enabled ? 0.4 : 0.15),
            ),
          ),
          child: erase
              ? Icon(Icons.backspace_outlined, color: theme.primary, size: 22)
              : Text(
                  '$value',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildActions(AppTheme theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Baştan Başla'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.textMuted,
              side: BorderSide(color: theme.textMuted.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.fact_check_rounded, size: 18),
            label: const Text('Kontrol Et'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primary,
              side: BorderSide(color: theme.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _restart() {
    setState(() {
      _grid = _current.puzzle
          .map((row) => List<int>.from(row))
          .toList();
      _won = false;
      _elapsed = 0;
      _selRow = null;
      _selCol = null;
      _watch
        ..reset()
        ..start();
    });
    // Kazanınca durdurulan zamanlayıcıyı yeniden başlat
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _watch.elapsed.inSeconds);
    });
  }

  void _check() {
    if (_won) return;
    final theme = themeNotifier.value;
    if (_isComplete()) {
      _handleWin();
      return;
    }
    // Boş hücre var mı?
    bool hasEmpty = false;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_grid[r][c] == 0) hasEmpty = true;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasEmpty
              ? 'Henüz tamamlanmadı — boş hücreler var.'
              : 'Bazı hücreler hatalı, kırmızı işaretli olanları kontrol et.',
        ),
        backgroundColor: hasEmpty ? theme.warning : theme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int value;
  final bool isGiven;
  final bool isSelected;
  final bool isPeer;
  final bool isConflict;
  final bool isDark;
  final Color accent;
  final bool thickRight;
  final bool thickBottom;
  final VoidCallback onTap;

  const _Cell({
    required this.value,
    required this.isGiven,
    required this.isSelected,
    required this.isPeer,
    required this.isConflict,
    required this.isDark,
    required this.accent,
    required this.thickRight,
    required this.thickBottom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? bg;
    if (isSelected) {
      bg = accent.withValues(alpha: 0.35);
    } else if (isConflict) {
      bg = const Color(0xFFFF5252).withValues(alpha: 0.3);
    } else if (isPeer) {
      bg = accent.withValues(alpha: 0.1);
    } else {
      bg = Colors.transparent;
    }

    Color numberColor;
    if (isConflict) {
      numberColor = const Color(0xFFFF5252);
    } else if (isGiven) {
      numberColor = isDark ? Colors.white : const Color(0xFF0F172A);
    } else {
      numberColor = accent;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(
              color: thickRight
                  ? accent.withValues(alpha: 0.7)
                  : (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
              width: thickRight ? 2 : 0.5,
            ),
            bottom: BorderSide(
              color: thickBottom
                  ? accent.withValues(alpha: 0.7)
                  : (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
              width: thickBottom ? 2 : 0.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: value == 0
            ? null
            : Text(
                '$value',
                style: TextStyle(
                  color: numberColor,
                  fontSize: 18,
                  fontWeight: isGiven ? FontWeight.bold : FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

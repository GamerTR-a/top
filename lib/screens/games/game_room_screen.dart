import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_background.dart';
import 'bubble_shooter_game.dart';
import 'sudoku_game.dart';
import 'tetris_game.dart';

/// NEV + → Oyun Odası launcher'ı.
/// Üç mini oyunu şık kartlarla listeler: Baloncuk Patlatma, Tetris, Sudoku.
class GameRoomScreen extends StatelessWidget {
  const GameRoomScreen({super.key});

  static const _games = [
    _GameInfo(
      title: 'Baloncuk Patlatma',
      description: 'Nişan al, fırlat, aynı renkten 3+ balonu eşleştir!',
      icon: Icons.bubble_chart_rounded,
      gradient: [Color(0xFF00ACC1), Color(0xFF38BDF8)],
    ),
    _GameInfo(
      title: 'Tetris',
      description: 'Klasik blok istifleme. Satırları temizle, skoru yükselt.',
      icon: Icons.grid_view_rounded,
      gradient: [Color(0xFF6366F1), Color(0xFFB388FF)],
    ),
    _GameInfo(
      title: 'Sudoku',
      description: '9×9 mantık bulmacası. Üç zorluk, hata vurgusu, süre.',
      icon: Icons.apps_rounded,
      gradient: [Color(0xFF4CAF50), Color(0xFF00E5FF)],
    ),
  ];

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
              'Oyun Odası 🎮',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    _GameCard(
                      info: _games[0],
                      onTap: () => _open(context, const BubbleShooterGame()),
                    ),
                    const SizedBox(height: 16),
                    _GameCard(
                      info: _games[1],
                      onTap: () => _open(context, const TetrisGame()),
                    ),
                    const SizedBox(height: 16),
                    _GameCard(
                      info: _games[2],
                      onTap: () => _open(context, const SudokuGame()),
                    ),
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

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildHeader(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withValues(alpha: 0.25),
            theme.secondary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: theme.primary.withValues(alpha: 0.5)),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Color(0xFF03DAC5),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mini Oyunlar',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mola arası iyi gelir. Hangi oyunu oynayalım?',
                  style: TextStyle(color: theme.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameInfo {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const _GameInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

class _GameCard extends StatelessWidget {
  final _GameInfo info;
  final VoidCallback onTap;

  const _GameCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;
    final g = info.gradient;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              g[0].withValues(alpha: 0.16),
              g[1].withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: g[0].withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: g[0].withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [g[0], g[1]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: g[0].withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(info.icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.description,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: g[0].withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: g[0].withValues(alpha: 0.5)),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: g[0],
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

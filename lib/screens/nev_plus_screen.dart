import 'package:flutter/material.dart';
import '../models/auth_user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import 'admin_screen.dart';
import 'baskan_panel_screen.dart';
import 'campus_map_screen.dart';
import 'games/game_room_screen.dart';
import 'sosyo_screen.dart';


class NevPlusScreen extends StatelessWidget {
  final AuthUser? user;

  const NevPlusScreen({super.key, this.user});

  void _showComingSoon(BuildContext context, String featureName, AppTheme theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$featureName yakında geliyor! 🚀',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    AppTheme theme,
    String title,
    IconData icon,
    Color neonColor, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.surface.withValues(alpha: 0.6)
            : theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: neonColor.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: neonColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: neonColor.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: neonColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: theme.textMuted,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.isAdmin ?? false;
    final isBaskan = user?.isBaskan ?? false;

    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            title: Text(
              'NEV + ✨',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          body: AnimatedThemeBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Nev+ Header Logo Banner
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/nev_plus_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'Kampüs Cepte',
                    Icons.map_outlined,
                    const Color(0xFF00ACC1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CampusMapScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'Oyun Odası',
                    Icons.sports_esports,
                    const Color(0xFF03DAC5),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameRoomScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'Kitap Okuma Kulübü',
                    Icons.menu_book,
                    const Color(0xFFFFD700),
                    onTap: () => _showComingSoon(context, 'Kitap Okuma Kulübü', theme),
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'Topluluk Haberleri',
                    Icons.newspaper,
                    const Color(0xFF9D4EDD),
                    onTap: () => _showComingSoon(context, 'Topluluk Haberleri', theme),
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'Menüde Ne Var?',
                    Icons.restaurant_menu,
                    const Color(0xFFFF7043),
                    onTap: () => _showComingSoon(context, 'Menüde Ne Var?', theme),
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'İş ilanları',
                    Icons.work_outline,
                    const Color(0xFF42A5F5),
                    onTap: () => _showComingSoon(context, 'İş ilanları', theme),
                  ),
                  _buildMenuItem(
                    context,
                    theme,
                    'SOSYO',
                    Icons.auto_awesome,
                    const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SosyoScreen()),
                      );
                    },
                  ),
                  if (isAdmin || isBaskan)
                    _buildMenuItem(
                      context,
                      theme,
                      'Başkan Paneli',
                      Icons.workspace_premium_outlined,
                      const Color(0xFF43A047),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BaskanPanelScreen(),
                          ),
                        );
                      },
                    ),
                  if (isAdmin)
                    _buildMenuItem(
                      context,
                      theme,
                      'Admin Paneli',
                      Icons.admin_panel_settings,
                      const Color(0xFFFF9800),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminScreen(),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}

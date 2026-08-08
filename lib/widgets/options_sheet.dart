import 'package:flutter/material.dart';
import '../screens/sosyo_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/theme_customizer_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/campus_map_screen.dart';
import '../screens/games/game_room_screen.dart';
import '../services/supabase_auth_service.dart';
import '../theme/app_theme.dart';

class OptionsSheet extends StatelessWidget {
  final bool isAdmin;
  final String userName;
  final Future<void> Function()? onLogout;
  final bool isSettings;

  const OptionsSheet({
    super.key,
    this.isAdmin = false,
    this.userName = '',
    this.onLogout,
    this.isSettings = false,
  });

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    Color neonColor, {
    VoidCallback? onTap,
  }) {
    final theme = themeNotifier.value;
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.surface.withValues(alpha: 0.5)
            : theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: neonColor.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
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
          Icons.arrow_forward_ios,
          color: theme.textMuted,
          size: 16,
        ),
        onTap: onTap ?? () => Navigator.pop(context),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    final theme = themeNotifier.value;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final theme = themeNotifier.value;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(
          'Hesabı Sil',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Hesabın ve tüm verilerin (gönderiler, rozetler, profil) kalıcı '
          'olarak silinecek. Bu işlem geri alınamaz.\n\nDevam etmek istiyor musun?',
          style: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text(
              'Hesabı Sil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseAuthService.deleteAccount();
      nav.pop(); // sheet'i kapat
      if (onLogout != null) await onLogout!();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Hesap silinemedi: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final theme = themeNotifier.value;
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: theme.isDark
                ? theme.background.withValues(alpha: 0.95)
                : theme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border(top: BorderSide(color: theme.primary, width: 2)),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.1),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.textMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                isSettings ? 'Ayarlar ⚙️' : 'NEV + ✨',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (userName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isAdmin ? '👑 Admin: ' : '👤 ',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      userName,
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (isSettings) ...[
                // Ayarlar: Tema Özelleştirme, Çıkış Yap, Hesabı Sil
                _buildMenuItem(
                  context,
                  'Tema Özelleştirme',
                  Icons.palette,
                  const Color(0xFFFF5252),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => const ThemeCustomizerScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  'Gizlilik Politikası & Depolama',
                  Icons.security_rounded,
                  const Color(0xFF4CAF50),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  'Talep ve Şikayetler',
                  Icons.feedback_outlined,
                  const Color(0xFFFF9800),
                  onTap: () => _showComingSoon(context, 'Talep ve Şikayetler'),
                ),
                if (onLogout != null)
                  _buildMenuItem(
                    context,
                    'Çıkış Yap',
                    Icons.logout,
                    const Color(0xFFFF5252),
                    onTap: () async {
                      await onLogout!();
                    },
                  ),
                if (onLogout != null)
                  _buildMenuItem(
                    context,
                    'Hesabı Sil',
                    Icons.delete_forever,
                    const Color(0xFFD32F2F),
                    onTap: () => _confirmDeleteAccount(context),
                  ),
              ] else ...[
                // NEV +: Kampüs Cepte, Oyun Odası, Kitap Okuma Kulübü, Topluluk Haberleri, SOSYO, Admin Paneli
                _buildMenuItem(
                  context,
                  'Kampüs Cepte',
                  Icons.map_outlined,
                  const Color(0xFF00ACC1),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => const CampusMapScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  'Oyun Odası',
                  Icons.sports_esports,
                  const Color(0xFF03DAC5),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => const GameRoomScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  'Kitap Okuma Kulübü',
                  Icons.menu_book,
                  const Color(0xFFFFD700),
                  onTap: () => _showComingSoon(context, 'Kitap Okuma Kulübü'),
                ),
                _buildMenuItem(
                  context,
                  'Topluluk Haberleri',
                  Icons.newspaper,
                  const Color(0xFF9D4EDD),
                  onTap: () => _showComingSoon(context, 'Topluluk Haberleri'),
                ),
                _buildMenuItem(
                  context,
                  'SOSYO',
                  Icons.auto_awesome,
                  const Color(0xFF4CAF50),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(builder: (_) => const SosyoScreen()),
                    );
                  },
                ),
                if (isAdmin)
                  _buildMenuItem(
                    context,
                    'Admin Paneli',
                    Icons.admin_panel_settings,
                    const Color(0xFFFF9800),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(
                          builder: (_) => const AdminScreen(),
                        ),
                      );
                    },
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

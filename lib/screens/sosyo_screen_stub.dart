import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sosyo_texts.dart';
import '../services/supabase_data_service.dart';
import '../widgets/animated_theme_background.dart';
import '../theme/app_theme.dart';

class SosyoScreen extends StatefulWidget {
  const SosyoScreen({super.key});

  @override
  State<SosyoScreen> createState() => _SosyoScreenState();
}

class _SosyoScreenState extends State<SosyoScreen> {
  String _description =
      SosyoTexts.cachedDescription ?? SosyoTexts.defaultDescription;
  String _about = SosyoTexts.cachedAbout ?? SosyoTexts.defaultAbout;

  @override
  void initState() {
    super.initState();
    _loadTexts();
  }

  Future<void> _loadTexts() async {
    try {
      final settings = await SupabaseDataService().getAppSettings(
        const [SosyoTexts.descriptionKey, SosyoTexts.aboutKey],
      );
      String pick(String key, String fallback) {
        final v = settings[key]?.trim() ?? '';
        return v.isEmpty ? fallback : v;
      }

      final description =
          pick(SosyoTexts.descriptionKey, SosyoTexts.defaultDescription);
      final about = pick(SosyoTexts.aboutKey, SosyoTexts.defaultAbout);
      SosyoTexts.remember(description, about);
      if (!mounted) return;
      setState(() {
        _description = description;
        _about = about;
      });
    } catch (e) {
      debugPrint('[Sosyo] Metinler alınamadı, varsayılanlar gösteriliyor: $e');
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
            title: Text(
              'SoSYo 🌟',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: theme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: theme.primary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
          ),
          body: AnimatedThemeBackground(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık banner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text('✨', style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'SoSYo Sosyal Ağı',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _description,
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 13,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    '📡 Sosyal Medya',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SocialTile(
                    icon: Icons.camera_alt_outlined,
                    platform: 'Instagram',
                    handle: '@nevgenc_sau',
                    url: 'https://instagram.com/nevgenc_sau',
                    color: const Color(0xFFE1306C),
                    theme: theme,
                  ),
                  _SocialTile(
                    icon: Icons.message_outlined,
                    platform: 'Twitter / X',
                    handle: '@nevgenc_sau',
                    url: 'https://twitter.com/nevgenc_sau',
                    color: const Color(0xFF1DA1F2),
                    theme: theme,
                  ),
                  _SocialTile(
                    icon: Icons.send_outlined,
                    platform: 'Telegram',
                    handle: 't.me/NevGenc',
                    url: 'https://t.me/NevGenc',
                    color: const Color(0xFF0088CC),
                    theme: theme,
                  ),
                  _SocialTile(
                    icon: Icons.work_outline,
                    platform: 'LinkedIn',
                    handle: 'NevGenç SAÜ',
                    url: 'https://linkedin.com/company/nevgenc-sau',
                    color: const Color(0xFF0077B5),
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    '💡 Hakkında',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _about,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 13,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SocialTile extends StatelessWidget {
  final IconData icon;
  final String platform;
  final String handle;
  final String url;
  final Color color;
  final AppTheme theme;

  const _SocialTile({
    required this.icon,
    required this.platform,
    required this.handle,
    required this.url,
    required this.color,
    required this.theme,
  });

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$platform açılamadı.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  handle,
                  style: TextStyle(color: theme.textMuted, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.open_in_new, color: theme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}


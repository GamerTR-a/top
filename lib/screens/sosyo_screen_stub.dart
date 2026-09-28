import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/animated_theme_background.dart';
import '../theme/app_theme.dart';

class SosyoScreen extends StatelessWidget {
  const SosyoScreen({super.key});

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
                              'NevGenç topluluğunun sosyal platformu. Aşağıdaki bağlantılardan bize ulaşabilir, etkinliklerden haberdar olabilirsin!',
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
                          'Merhabalar; ben Bilgisayar Mühendisliği Öğrencisi Abdurrahman Turan Özcan; Yazılım Mühendisliği Öğrencisi Deniz Emir Yıldız, Yazılım Mühendisliği Öğrencisi Mehmet Ali Işık\'a teşekkür ederek söze başlamak istiyorum. NevGenç, Sakarya ve Sakarya Uygulamalı Bilimler üniversitesindeki toplulukların ve öğrenci arkadaşlarımızın hayatını kolaylaştırmak ve üniversite hayatını en verimli şekilde geçirmelerini amaçlayarak ortaya çıkmış bir projedir. Sakarya Belediyesi, Serdivan\'daki çeşitli işletmeler, Çekirdekten Girişimci Vakfı, üniversite toplulukları ve üniversite yönetimi arasında köprü olarak kampüsümüzü ve Sakaryamızı geleceğe taşımak için NevGenç projesini hayata geçirdik.',
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


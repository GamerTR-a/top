import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';
import '../models/topluluk.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../services/supabase_data_service.dart';

/// Topluluk sohbeti artık uygulama içinde değil; Telegram / Discord üzerinde
/// yürütülüyor. Bu ekran topluluğun harici sohbet grubuna derin link açar ve
/// başkan/admin bağlantıyı yönetebilir (sunucu depolaması kullanılmaz).
class CommunityChatScreen extends StatefulWidget {
  final Topluluk topluluk;

  const CommunityChatScreen({super.key, required this.topluluk});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final SupabaseDataService _svc = SupabaseDataService();

  Map<String, String> _links = {};
  bool _loading = true;
  bool _canManage = false;

  /// Varsayılan Telegram bağlantısı — topluluk özel bir bağlantı eklemediyse
  /// buton boş dönmesin diye NevGenç resmi grubuna yönlendirilir.
  static const _defaultTelegramUrl = 'https://t.me/NevGenc';

  String? _resolvedLink(String platform) {
    final stored = _links[platform];
    if (stored != null && stored.trim().isNotEmpty) return stored;
    if (platform == 'telegram') return _defaultTelegramUrl;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final links = await _svc.getCommunityLinks(widget.topluluk.id);
    String? role;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .single();
        role = profile['role'] as String?;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _links = links;
      _loading = false;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      _canManage =
          role == 'admin' || (uid != null && widget.topluluk.baskanId == uid);
    });
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showSnack('Bağlantı açılamadı.', isError: true);
    } catch (_) {
      if (mounted) _showSnack('Bağlantı açılamadı.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final theme = themeNotifier.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? theme.error : theme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _editLinkDialog(String platform) async {
    final theme = themeNotifier.value;
    final urlCtrl = TextEditingController(text: _links[platform] ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          platform == 'telegram' ? 'Telegram Grubu 📨' : 'Discord Sunucusu 🎧',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: urlCtrl,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:
                platform == 'telegram'
                    ? 'https://t.me/NevGenc'
                    : 'https://discord.gg/DavetKodu',
            hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
            filled: true,
            fillColor: theme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: _links.containsKey(platform)
                ? () async {
                    await _svc.removeCommunityLink(
                      widget.topluluk.id,
                      platform,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, 'remove');
                  }
                : null,
            child: Text('Kaldır', style: TextStyle(color: theme.error)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _svc.setCommunityLink(
                  widget.topluluk.id,
                  platform,
                  urlCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx, 'saved');
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: theme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (saved == 'saved' || saved == 'remove') await _load();
  }

  Widget _buildLogo(AppTheme theme) {
    final path = widget.topluluk.logoPath;
    final fallback = Icon(Icons.group, color: theme.textMuted, size: 40);
    return ClipOval(
      child: SizedBox(
        width: 84,
        height: 84,
        child: AppNetworkImage(
          path: path,
          fit: BoxFit.cover,
          fallback: () => fallback,
        ),
      ),
    );
  }

  Widget _linkButton({
    required String platform,
    required AppTheme theme,
    required String? url,
    required bool canManage,
  }) {
    final isTelegram = platform == 'telegram';
    final color = isTelegram ? const Color(0xFF229ED9) : const Color(0xFF5865F2);
    final icon = isTelegram ? Icons.send_rounded : Icons.headset_rounded;
    final label = isTelegram ? 'Telegram Grubuna Katıl' : 'Discord Sunucusuna Katıl';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: color, size: 28),
            title: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              isTelegram ? 'Telegram uygulamasına geçer' : 'Discord uygulamasına geçer',
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
            trailing: url != null
                ? IconButton(
                    icon: Icon(Icons.open_in_new, color: color),
                    onPressed: () => _openLink(url),
                    tooltip: 'Aç',
                  )
                : null,
            onTap: url != null ? () => _openLink(url) : null,
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    url != null
                        ? 'Bağlantı: ${url.replaceFirst('https://', '')}'
                        : 'Bu platform için bağlantı yok',
                    style: TextStyle(color: theme.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  TextButton.icon(
                    onPressed: () => _editLinkDialog(platform),
                    icon: Icon(
                      url != null ? Icons.edit_outlined : Icons.add_link,
                      size: 16,
                      color: theme.primary,
                    ),
                    label: Text(
                      url != null ? 'Düzenle' : 'Ekle',
                      style: TextStyle(color: theme.primary, fontSize: 12),
                    ),
                  ),
                ],
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
        final t = widget.topluluk;
        return AnimatedThemeBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: theme.surface.withValues(alpha: 0.6),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.ad,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sohbet',
                    style: TextStyle(color: theme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            body: _loading
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: theme.primary,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        const SizedBox(height: 8),
                        Center(child: _buildLogo(theme)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            t.ad,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (t.baskanAdi != 'Belirtilmedi')
                          Center(
                            child: Text(
                              'Başkan: ${t.baskanAdi}',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.rocket_launch_outlined,
                                color: theme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Bu topluluğun sohbeti artık Telegram / '
                                  'Discord üzerinden yürütülüyor. Daha hızlı, '
                                  'ücretsiz ve kayıt gerektirmez.',
                                  style: TextStyle(
                                    color: theme.textMuted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _linkButton(
                          platform: 'telegram',
                          theme: theme,
                          url: _resolvedLink('telegram'),
                          canManage: _canManage,
                        ),
                        _linkButton(
                          platform: 'discord',
                          theme: theme,
                          url: _resolvedLink('discord'),
                          canManage: _canManage,
                        ),
                        if (_links.isEmpty && !_canManage)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text(
                                'Bu topluluğun özel bir grubu yok; '
                                'varsayılan NevGenç Telegram grubuna bağlanırsın.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Bağlantıyı kimler yönetebilir? Topluluk başkanı '
                            've yöneticiler.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textMuted.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/supabase_data_service.dart';
import '../../theme/app_theme.dart';

/// Bir topluluğun gösterebileceği harici bağlantı türü.
class CommunityLinkPlatform {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String hint;

  const CommunityLinkPlatform(
    this.key,
    this.label,
    this.icon,
    this.color,
    this.hint,
  );
}

/// Başkan panelinde düzenlenen ve topluluk sayfasında gösterilen platformlar.
/// Anahtarlar `community_links.platform` CHECK kısıtıyla aynı olmalı.
const communityLinkPlatforms = <CommunityLinkPlatform>[
  CommunityLinkPlatform('whatsapp', 'WhatsApp', Icons.chat_bubble_outline,
      Color(0xFF25D366), 'https://chat.whatsapp.com/...'),
  CommunityLinkPlatform('telegram', 'Telegram', Icons.send_outlined,
      Color(0xFF0088CC), 'https://t.me/...'),
  CommunityLinkPlatform('instagram', 'Instagram', Icons.camera_alt_outlined,
      Color(0xFFE1306C), 'https://instagram.com/...'),
  CommunityLinkPlatform('discord', 'Discord', Icons.discord,
      Color(0xFF5865F2), 'https://discord.gg/...'),
  CommunityLinkPlatform('x', 'X (Twitter)', Icons.alternate_email_rounded,
      Color(0xFF64748B), 'https://x.com/...'),
  CommunityLinkPlatform('linkedin', 'LinkedIn', Icons.work_outline,
      Color(0xFF0077B5), 'https://linkedin.com/company/...'),
  CommunityLinkPlatform('youtube', 'YouTube', Icons.play_circle_outline,
      Color(0xFFFF0000), 'https://youtube.com/@...'),
  CommunityLinkPlatform('website', 'Web Sitesi', Icons.language_rounded,
      Color(0xFF00ACC1), 'https://...'),
];

/// Başkan Paneli — "Bağlantılar" sekmesi. Boş bırakılan bağlantı silinir.
class LinksTab extends StatefulWidget {
  final AppTheme theme;
  final int communityId;

  const LinksTab({super.key, required this.theme, required this.communityId});

  @override
  State<LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<LinksTab> {
  final _api = SupabaseDataService();
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls = {
    for (final p in communityLinkPlatforms) p.key: TextEditingController(),
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LinksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.communityId != widget.communityId) _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.communityId;
    setState(() => _loading = true);
    final links = await _api.getCommunityLinks(id);
    if (!mounted || id != widget.communityId) return;
    setState(() {
      for (final e in _ctrls.entries) {
        e.value.text = links[e.key] ?? '';
      }
      _loading = false;
    });
  }

  String? _validateUrl(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    if (!t.startsWith('https://') || uri == null || !uri.hasAuthority) {
      return 'https:// ile başlayan geçerli bir bağlantı girin';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final theme = widget.theme;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await _api.saveCommunityLinks(
        widget.communityId,
        {for (final e in _ctrls.entries) e.key: e.value.text.trim()},
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Bağlantılar kaydedildi.'),
          backgroundColor: theme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: theme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Topluluk Bağlantıları',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doldurduğunuz bağlantılar topluluk sayfasında gösterilir. '
            'Bir bağlantıyı kaldırmak için alanı boş bırakıp kaydedin.',
            style: TextStyle(color: theme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final p in communityLinkPlatforms)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _ctrls[p.key],
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: TextStyle(color: theme.textColor, fontSize: 13),
                validator: _validateUrl,
                decoration: InputDecoration(
                  labelText: p.label,
                  labelStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                  hintText: p.hint,
                  hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                  prefixIcon: Icon(p.icon, color: p.color, size: 20),
                  filled: true,
                  fillColor: theme.surface,
                  border: border(theme.primary.withValues(alpha: 0.2)),
                  enabledBorder: border(theme.primary.withValues(alpha: 0.2)),
                  focusedBorder: border(theme.primary, 1.5),
                  errorBorder: border(theme.error),
                  focusedErrorBorder: border(theme.error, 1.5),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined, color: Colors.white),
              label: const Text(
                'Bağlantıları Kaydet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

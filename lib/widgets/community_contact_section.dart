import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/topluluk.dart';
import '../screens/baskan_panel/links_tab.dart' show communityLinkPlatforms;
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';

/// Topluluk sayfasında başkanın girdiği iletişim bilgilerini ve bağlantıları
/// gösterir. Hiçbiri yoksa yer kaplamaz.
class CommunityContactSection extends StatefulWidget {
  final Topluluk topluluk;
  final AppTheme theme;

  const CommunityContactSection({
    super.key,
    required this.topluluk,
    required this.theme,
  });

  @override
  State<CommunityContactSection> createState() =>
      _CommunityContactSectionState();
}

class _CommunityContactSectionState extends State<CommunityContactSection> {
  final _api = SupabaseDataService();
  Map<String, String> _links = const {};
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _email = widget.topluluk.iletisimEposta;
    _phone = widget.topluluk.iletisimTelefon;
    _load();
  }

  Future<void> _load() async {
    final id = widget.topluluk.id;
    final results = await Future.wait([
      _api.getCommunityLinks(id),
      _api.getCommunityById(id),
    ]);
    if (!mounted) return;
    final fresh = results[1] as Topluluk?;
    setState(() {
      _links = results[0] as Map<String, String>;
      if (fresh != null) {
        _email = fresh.iletisimEposta;
        _phone = fresh.iletisimTelefon;
      }
    });
  }

  Future<void> _open(Uri uri, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      messenger.showSnackBar(SnackBar(content: Text('$label açılamadı.')));
    }
  }

  Widget _chip(IconData icon, String label, Color color, VoidCallback onTap) {
    final theme = widget.theme;
    return Material(
      color: theme.surface.withValues(alpha: theme.isDark ? 0.6 : 1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final chips = <Widget>[
      if (_email.isNotEmpty)
        _chip(
          Icons.alternate_email_rounded,
          _email,
          theme.primary,
          () => _open(Uri(scheme: 'mailto', path: _email), 'E-posta'),
        ),
      if (_phone.isNotEmpty)
        _chip(
          Icons.phone_outlined,
          _phone,
          theme.primary,
          () => _open(
            Uri(scheme: 'tel', path: _phone.replaceAll(RegExp(r'[^0-9+]'), '')),
            'Telefon',
          ),
        ),
      for (final p in communityLinkPlatforms)
        if ((_links[p.key] ?? '').startsWith('https://'))
          _chip(
            p.icon,
            p.label,
            p.color,
            () => _open(Uri.parse(_links[p.key]!), p.label),
          ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İletişim ve Bağlantılar',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

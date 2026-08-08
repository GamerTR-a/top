import 'package:flutter/material.dart';
import '../models/topluluk.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../services/joined_communities_service.dart';
import '../services/supabase_data_service.dart';
import 'community_chat_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Topluluk topluluk;
  const CommunityDetailScreen({super.key, required this.topluluk});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _svc = SupabaseDataService();
  late Future<Map<String, dynamic>> _activitiesFuture;
  bool? _isMember;
  bool _membershipLoading = false;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _svc.getCommunityActivities(widget.topluluk.id);
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    final joined =
        await JoinedCommunitiesService.instance.isJoined(widget.topluluk.id);
    if (mounted) setState(() => _isMember = joined);
  }

  Future<void> _toggleMembership(AppTheme theme) async {
    if (_membershipLoading) return;
    setState(() => _membershipLoading = true);
    try {
      // Liste kartındaki "Katıl" ile aynı yerel mantık: anında ve çevrimdışı çalışır.
      final joined =
          await JoinedCommunitiesService.instance.toggle(widget.topluluk);
      if (mounted) {
        setState(() => _isMember = joined);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              joined
                  ? '${widget.topluluk.ad} topluluğuna katıldın! 🎉'
                  : '${widget.topluluk.ad} topluluğundan ayrıldın.',
            ),
            backgroundColor: joined ? theme.primary : theme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _membershipLoading = false);
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityChatScreen(topluluk: widget.topluluk),
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
              backgroundColor: theme.surface.withValues(alpha: 0.4),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                t.ad,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              actions: [
                if (_isMember != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _membershipLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: theme.primary,
                              strokeWidth: 2,
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _toggleMembership(theme),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _isMember!
                                    ? theme.error.withValues(alpha: 0.15)
                                    : theme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isMember!
                                      ? theme.error
                                      : theme.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isMember! ? Icons.exit_to_app : Icons.add,
                                    color: _isMember!
                                        ? theme.error
                                        : theme.primary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isMember! ? 'Ayrıl' : 'Katıl',
                                    style: TextStyle(
                                      color: _isMember!
                                          ? theme.error
                                          : theme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityHeader(topluluk: t, theme: theme),
                    const SizedBox(height: 16),
                    _ChatButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Sohbete Katıl 💬',
                      color: theme.primary,
                      onTap: _openChat,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Son Faaliyetler',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActivitiesSection(
                      future: _activitiesFuture,
                      theme: theme,
                      onRetry: () {
                        setState(
                          () => _activitiesFuture = _svc.getCommunityActivities(
                            widget.topluluk.id,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Community Header ─────────────────────────────────────────────────────────

Widget _buildLogoWidget(String path, AppTheme theme) {
  final fallback = Icon(Icons.groups, color: theme.primary, size: 40);
  return AppNetworkImage(
    path: path,
    fit: BoxFit.cover,
    fallback: () => fallback,
  );
}

class _CommunityHeader extends StatelessWidget {
  final Topluluk topluluk;
  final AppTheme theme;
  const _CommunityHeader({required this.topluluk, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = topluluk;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    color: theme.background,
                    child: _buildLogoWidget(t.logoPath, theme),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.ad,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Kategori chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.kategori,
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Stats
                    Row(
                      children: [
                        _StatBadge(
                          icon: Icons.people_alt,
                          label: '${t.uyeSayisi} üye',
                          color: theme.secondary,
                        ),
                        const SizedBox(width: 12),
                        _StatBadge(
                          icon: Icons.star_rounded,
                          label: '${t.puan.toInt()} puan',
                          color: theme.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (t.aciklama.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              t.aciklama,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline, color: theme.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(
                'Başkan: ${t.baskanAdi}',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Chat Button ──────────────────────────────────────────────────────────────

class _ChatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ChatButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activities ────────────────────────────────────────────────────────────────

class _ActivitiesSection extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  final AppTheme theme;
  final VoidCallback onRetry;
  const _ActivitiesSection({
    required this.future,
    required this.theme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: theme.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(theme: theme, onRetry: onRetry);
        }

        final data = snapshot.data ?? {};
        final posts = (data['posts'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final events = (data['events'] as List? ?? [])
            .cast<Map<String, dynamic>>();

        // Unified activity list sorted by date
        final items = <_ActivityItem>[
          ...posts.map((p) => _ActivityItem.fromPost(p)),
          ...events.map((e) => _ActivityItem.fromEvent(e)),
        ]..sort((a, b) => b.date.compareTo(a.date));

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: theme.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz faaliyet yok',
                    style: TextStyle(color: theme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: items
              .take(15)
              .map((item) => _ActivityCard(item: item, theme: theme))
              .toList(),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final AppTheme theme;
  final VoidCallback onRetry;
  const _ErrorState({required this.theme, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 40,
              color: theme.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'Faaliyetler yüklenemedi',
              style: TextStyle(color: theme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: theme.primary),
              label: Text(
                'Tekrar Dene',
                style: TextStyle(color: theme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity Data Model ──────────────────────────────────────────────────────

enum _ActivityType { post, event }

class _ActivityItem {
  final _ActivityType type;
  final String title;
  final String? subtitle;
  final DateTime date;
  final int? supportCount;

  const _ActivityItem({
    required this.type,
    required this.title,
    this.subtitle,
    required this.date,
    this.supportCount,
  });

  factory _ActivityItem.fromPost(Map<String, dynamic> p) {
    final content = p['content'] as String? ?? '';
    return _ActivityItem(
      type: _ActivityType.post,
      title: content.length > 80 ? '${content.substring(0, 80)}…' : content,
      date: DateTime.parse(p['created_at'] as String).toLocal(),
      supportCount: (p['support_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory _ActivityItem.fromEvent(Map<String, dynamic> e) {
    return _ActivityItem(
      type: _ActivityType.event,
      title: e['title'] as String? ?? '',
      subtitle: e['location'] as String?,
      date: DateTime.parse(
        (e['event_date'] ?? e['created_at']) as String,
      ).toLocal(),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _ActivityItem item;
  final AppTheme theme;
  const _ActivityCard({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isEvent = item.type == _ActivityType.event;
    final color = isEvent ? theme.warning : theme.secondary;
    final icon = isEvent ? Icons.event_rounded : Icons.article_outlined;
    final dateStr = _formatDate(item.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEvent ? item.title : item.title,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: theme.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(color: theme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 11, color: theme.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      dateStr,
                      style: TextStyle(color: theme.textMuted, fontSize: 11),
                    ),
                    if (item.supportCount != null &&
                        item.supportCount! > 0) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 11,
                        color: theme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.supportCount}',
                        style: TextStyle(color: theme.primary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

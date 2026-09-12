import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:url_launcher/url_launcher.dart';
import '../models/auth_user_model.dart';
import '../services/supabase_data_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';


class NotificationCenterScreen extends StatefulWidget {
  final AuthUser currentUser;
  const NotificationCenterScreen({super.key, required this.currentUser});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  final _svc = SupabaseDataService();
  final _notifSvc = NotificationService();

  late TabController _tabController;
  final List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  static const _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
    _setupRealtime();
    _requestPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeSub?.unsubscribe();
    super.dispose();
  }

  RealtimeChannel? _realtimeSub;

  void _setupRealtime() {
    _realtimeSub = _svc.subscribeToNotifications(widget.currentUser.id, (payload) {
      if (mounted) {
        final newNotif = Map<String, dynamic>.from(payload);
        setState(() => _notifications.insert(0, newNotif));
      }
    });
  }

  Future<void> _requestPermission() async {
    await _notifSvc.requestPermission();
    await _notifSvc.saveFcmTokenToServer();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 0;
        _hasMore = true;
        _notifications.clear();
      });
    }
    if (!_hasMore || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final res = await _svc.getNotifications(
        userId: widget.currentUser.id,
        page: _page,
        limit: _pageSize,
      );
      if (mounted) {
        if (res.length < _pageSize) _hasMore = false;
        setState(() {
          _notifications.addAll(res);
          _page++;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _svc.markNotificationRead(notificationId);
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (idx != -1) {
          _notifications[idx]['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final unreadIds = _notifications
        .where((n) => !(n['is_read'] as bool? ?? false))
        .map((n) => n['id'] as String)
        .toList();
    for (final id in unreadIds) {
      await _svc.markNotificationRead(id);
    }
    setState(() {
      for (final n in _notifications) {
        n['is_read'] = true;
      }
    });
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
      if (diff.inHours < 24) return '${diff.inHours} sa önce';
      if (diff.inDays < 7) return '${diff.inDays} gün önce';
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return '';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'member_joined': return Icons.person_add_rounded;
      case 'member_left': return Icons.person_remove_rounded;
      case 'event_created': return Icons.event_rounded;
      case 'event_reminder': return Icons.notification_important_rounded;
      case 'post_reported': return Icons.report_rounded;
      case 'post_rated': return Icons.star_rounded;
      case 'badge_earned': return Icons.emoji_events_rounded;
      case 'announcement': return Icons.campaign_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type, AppTheme theme) {
    switch (type) {
      case 'member_joined': return Colors.green;
      case 'member_left': return theme.error;
      case 'event_created': return theme.primary;
      case 'event_reminder': return theme.warning;
      case 'post_reported': return theme.error;
      case 'post_rated': return theme.warning;
      case 'badge_earned': return Colors.amber;
      case 'announcement': return theme.secondary;
      default: return theme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final unreadCount = _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;
        final tabs = [
          Tab(text: 'Tümü'),
          Tab(text: 'Okunmamış ($unreadCount)'),
          Tab(text: 'Ayarlar'),
        ];

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
              title: Text('Bildirimler', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 17)),
              actions: [
                if (_notifications.any((n) => !(n['is_read'] as bool? ?? false)))
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: Text('Tümünü Okundu İşaretle', style: TextStyle(color: theme.primary, fontSize: 12)),
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: theme.primary,
                unselectedLabelColor: theme.textMuted,
                indicatorColor: theme.primary,
                tabs: tabs,
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildListTab(theme, filterRead: null),
                _buildListTab(theme, filterRead: false),
                _buildSettingsTab(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleNotificationTap(Map<String, dynamic> n) {
    _markAsRead(n['id'] as String);

    final type = n['type'] as String? ?? '';
    final title = n['title'] as String? ?? 'Bildirim Detayı';
    final body = n['body'] as String? ?? '';
    final data = n['data'] as Map<String, dynamic>? ?? {};
    final storeUrl = data['store_url'] as String?;
    final version = data['version'] as String?;
    final isUpdate = type == 'announcement' || data['is_update'] == true;

    final theme = themeNotifier.value;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isUpdate ? Icons.system_update_rounded : Icons.notifications_rounded,
              color: isUpdate ? const Color(0xFF9D4EDD) : theme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (version != null && version.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D4EDD).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sürüm: $version',
                  style: const TextStyle(
                    color: Color(0xFF9D4EDD),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              body,
              style: TextStyle(color: theme.textMuted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Anladım', style: TextStyle(color: theme.textMuted)),
          ),
          if (storeUrl != null && storeUrl.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Güncelle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildListTab(AppTheme theme, {bool? filterRead}) {
    final filtered = filterRead == null
        ? _notifications
        : _notifications.where((n) => (n['is_read'] as bool? ?? false) != filterRead).toList();

    if (_loading && filtered.isEmpty) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    if (filtered.isEmpty) {
      return _emptyState(theme, filterRead == false ? 'Okunmamış bildiriminiz yok 🎉' : 'Henüz bildirim yok');
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(refresh: true),
      color: theme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            if (_loadingMore) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: theme.primary)),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => _loadNotifications(),
                child: Text('Daha fazla yükle', style: TextStyle(color: theme.primary)),
              ),
            );
          }

          final n = filtered[index];
          final isRead = n['is_read'] as bool? ?? false;
          final type = n['type'] as String? ?? 'info';
          final title = n['title'] as String? ?? '';
          final body = n['body'] as String? ?? '';
          final createdAt = n['created_at'] as String? ?? '';
          final icon = _iconForType(type);
          final color = _colorForType(type, theme);

          return _NotificationCard(
            theme: theme,
            icon: icon,
            color: color,
            title: title,
            body: body,
            time: _formatDate(createdAt),
            isRead: isRead,
            onTap: () => _handleNotificationTap(n),
            onDismiss: () async {
              await _svc.deleteNotification(n['id'] as String);
              setState(() => _notifications.remove(n));
            },
          );
        },
      ),
    );
  }


  Widget _emptyState(AppTheme theme, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: theme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: theme.textMuted, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(AppTheme theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(title: 'Push Bildirimleri', theme: theme, children: [
          _SettingTile(
            theme: theme,
            icon: Icons.notifications_active,
            title: 'Push Bildirimleri',
            subtitle: 'Yeni üye, etkinlik, rapor vb. anında bildirim al',
            trailing: Switch(
              value: _notifSvc.pushEnabled,
              onChanged: (v) => _notifSvc.setPushEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
          _SettingTile(
            theme: theme,
            icon: Icons.group_add,
            title: 'Yeni Üye Bildirimleri',
            subtitle: 'Topluluğa yeni üye katıldığında',
            trailing: Switch(
              value: _notifSvc.memberJoinEnabled,
              onChanged: (v) => _notifSvc.setMemberJoinEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
          _SettingTile(
            theme: theme,
            icon: Icons.event,
            title: 'Etkinlik Bildirimleri',
            subtitle: 'Yeni etkinlik oluşturulduğunda / hatırlatma',
            trailing: Switch(
              value: _notifSvc.eventEnabled,
              onChanged: (v) => _notifSvc.setEventEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
          _SettingTile(
            theme: theme,
            icon: Icons.report,
            title: 'Rapor Bildirimleri',
            subtitle: 'Gönderi rapor edildiğinde (sadece başkan/admin)',
            trailing: Switch(
              value: _notifSvc.reportEnabled,
              onChanged: (v) => _notifSvc.setReportEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _SettingsSection(title: 'Uygulama İçi', theme: theme, children: [
          _SettingTile(
            theme: theme,
            icon: Icons.badge,
            title: 'Rozet Kazanma Bildirimi',
            subtitle: 'Yeni rozet kazandığınızda',
            trailing: Switch(
              value: _notifSvc.badgeEnabled,
              onChanged: (v) => _notifSvc.setBadgeEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
          _SettingTile(
            theme: theme,
            icon: Icons.campaign,
            title: 'Duyuru Bildirimleri',
            subtitle: 'Yönetici duyuruları',
            trailing: Switch(
              value: _notifSvc.announcementEnabled,
              onChanged: (v) => _notifSvc.setAnnouncementEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _SettingsSection(title: 'Gelişmiş', theme: theme, children: [
          _SettingTile(
            theme: theme,
            icon: Icons.sync,
            title: 'Realtime Senkronizasyonu',
            subtitle: 'Anlık bildirim akışı (WebSocket)',
            trailing: Switch(
              value: _notifSvc.realtimeEnabled,
              onChanged: (v) => _notifSvc.setRealtimeEnabled(v),
              activeThumbColor: theme.primary,
            ),
          ),
          _SettingTile(
            theme: theme,
            icon: Icons.delete_sweep,
            title: 'Okunmuş Bildirimleri Temizle',
            subtitle: '30 günden eski okunmuş bildirimleri sil',
            trailing: TextButton(
              onPressed: () => _clearOldRead(),
              child: Text('Temizle', style: TextStyle(color: theme.error)),
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _clearOldRead() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eski Bildirimleri Temizle'),
        content: const Text('30 günden eski okunmuş bildirimler silinecek. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Temizle')),
        ],
      ),
    );
    if (confirm != true) return;
    await _svc.deleteOldReadNotifications(widget.currentUser.id);
    _loadNotifications(refresh: true);
  }
}

class _NotificationCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.theme,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(title + time),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete, color: theme.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? theme.surface.withValues(alpha: 0.35)
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? theme.primary.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(time, style: TextStyle(color: theme.textMuted, fontSize: 11)),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(color: theme.textMuted, fontSize: 12, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final AppTheme theme;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _SettingTile({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: theme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
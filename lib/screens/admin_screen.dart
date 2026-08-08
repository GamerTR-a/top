import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../widgets/animated_theme_background.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = SupabaseDataService();
  List<AuthUser> _users = [];
  bool _loadingUsers = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _reports = [];
  bool _loadingReports = true;
  List<Topluluk> _communities = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Route guard — admin olmayan kullanıcıları geri gönder
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .single();
        if ((profile['role'] as String?) != 'admin' && mounted) {
          Navigator.of(context).pop();
        }
      } catch (_) {
        if (mounted) Navigator.of(context).pop();
      }
    });
    _loadUsers();
    _loadStats();
    _loadReports();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    try {
      final list = await _api.getTopluluklarForAdmin();
      if (!mounted) return;
      setState(() => _communities = list);
    } catch (e) {
      debugPrint('[Admin] Topluluklar yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await _api.getAdminUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loadingUsers = false;
      });
    } catch (e) {
      debugPrint('[Admin] Kullanıcılar yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _api.getAdminStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      debugPrint('[Admin] İstatistikler yüklenemedi: $e');
    }
  }

  Future<void> _loadReports() async {
    try {
      final reports = await _api.getPostReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loadingReports = false;
      });
    } catch (e) {
      debugPrint('[Admin] Şikayetler yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _loadingReports = false);
    }
  }

  Future<void> _showChairmanDialog(AuthUser user) async {
    final theme = themeNotifier.value;
    await _loadCommunities();
    if (!mounted) return;

    // Kullanıcı zaten bir topluluğun başkanıysa onu seçili getir.
    int? selectedId;
    if (user.isBaskan) {
      final cur = _communities.where((c) => c.baskanId == user.id).toList();
      if (cur.isNotEmpty) selectedId = cur.first.id;
    }

    final isAdminUser = user.role == 'admin';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final byId = {for (final c in _communities) c.id: c};
          final sel = selectedId != null ? byId[selectedId] : null;
          final wouldReplace = sel != null &&
              sel.baskanId != null &&
              sel.baskanId != user.id;
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Başkan Ata',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${user.name}" kullanıcısını başkan yap',
                    style: TextStyle(color: theme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_communities.isEmpty)
                    Text(
                      'Topluluklar yüklenemedi. Paneli yenilemeyi deneyin.',
                      style: TextStyle(color: theme.error, fontSize: 12),
                    )
                  else
                  DropdownButtonFormField<int?>(
                    initialValue: selectedId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Topluluk',
                      filled: true,
                      fillColor: theme.surface.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    dropdownColor: theme.surface,
                    items: [
                      for (final c in _communities)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.baskanId != null &&
                                    c.baskanAdi != 'Belirtilmedi'
                                ? '${c.ad} — Bşk: ${c.baskanAdi}'
                                : c.ad,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: isAdminUser
                        ? null
                        : (v) => setDialogState(() => selectedId = v),
                  ),
                  const SizedBox(height: 10),
                  if (wouldReplace)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '⚠️ "${sel.baskanAdi}" bu topluluğun şu anki başkanı. '
                        'Atanırsa başkanlığı değişecek.',
                        style: TextStyle(
                          color: theme.warning,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else if (user.isBaskan)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bu kullanıcı şu an başkan. Yeni topluluk seçerek '
                        'başkanlığını taşıyabilir veya aşağıdan kaldırabilirsin.',
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (isAdminUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Admin kullanıcıya başkan atanamaz (rolü düşer).',
                        style: TextStyle(
                          color: theme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (user.isBaskan) ...[
                TextButton(
                  onPressed: () async {
                    final cur = _communities
                        .where((c) => c.baskanId == user.id)
                        .toList();
                    if (cur.isEmpty) return;
                    Navigator.pop(ctx);
                    bool ok = false;
                    try {
                      await _api.removeChairman(
                        communityId: cur.first.id,
                        chairmanId: user.id,
                      );
                      ok = true;
                    } catch (e) {
                      debugPrint('[Admin] Başkanlık kaldırılamadı: $e');
                    }
                    await _loadUsers();
                    await _loadCommunities();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _snack(
                          ok
                              ? 'Başkanlık kaldırıldı.'
                              : 'Başkanlık kaldırılamadı.',
                          ok ? theme.primary : theme.error,
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: theme.error,
                  ),
                  child: const Text('Başkanlığı Kaldır'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('İptal', style: TextStyle(color: theme.textMuted)),
              ),
              ElevatedButton(
                onPressed: isAdminUser || selectedId == null
                    ? null
                    : () async {
                        final cid = selectedId;
                        if (cid == null) return;
                        Navigator.pop(ctx);
                        bool ok = false;
                        try {
                          await _api.assignChairman(
                            userId: user.id,
                            userName: user.name,
                            communityId: cid,
                          );
                          ok = true;
                        } catch (e) {
                          debugPrint('[Admin] Başkan atanamadı: $e');
                        }
                        await _loadUsers();
                        await _loadCommunities();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            _snack(
                              ok
                                  ? '${user.name} başkan yapıldı.'
                                  : 'Başkan atanamadı.',
                              ok ? theme.primary : theme.error,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ata'),
              ),
            ],
          );
        },
      ),
    );
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      );

  Future<void> _handleReportAction(
    Map<String, dynamic> report,
    String action,
  ) async {
    final reportId = report['id'] as int;
    final post = report['posts'] as Map?;
    final postId = (post?['id'] as num?)?.toInt();
    try {
      switch (action) {
        case 'hide':
          if (postId != null) await _api.setPostStatus(postId, 'hidden');
          await _api.updateReportStatus(reportId, 'reviewed');
          break;
        case 'reviewed':
          await _api.updateReportStatus(reportId, 'reviewed');
          break;
        case 'dismissed':
          await _api.updateReportStatus(reportId, 'dismissed');
          break;
      }
    } catch (e) {
      debugPrint('[Admin] Şikayet işlemi başarısız: $e');
    }
    await _loadReports();
  }

  Widget _buildReportsTab() {
    final theme = themeNotifier.value;
    if (_loadingReports) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 56,
              color: theme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Açık şikayet yok 🎉',
              style: TextStyle(color: theme.textMuted),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReports,
      color: theme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) => _ReportCard(
          report: _reports[index],
          theme: theme,
          onAction: _handleReportAction,
        ),
      ),
    );
  }

  void _showDeleteConfirm(AuthUser user) {
    final theme = themeNotifier.value;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Kullanıcıyı Sil',
          style: TextStyle(color: theme.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${user.name}" adlı kullanıcıyı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = false;
              try {
                await _api.deleteAdminUser(user.id);
                success = true;
              } catch (e) {
                debugPrint('[Admin] Kullanıcı silinemedi: $e');
              }
              await _loadUsers();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '${user.name} silindi.'
                          : 'Silme işlemi başarısız oldu.',
                    ),
                    backgroundColor: success ? theme.error : theme.textMuted,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAdminPasswordDialog() {
    final theme = themeNotifier.value;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Admin Şifresi',
          style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Admin hesabı şifresini değiştirmek için Supabase kontrol panelinden '
          'Authentication → Users bölümüne gidin ve ilgili kullanıcıyı seçin.',
          style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Anladım', style: TextStyle(color: theme.primary)),
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
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: theme.primary),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Admin Paneli 👑',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: theme.primary,
              unselectedLabelColor: theme.textMuted,
              indicatorColor: theme.primary,
              tabs: const [
                Tab(text: 'Kullanıcılar'),
                Tab(text: 'Şikayetler'),
                Tab(text: 'Ayarlar'),
              ],
            ),
          ),
          body: AnimatedThemeBackground(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Kullanıcılar
                _loadingUsers
                    ? Center(
                        child: CircularProgressIndicator(color: theme.primary),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: theme.primary,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.people,
                                    label: 'Toplam Kullanıcı',
                                    value: _stats != null
                                        ? '${_stats!['totalUsers'] ?? _users.length}'
                                        : '${_users.length}',
                                    color: theme.primary,
                                    theme: theme,
                                  ),
                                ),
                                if (_stats != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.groups,
                                      label: 'Topluluklar',
                                      value:
                                          '${_stats!['totalCommunities'] ?? 0}',
                                      color: theme.secondary,
                                      theme: theme,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_stats != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.article_outlined,
                                      label: 'Gönderiler',
                                      value: '${_stats!['totalPosts'] ?? 0}',
                                      color: theme.warning,
                                      theme: theme,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.person_add_outlined,
                                      label: 'Bu Hafta',
                                      value:
                                          '+${_stats!['newUsersThisWeek'] ?? 0}',
                                      color: theme.error,
                                      theme: theme,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Kayıtlı Kullanıcılar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_users.isEmpty)
                              Center(
                                child: Text(
                                  'Henüz kayıtlı kullanıcı yok.',
                                  style: TextStyle(color: theme.textMuted),
                                ),
                              )
                            else
                              ..._users.map(
                                (u) => _UserTile(
                                  user: u,
                                  theme: theme,
                                  communities: _communities,
                                  onChairman: () => _showChairmanDialog(u),
                                  onDelete: () => _showDeleteConfirm(u),
                                ),
                              ),
                          ],
                        ),
                      ),

                // Tab 2: Şikayetler
                _buildReportsTab(),

                // Tab 3: Ayarlar
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Admin Şifresi',
                      subtitle: 'Admin girişi şifresini görüntüle',
                      color: theme.warning,
                      theme: theme,
                      onTap: _showAdminPasswordDialog,
                    ),
                    _SettingsTile(
                      icon: Icons.people_outline,
                      title: 'Kullanıcıları Yenile',
                      subtitle: 'Kullanıcı listesini güncelle',
                      color: theme.primary,
                      theme: theme,
                      onTap: () {
                        _tabController.animateTo(0);
                        _loadUsers();
                        _loadStats();
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'Uygulama Versiyonu',
                      subtitle: 'NevGenç v1.0.0',
                      color: theme.secondary,
                      theme: theme,
                      onTap: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AppTheme theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: theme.textMuted, fontSize: 13),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AuthUser user;
  final AppTheme theme;
  final List<Topluluk> communities;
  final VoidCallback onChairman;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.theme,
    required this.communities,
    required this.onChairman,
    required this.onDelete,
  });

  Widget _roleChip() {
    final (label, color) = switch (user.role) {
      'admin' => ('Admin', theme.warning),
      'baskan' => ('Başkan', theme.primary),
      _ => ('Öğrenci', theme.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chairmanOf = communities
        .where((c) => c.baskanId == user.id)
        .map((c) => c.ad)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.primary.withValues(alpha: 0.2),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _roleChip(),
                  ],
                ),
                if (chairmanOf.isNotEmpty)
                  Text(
                    'Başkanı: ${chairmanOf.join(', ')}',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  'Kayıt: ${user.createdAt.day}.${user.createdAt.month}.${user.createdAt.year}',
                  style: TextStyle(color: theme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (user.role != 'admin')
            IconButton(
              icon: Icon(
                Icons.manage_accounts_outlined,
                color: theme.primary.withValues(alpha: 0.8),
                size: 20,
              ),
              onPressed: onChairman,
              tooltip: user.isBaskan
                  ? 'Başkanlığı düzenle/kaldır'
                  : 'Başkan yap',
            ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: theme.error.withValues(alpha: 0.7),
              size: 20,
            ),
            onPressed: onDelete,
            tooltip: 'Kullanıcıyı sil',
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final AppTheme theme;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: theme.surface.withValues(alpha: 0.5),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: theme.textMuted, fontSize: 12),
        ),
        trailing: onTap != null
            ? Icon(Icons.arrow_forward_ios, color: theme.textMuted, size: 14)
            : null,
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final AppTheme theme;
  final Future<void> Function(Map<String, dynamic>, String) onAction;

  const _ReportCard({
    required this.report,
    required this.theme,
    required this.onAction,
  });

  String _dateLabel(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day}.${d.month}.${d.year} $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = report['posts'] as Map?;
    final postId = (post?['id'] as num?)?.toInt();
    final community = post?['community_name'] as String? ?? '';
    final content = post?['content'] as String? ?? '';
    final reason = report['reason'] as String? ?? '';
    final createdAt = report['created_at'] as String? ?? '';
    final postStatus = post?['status'] as String? ?? 'published';
    final isHidden = postStatus == 'hidden';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: theme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  community.isEmpty ? 'Bilinmeyen Topluluk' : community,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                _dateLabel(createdAt),
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.length > 120
                ? '${content.substring(0, 120)}...'
                : content,
            style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Gerekçe: $reason',
              style: TextStyle(color: theme.warning, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isHidden && postId != null)
                _ActionChip(
                  label: 'Gönderiyi Gizle',
                  icon: Icons.visibility_off_outlined,
                  color: theme.error,
                  theme: theme,
                  onTap: () => onAction(report, 'hide'),
                ),
              _ActionChip(
                label: 'Değerlendirildi',
                icon: Icons.check_circle_outline,
                color: theme.secondary,
                theme: theme,
                onTap: () => onAction(report, 'reviewed'),
              ),
              _ActionChip(
                label: 'Reddet',
                icon: Icons.close,
                color: theme.textMuted,
                theme: theme,
                onTap: () => onAction(report, 'dismissed'),
              ),
            ],
          ),
          if (isHidden)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ Gönderi zaten gizli',
                style: TextStyle(color: theme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final AppTheme theme;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

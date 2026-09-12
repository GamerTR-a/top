import 'package:flutter/material.dart';
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../theme/app_theme.dart';
import 'community_settings_screen.dart';

class CommunityManagementScreen extends StatefulWidget {
  final Topluluk topluluk;
  final AuthUser currentUser;

  const CommunityManagementScreen({
    super.key,
    required this.topluluk,
    required this.currentUser,
  });

  @override
  State<CommunityManagementScreen> createState() => _CommunityManagementScreenState();
}

class _CommunityManagementScreenState extends State<CommunityManagementScreen>
    with SingleTickerProviderStateMixin {
  final _svc = SupabaseDataService();
  late TabController _tabController;

  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = true;
  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = true;
  Map<String, String> _links = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMembers(),
      _loadPosts(),
      _loadLinks(),
    ]);
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final res = await _svc.getCommunityMembers(widget.topluluk.id);
      if (mounted) {
        setState(() {
          _members = res;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final res = await _svc.getCommunityPosts(widget.topluluk.id);
      if (mounted) {
        setState(() {
          _posts = res;
          _loadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPosts = false);
      }
    }
  }

  Future<void> _loadLinks() async {
    try {
      final res = await _svc.getCommunityLinks(widget.topluluk.id);
      if (mounted) {
        setState(() => _links = res);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunitySettingsScreen(
          topluluk: widget.topluluk,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (result == true) {
      _loadAll(); // Refresh after settings change
    }
  }

  Future<void> _handleRemoveMember(String memberId, String memberName) async {
    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Üyeyi Çıkar', style: TextStyle(color: theme.error, fontWeight: FontWeight.bold)),
        content: Text('"$memberName" üyesini topluluktan çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.error, foregroundColor: Colors.white),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _svc.removeCommunityMember(widget.topluluk.id, memberId);
      _loadMembers();
      if (mounted) _showSnack('$memberName topluluktan çıkarıldı', theme.primary);
    } catch (e) {
      if (mounted) _showSnack('Çıkarma başarısız: $e', theme.error);
    }
  }

  Future<void> _handleDeletePost(int postId) async {
    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Gönderiyi Sil', style: TextStyle(color: theme.error, fontWeight: FontWeight.bold)),
        content: const Text('Bu gönderiyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.error, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _svc.deletePost(postId);
      _loadPosts();
      if (mounted) _showSnack('Gönderi silindi', theme.primary);
    } catch (e) {
      if (mounted) _showSnack('Silme başarısız: $e', theme.error);
    }
  }

  Future<void> _handleHidePost(int postId, String currentStatus) async {
    final newStatus = currentStatus == 'published' ? 'hidden' : 'published';
    try {
      await _svc.setPostStatus(postId, newStatus);
      _loadPosts();
      if (mounted) _showSnack(newStatus == 'hidden' ? 'Gönderi gizlendi' : 'Gönderi yayımlandı', themeNotifier.value.primary);
    } catch (e) {
      if (mounted) _showSnack('İşlem başarısız: $e', themeNotifier.value.error);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
      return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return AnimatedThemeBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: theme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: theme.primary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Topluluk Yönetimi',
                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.settings, color: theme.primary),
                  onPressed: _openSettings,
                  tooltip: 'Ayarlar',
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: theme.primary,
                unselectedLabelColor: theme.textMuted,
                indicatorColor: theme.primary,
                tabs: const [
                  Tab(text: 'Genel'),
                  Tab(text: 'Üyeler'),
                  Tab(text: 'Gönderiler'),
                  Tab(text: 'Linkler'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme),
                _buildMembersTab(theme),
                _buildPostsTab(theme),
                _buildLinksTab(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(AppTheme theme) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: theme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Topluluk kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: theme.primary.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 1)],
                      ),
                      child: ClipOval(
                        child: AppNetworkImage(
                          path: widget.topluluk.logoPath,
                          fit: BoxFit.cover,
                          fallback: () => Icon(Icons.groups, color: theme.primary, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.topluluk.ad, style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(widget.topluluk.kategori, style: TextStyle(color: theme.primary, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.primary.withValues(alpha: 0.4))),
                      child: Text('BAŞKAN', style: TextStyle(color: theme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.topluluk.aciklama.isNotEmpty)
                  Text(widget.topluluk.aciklama, style: TextStyle(color: theme.textColor.withValues(alpha: 0.85), fontSize: 14, height: 1.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _OverviewStat(icon: Icons.people_alt, label: 'Üyeler', value: '${widget.topluluk.uyeSayisi}', color: theme.secondary),
                    const SizedBox(width: 16),
                    _OverviewStat(icon: Icons.article_outlined, label: 'Gönderiler', value: '${_posts.length}', color: theme.primary),
                    const SizedBox(width: 16),
                    _OverviewStat(icon: Icons.star_rounded, label: 'Puan', value: widget.topluluk.puan.toStringAsFixed(1), color: theme.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Hızlı işlemler
          Text('Hızlı İşlemler', style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.edit,
                  label: 'Topluluk Düzenle',
                  subtitle: 'İsim, açıklama, logo, kategori',
                  color: theme.primary,
                  onTap: _openSettings,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.link,
                  label: 'Sohbet Linkleri',
                  subtitle: 'Telegram / Discord',
                  color: theme.secondary,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.people,
                  label: 'Üye Yönetimi',
                  subtitle: 'Listele, çıkar',
                  color: theme.warning,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.article_outlined,
                  label: 'Gönderi Yönetimi',
                  subtitle: 'Gizle, sil',
                  color: theme.error,
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(AppTheme theme) {
    if (_loadingMembers) return Center(child: CircularProgressIndicator(color: theme.primary));
    if (_members.isEmpty) return Center(child: Text('Henüz üye yok', style: TextStyle(color: theme.textMuted)));

    return RefreshIndicator(
      onRefresh: _loadMembers,
      color: theme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final m = _members[index];
          final isChairman = m['user_id'] == widget.topluluk.baskanId;
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
                    (m['name'] as String? ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold),
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
                            child: Text(m['name'] as String? ?? 'Bilinmiyor', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                          ),
                          if (isChairman) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.primary.withValues(alpha: 0.4))),
                              child: Text('BAŞKAN', style: TextStyle(color: theme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text('Katılım: ${_formatDate(m['joined_at'] as String? ?? '')}', style: TextStyle(color: theme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (!isChairman)
                  IconButton(
                    icon: Icon(Icons.person_remove_outlined, color: theme.error.withValues(alpha: 0.7), size: 20),
                    onPressed: () => _handleRemoveMember(m['user_id'] as String, m['name'] as String? ?? 'Üye'),
                    tooltip: 'Üyeyi çıkar',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsTab(AppTheme theme) {
    if (_loadingPosts) return Center(child: CircularProgressIndicator(color: theme.primary));
    if (_posts.isEmpty) return Center(child: Text('Henüz gönderi yok', style: TextStyle(color: theme.textMuted)));

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: theme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final p = _posts[index];
          final isHidden = p['status'] == 'hidden';
          final content = p['content'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isHidden ? theme.error.withValues(alpha: 0.3) : theme.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        content.length > 80 ? '${content.substring(0, 80)}...' : content,
                        style: TextStyle(color: theme.textColor, fontSize: 13, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isHidden ? theme.error.withValues(alpha: 0.15) : theme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isHidden ? theme.error.withValues(alpha: 0.4) : theme.secondary.withValues(alpha: 0.4)),
                      ),
                      child: Text(isHidden ? 'GİZLİ' : 'YAYINDA', style: TextStyle(color: isHidden ? theme.error : theme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(_formatDate(p['created_at'] as String? ?? ''), style: TextStyle(color: theme.textMuted, fontSize: 11)),
                    const SizedBox(width: 16),
                    if ((p['support_count'] as num?) != null)
                      Row(
                        children: [
                          Icon(Icons.thumb_up_outlined, size: 12, color: theme.primary),
                          const SizedBox(width: 3),
                          Text('${p['support_count']}', style: TextStyle(color: theme.primary, fontSize: 11)),
                        ],
                      ),
                    if ((p['rating_avg'] as num?) != null && (p['rating_avg'] as num?)! > 0) ...[
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 12, color: theme.warning),
                          const SizedBox(width: 3),
                          Text((p['rating_avg'] as num).toStringAsFixed(1), style: TextStyle(color: theme.warning, fontSize: 11)),
                        ],
                      ),
                    ],
                    const Spacer(),
                    if (!isHidden)
                      TextButton.icon(
                        icon: Icon(Icons.visibility_off_outlined, size: 14, color: theme.error),
                        label: Text('Gizle', style: TextStyle(color: theme.error, fontSize: 12)),
                        onPressed: () => _handleHidePost(p['id'] as int, p['status'] as String? ?? 'published'),
                      )
                    else
                      TextButton.icon(
                        icon: Icon(Icons.visibility_outlined, size: 14, color: theme.secondary),
                        label: Text('Yayımla', style: TextStyle(color: theme.secondary, fontSize: 12)),
                        onPressed: () => _handleHidePost(p['id'] as int, p['status'] as String? ?? 'hidden'),
                      ),
                    TextButton.icon(
                      icon: Icon(Icons.delete_outline, size: 14, color: theme.error),
                      label: Text('Sil', style: TextStyle(color: theme.error, fontSize: 12)),
                      onPressed: () => _handleDeletePost(p['id'] as int),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinksTab(AppTheme theme) {
    final platforms = ['telegram', 'discord'];
    final icons = {'telegram': Icons.telegram, 'discord': Icons.discord};
    final colors = {'telegram': const Color(0xFF0088CC), 'discord': const Color(0xFF5865F2)};

    return RefreshIndicator(
      onRefresh: _loadLinks,
      color: theme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sohbet Linkleri', style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Topluluk üyeleri bu linklerle harici sohbetlere yönlendirilir.', style: TextStyle(color: theme.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          ...platforms.map((platform) {
            final url = _links[platform];
            final hasLink = url != null && url.isNotEmpty;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors[platform]!.withValues(alpha: hasLink ? 0.5 : 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(color: colors[platform]!.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(icons[platform], color: colors[platform], size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(platform.toUpperCase(), style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                            if (hasLink) ...[
                              const SizedBox(height: 2),
                              Text(url, style: TextStyle(color: theme.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      if (hasLink)
                        IconButton(
                          icon: Icon(Icons.copy, color: theme.textMuted, size: 20),
                          onPressed: () {
                            // Clipboard copy would go here
                            _showSnack('Link kopyalandı', theme.primary);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasLink) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.edit, size: 16, color: theme.primary),
                            label: Text('Düzenle', style: TextStyle(color: theme.primary, fontSize: 12)),
                            onPressed: () => _editLinkDialog(platform, url),
                            style: OutlinedButton.styleFrom(side: BorderSide(color: theme.primary.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.delete_outline, size: 16, color: Colors.white),
                            label: Text('Kaldır', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () => _removeLink(platform),
                            style: ElevatedButton.styleFrom(backgroundColor: theme.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add_link, size: 18, color: Colors.white),
                        label: Text('Link Ekle', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _editLinkDialog(platform, ''),
                        style: ElevatedButton.styleFrom(backgroundColor: colors[platform], padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Text('Not: Linkler https:// ile başlamalıdır.', style: TextStyle(color: theme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _editLinkDialog(String platform, String currentUrl) async {
    final theme = themeNotifier.value;
    final ctrl = TextEditingController(text: currentUrl);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$platform Linki ${currentUrl.isEmpty ? 'Ekle' : 'Düzenle'}', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: theme.textMuted),
            filled: true,
            fillColor: theme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white),
            child: Text(currentUrl.isEmpty ? 'Ekle' : 'Kaydet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final url = ctrl.text.trim();
    if (url.isEmpty) {
      await _removeLink(platform);
    } else if (!url.startsWith('https://')) {
      _showSnack('Link https:// ile başlamalı', theme.error);
    } else {
      try {
        await _svc.setCommunityLink(widget.topluluk.id, platform, url);
        _loadLinks();
        _showSnack('$platform linki güncellendi', theme.primary);
      } catch (e) {
        _showSnack('Güncelleme başarısız: $e', theme.error);
      }
    }
  }

  Future<void> _removeLink(String platform) async {
    try {
      await _svc.removeCommunityLink(widget.topluluk.id, platform);
      _loadLinks();
      _showSnack('$platform linki kaldırıldı', themeNotifier.value.primary);
    } catch (e) {
      _showSnack('Kaldırma başarısız: $e', themeNotifier.value.error);
    }
  }
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _OverviewStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
            Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
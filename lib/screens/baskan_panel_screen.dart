import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';


class BaskanPanelScreen extends StatefulWidget {
  final Topluluk? initialTopluluk;

  const BaskanPanelScreen({
    super.key,
    this.initialTopluluk,
  });

  @override
  State<BaskanPanelScreen> createState() => _BaskanPanelScreenState();
}

class _BaskanPanelScreenState extends State<BaskanPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = SupabaseDataService();

  List<Topluluk> _myCommunities = [];
  Topluluk? _selectedCommunity;
  bool _loadingCommunities = true;

  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = false;
  String _memberSearchQuery = '';

  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = false;

  final _whatsappCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  bool _savingLinks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _whatsappCtrl.dispose();
    _telegramCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .single();
      final role = profile['role'] as String? ?? 'student';
      if (role != 'baskan' && role != 'admin' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu panele erişim yetkiniz yok.')),
        );
        Navigator.pop(context);
        return;
      }

      if (widget.initialTopluluk != null) {
        _myCommunities = [widget.initialTopluluk!];
        _selectedCommunity = widget.initialTopluluk!;
      } else {
        var communities = await _api.getCommunitiesForBaskan(uid);
        if (communities.isEmpty && role == 'admin') {
          communities = await _api.getTopluluklarForAdmin();
        }
        _myCommunities = communities;
        if (communities.isNotEmpty) {
          _selectedCommunity = communities.first;
        }
      }

      if (mounted) {
        setState(() => _loadingCommunities = false);
        if (_selectedCommunity != null) {
          _loadCommunityDetails(_selectedCommunity!.id);
        }
      }
    } catch (e) {
      debugPrint('[BaskanPanel] Yetki kontrolü veya yükleme hatası: $e');
      if (mounted) setState(() => _loadingCommunities = false);
    }
  }

  Future<void> _loadCommunityDetails(int communityId) async {
    _loadMembers(communityId);
    _loadPosts(communityId);
    _loadLinks(communityId);
  }

  Future<void> _loadMembers(int communityId) async {
    setState(() => _loadingMembers = true);
    try {
      final res = await _api.getCommunityMembers(communityId);
      if (mounted) {
        setState(() {
          _members = res;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadPosts(int communityId) async {
    setState(() => _loadingPosts = true);
    try {
      final res = await _api.getCommunityPosts(communityId);
      if (mounted) {
        setState(() {
          _posts = res;
          _loadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _loadLinks(int communityId) async {
    try {
      final res = await _api.getCommunityLinks(communityId);
      if (mounted) {
        setState(() {
          _whatsappCtrl.text = res['whatsapp'] ?? '';
          _telegramCtrl.text = res['telegram'] ?? '';
          _instagramCtrl.text = res['instagram'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _removeMember(String userId, String name) async {
    if (_selectedCommunity == null) return;
    final theme = themeNotifier.value;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Üyeyi Çıkar', style: TextStyle(color: theme.textColor)),
        content: Text(
          '"$name" adlı kullanıcıyı topluluktan çıkarmak istediğinize emin misiniz?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.removeCommunityMember(_selectedCommunity!.id, userId);
      _loadMembers(_selectedCommunity!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name topluluktan çıkarıldı.'),
            backgroundColor: theme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: theme.error),
        );
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    if (_selectedCommunity == null) return;
    final theme = themeNotifier.value;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Gönderiyi Sil', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Bu gönderiyi topluluk akışından silmek istediğinize emin misiniz?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.deletePost(postId);
      _loadPosts(_selectedCommunity!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Gönderi silindi.'), backgroundColor: theme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: theme.error),
        );
      }
    }
  }

  Future<void> _saveLinks() async {
    if (_selectedCommunity == null) return;
    final theme = themeNotifier.value;
    setState(() => _savingLinks = true);

    try {
      final updatedLinks = {
        'whatsapp': _whatsappCtrl.text.trim(),
        'telegram': _telegramCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
      };
      await _api.updateCommunityLinks(_selectedCommunity!.id, updatedLinks);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bağlantılar başarıyla kaydedildi.'),
            backgroundColor: theme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: theme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingLinks = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    final theme = themeNotifier.value;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label kopyalandı: $text'),
        backgroundColor: theme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAllEmails(List<Map<String, dynamic>> filteredMembers) {
    final theme = themeNotifier.value;
    final emails = filteredMembers
        .map((m) {
          final profile = m['profiles'] as Map<String, dynamic>?;
          return profile?['email'] as String? ?? '';
        })
        .where((e) => e.isNotEmpty)
        .toList();

    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kopyalanacak e-posta adresi bulunamadı.'),
          backgroundColor: theme.warning,
        ),
      );
      return;
    }

    final joinedStr = emails.join(', ');
    Clipboard.setData(ClipboardData(text: joinedStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${emails.length} adet e-posta adresi panoya kopyalandı! 📋'),
        backgroundColor: theme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: theme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Başkan Paneli',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedThemeBackground(
          child: _loadingCommunities
              ? Center(child: CircularProgressIndicator(color: theme.primary))
              : _myCommunities.isEmpty
                  ? _buildNoCommunityView(theme)
                  : Column(
                      children: [
                        _buildTopHeaderCard(theme),
                        TabBar(
                          controller: _tabController,
                          indicatorColor: theme.primary,
                          labelColor: theme.primary,
                          unselectedLabelColor: theme.textMuted,
                          tabs: const [
                            Tab(icon: Icon(Icons.people_outline), text: 'Üyeler & Mailler'),
                            Tab(icon: Icon(Icons.article_outlined), text: 'Gönderiler'),
                            Tab(icon: Icon(Icons.link_outlined), text: 'Bağlantılar'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMembersTab(theme),
                              _buildPostsTab(theme),
                              _buildLinksTab(theme),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildNoCommunityView(AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_outlined, size: 64, color: theme.textMuted),
            const SizedBox(height: 16),
            Text(
              'Atanmış Topluluk Bulunamadı',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hesabınıza atanmış bir topluluk başkanlığı bulunmuyor. Sistem yöneticiniz ile iletişime geçin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard(AppTheme theme) {
    final sel = _selectedCommunity!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.primary, width: 2),
                ),
                child: ClipOval(
                  child: AppNetworkImage(
                    path: sel.logoPath,
                    fit: BoxFit.cover,
                    fallback: () => Icon(Icons.groups, color: theme.primary, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_myCommunities.length > 1)
                      DropdownButton<int>(
                        value: sel.id,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: theme.surface,
                        underline: const SizedBox(),
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        items: _myCommunities.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.ad),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            setState(() {
                              _selectedCommunity = _myCommunities.firstWhere((c) => c.id == newId);
                            });
                            _loadCommunityDetails(newId);
                          }
                        },
                      )
                    else
                      Text(
                        sel.ad,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sel.kategori,
                            style: TextStyle(
                              color: theme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star_rounded, color: theme.warning, size: 16),
                        Text(
                          ' ${sel.puan.toStringAsFixed(1)} Puan',
                          style: TextStyle(color: theme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1. ÜYELER VE E-POSTALAR TABI ──────────────────────────────────────────
  Widget _buildMembersTab(AppTheme theme) {
    if (_loadingMembers) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    final query = _memberSearchQuery.toLowerCase().trim();
    final filtered = _members.where((m) {
      final profile = m['profiles'] as Map<String, dynamic>?;
      if (profile == null) return false;
      final name = (profile['name'] as String? ?? '').toLowerCase();
      final email = (profile['email'] as String? ?? '').toLowerCase();
      final dept = (profile['department'] as String? ?? '').toLowerCase();
      return query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          dept.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Arama çubuğu ve Tüm Mailleri Kopyala Butonu
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _memberSearchQuery = val),
                  style: TextStyle(color: theme.textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Üye adı, e-posta veya bölüm ara...',
                    hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: theme.primary, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: theme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _copyAllEmails(filtered),
                icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                label: const Text(
                  'Tüm Mailler',
                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toplam Üye Sayacı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Topluluk Üyeleri (${filtered.length} Kişi)',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'E-Postaları kopyalamak için tıklayın',
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Üye Kartları Listesi
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Üye bulunamadı.',
                      style: TextStyle(color: theme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      final profile = item['profiles'] as Map<String, dynamic>? ?? {};
                      final userId = profile['id'] as String? ?? item['user_id'] as String;
                      final name = profile['name'] as String? ?? 'İsimsiz Üye';
                      final email = profile['email'] as String? ?? 'E-posta Yok';
                      final photo = profile['profile_photo'] as String?;
                      final dept = profile['department'] as String?;
                      final role = profile['role'] as String? ?? 'student';
                      final joinedAtRaw = item['joined_at'] as String?;

                      String joinedDateStr = '';
                      if (joinedAtRaw != null) {
                        try {
                          final dt = DateTime.parse(joinedAtRaw);
                          joinedDateStr = '${dt.day}.${dt.month}.${dt.year}';
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.primary.withValues(alpha: 0.2),
                                  child: photo != null && photo.isNotEmpty
                                      ? ClipOval(
                                          child: AppNetworkImage(
                                            path: photo,
                                            fit: BoxFit.cover,
                                            fallback: () => Icon(
                                              Icons.person,
                                              color: theme.primary,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Icon(Icons.person, color: theme.primary, size: 20),
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
                                              name,
                                              style: TextStyle(
                                                color: theme.textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (role == 'baskan' || role == 'admin')
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.secondary.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                role == 'admin' ? 'Admin' : 'Başkan',
                                                style: TextStyle(
                                                  color: theme.secondary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (dept != null && dept.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          dept,
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.person_remove_outlined, color: theme.error, size: 20),
                                  tooltip: 'Üyeyi Çıkar',
                                  onPressed: () => _removeMember(userId, name),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                            // E-Posta Alanı (Vurgulu ve Kopyala Butonlu)
                            InkWell(
                              onTap: () => _copyToClipboard(email, 'E-posta'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.primary.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.email_outlined, size: 16, color: theme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.copy, size: 14, color: theme.primary),
                                  ],
                                ),
                              ),
                            ),
                            if (joinedDateStr.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  'Katılım Tarihi: $joinedDateStr',
                                  style: TextStyle(color: theme.textMuted, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEventParticipantsModal(int postId, String content) async {
    final theme = themeNotifier.value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _api.getEventParticipants(postId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: theme.primary)),
              );
            }
            final participants = snapshot.data ?? [];

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.textMuted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.event_available, color: theme.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Etkinlik Katılımcıları (${participants.length})',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (participants.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _copyAllEmails(participants),
                      icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                      label: const Text(
                        'Tüm Katılımcı Maillerini Kopyala 📋',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: participants.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz bu etkinliğe katılan öğrenci yok.',
                              style: TextStyle(color: theme.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: participants.length,
                            itemBuilder: (ctx, idx) {
                              final item = participants[idx];
                              final profile = item['profiles'] as Map<String, dynamic>? ?? {};
                              final name = profile['name'] as String? ?? 'Öğrenci';
                              final email = profile['email'] as String? ?? '';
                              final dept = profile['department'] as String?;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.background.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.primary.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: theme.primary.withValues(alpha: 0.2),
                                      child: Icon(Icons.person, color: theme.primary, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: theme.textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (dept != null && dept.isNotEmpty)
                                            Text(
                                              dept,
                                              style: TextStyle(color: theme.textMuted, fontSize: 11),
                                            ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              color: theme.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, color: theme.primary, size: 18),
                                      onPressed: () => _copyToClipboard(email, 'E-posta'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── 2. GÖNDERİLER VE MODERASYON TABI ──────────────────────────────────────
  Widget _buildPostsTab(AppTheme theme) {
    if (_loadingPosts) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topluluk Akış Gönderileri (${_posts.length})',
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _posts.isEmpty
                ? Center(
                    child: Text(
                      'Bu topluluğa henüz gönderi paylaşılmamış.',
                      style: TextStyle(color: theme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (ctx, index) {
                      final p = _posts[index];
                      final postId = (p['id'] as num).toInt();
                      final content = p['content'] as String? ?? '';
                      final createdAt = p['created_at'] as String? ?? '';
                      final imageUrl = p['image_url'] as String?;
                      final isEvent = p['is_event'] as bool? ?? false;

                      return Card(
                        color: theme.surface,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.primary.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: AppNetworkImage(
                                          path: imageUrl,
                                          fit: BoxFit.cover,
                                          fallback: () => Container(
                                            width: 50,
                                            height: 50,
                                            color: theme.primary.withValues(alpha: 0.1),
                                            child: Icon(Icons.image, color: theme.primary),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          content,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.textColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          createdAt,
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: theme.error, size: 20),
                                    onPressed: () => _deletePost(postId),
                                  ),
                                ],
                              ),
                              if (isEvent) ...[
                                const Divider(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showEventParticipantsModal(postId, content),
                                    icon: Icon(Icons.people_outline, color: theme.primary, size: 18),
                                    label: Text(
                                      'Etkinlik Katılımcıları & Mailleri 📋',
                                      style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: theme.primary.withValues(alpha: 0.4)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }


  // ── 3. SOSYAL BAĞLANTILAR VE AYARLAR TABI ────────────────────────────────
  Widget _buildLinksTab(AppTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topluluk İletişim Bağlantıları',
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Üyelerinize sunulacak sosyal medya ve iletişim gruplarının linklerini güncelleyin.',
            style: TextStyle(color: theme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _buildLinkField(
            controller: _whatsappCtrl,
            label: 'WhatsApp Grubu Linki',
            icon: Icons.chat_bubble_outline,
            hint: 'https://chat.whatsapp.com/...',
            theme: theme,
          ),
          const SizedBox(height: 14),
          _buildLinkField(
            controller: _telegramCtrl,
            label: 'Telegram Grubu Linki',
            icon: Icons.send_outlined,
            hint: 'https://t.me/...',
            theme: theme,
          ),
          const SizedBox(height: 14),
          _buildLinkField(
            controller: _instagramCtrl,
            label: 'Instagram Sayfası Linki',
            icon: Icons.camera_alt_outlined,
            hint: 'https://instagram.com/...',
            theme: theme,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _savingLinks ? null : _saveLinks,
              icon: _savingLinks
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Bağlantıları Kaydet',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required AppTheme theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: theme.textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: theme.primary, size: 20),
            filled: true,
            fillColor: theme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

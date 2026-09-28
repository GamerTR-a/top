import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_user_model.dart' show departmentText;
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../utils/secure_screen.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import 'baskan_panel/members_tab.dart';
import 'baskan_panel/posts_tab.dart';
import 'baskan_panel/links_tab.dart';
import 'baskan_panel/notify_tab.dart';


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

  final _notifTitleCtrl = TextEditingController();
  final _notifBodyCtrl = TextEditingController();
  final Set<String> _selectedRecipientIds = {};
  bool _sendingNotification = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Üye e-posta listesi görev değiştirici önizlemesinde/ekran görüntüsünde
    // görünmesin (bkz. kontrol.md Bölüm 7 — FLAG_SECURE).
    SecureScreen.enable();
    _initData();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _tabController.dispose();
    _whatsappCtrl.dispose();
    _telegramCtrl.dispose();
    _instagramCtrl.dispose();
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
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
    _selectedRecipientIds.clear();
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
          tooltip: 'Geri',
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
                          isScrollable: true,
                          tabs: const [
                            Tab(icon: Icon(Icons.people_outline), text: 'Üyeler & Mailler'),
                            Tab(icon: Icon(Icons.article_outlined), text: 'Gönderiler'),
                            Tab(icon: Icon(Icons.link_outlined), text: 'Bağlantılar'),
                            Tab(icon: Icon(Icons.campaign_outlined), text: 'Bildirim Gönder'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              MembersTab(
                                theme: theme,
                                loading: _loadingMembers,
                                members: _members,
                                searchQuery: _memberSearchQuery,
                                onSearchChanged: (val) =>
                                    setState(() => _memberSearchQuery = val),
                                onCopyAllEmails: _copyAllEmails,
                                onRemoveMember: _removeMember,
                                onCopyToClipboard: _copyToClipboard,
                              ),
                              PostsTab(
                                theme: theme,
                                loading: _loadingPosts,
                                posts: _posts,
                                onDeletePost: _deletePost,
                                onShowEventParticipants:
                                    _showEventParticipantsModal,
                              ),
                              LinksTab(
                                theme: theme,
                                whatsappController: _whatsappCtrl,
                                telegramController: _telegramCtrl,
                                instagramController: _instagramCtrl,
                                saving: _savingLinks,
                                onSave: _saveLinks,
                              ),
                              NotifyTab(
                                theme: theme,
                                loadingMembers: _loadingMembers,
                                members: _members,
                                selectedCommunityName: _selectedCommunity?.ad,
                                selectedRecipientIds: _selectedRecipientIds,
                                onToggleRecipient: _toggleRecipient,
                                onToggleSelectAll: _toggleSelectAllRecipients,
                                titleController: _notifTitleCtrl,
                                bodyController: _notifBodyCtrl,
                                sending: _sendingNotification,
                                onSend: _confirmAndSendNotification,
                              ),
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
                              final dept = departmentText(profile['department']);

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
                                      tooltip: 'E-postayı Kopyala',
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



  // ── NotifyTab (bkz. baskan_panel/notify_tab.dart) için seçim yardımcıları ──
  void _toggleRecipient(String userId, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecipientIds.add(userId);
      } else {
        _selectedRecipientIds.remove(userId);
      }
    });
  }

  void _toggleSelectAllRecipients() {
    final allIds = _members
        .map((m) {
          final profile = m['profiles'] as Map<String, dynamic>?;
          return profile?['id'] as String? ?? m['user_id'] as String?;
        })
        .whereType<String>()
        .toSet();
    final allSelected =
        allIds.isNotEmpty && _selectedRecipientIds.length == allIds.length;
    setState(() {
      if (allSelected) {
        _selectedRecipientIds.clear();
      } else {
        _selectedRecipientIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _confirmAndSendNotification() async {
    final theme = themeNotifier.value;
    final title = _notifTitleCtrl.text.trim();
    final body = _notifBodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Başlık ve mesaj zorunludur.'), backgroundColor: theme.error),
      );
      return;
    }
    if (_selectedRecipientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('En az bir alıcı seçmelisin.'), backgroundColor: theme.error),
      );
      return;
    }
    if (_selectedCommunity == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Gönderimi Onayla', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedRecipientIds.length} üyeye bildirim gönderilecek:',
              style: TextStyle(color: theme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(color: theme.textColor.withValues(alpha: 0.85), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sendingNotification = true);
    try {
      final res = await _api.sendCommunityNotification(
        communityId: _selectedCommunity!.id,
        title: title,
        body: body,
        recipientIds: _selectedRecipientIds.toList(),
      );
      final sentCount = (res['sent_count'] as num?)?.toInt() ?? _selectedRecipientIds.length;
      if (!mounted) return;
      _notifTitleCtrl.clear();
      _notifBodyCtrl.clear();
      setState(() {
        _selectedRecipientIds.clear();
        _sendingNotification = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bildirim $sentCount üyeye gönderildi. 📨'),
          backgroundColor: theme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderilemedi: $e'), backgroundColor: theme.error),
      );
    }
  }
}

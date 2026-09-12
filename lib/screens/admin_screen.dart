import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../models/auth_user_model.dart';
import '../models/ticket_model.dart';
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
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
  String _communitySearch = '';
  List<UserTicket> _tickets = [];
  bool _loadingTickets = true;
  String? _ticketStatusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _loadingTickets = true);
    try {
      final tickets = await _api.getAllTickets(status: _ticketStatusFilter);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loadingTickets = false;
      });
    } catch (e) {
      debugPrint('[Admin] Talepler yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _loadingTickets = false);
    }
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

  Widget _buildTicketsTab() {
    final theme = themeNotifier.value;
    if (_loadingTickets) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }
    return Column(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('Tümü', null, theme),
              const SizedBox(width: 8),
              _buildFilterChip('Açık', 'open', theme),
              const SizedBox(width: 8),
              _buildFilterChip('İşlemde', 'in_progress', theme),
              const SizedBox(width: 8),
              _buildFilterChip('Çözüldü', 'resolved', theme),
              const SizedBox(width: 8),
              _buildFilterChip('Kapalı', 'closed', theme),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 56, color: theme.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _ticketStatusFilter == null ? 'Henüz talep yok 🎉' : 'Bu durumda talep yok',
                        style: TextStyle(color: theme.textMuted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTickets,
                  color: theme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) => _TicketCard(
                      ticket: _tickets[index],
                      theme: theme,
                      onStatusChanged: _handleTicketStatusChange,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? status, AppTheme theme) {
    final isSelected = _ticketStatusFilter == status;
    final color = _getStatusColor(status);
    return FilterChip(
      selected: isSelected,
      onSelected: (_) async {
        setState(() => _ticketStatusFilter = status);
        await _loadTickets();
      },
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : theme.textMuted,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selectedColor: color.withValues(alpha: 0.3),
      backgroundColor: theme.surface.withValues(alpha: 0.5),
      checkmarkColor: color,
      side: BorderSide(color: isSelected ? color : theme.primary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'open': return const Color(0xFF2196F3);
      case 'in_progress': return const Color(0xFFFF9800);
      case 'resolved': return const Color(0xFF4CAF50);
      case 'closed': return const Color(0xFF9E9E9E);
      default: return const Color(0xFF9D4EDD);
    }
  }

  Future<void> _handleTicketStatusChange(UserTicket ticket, String newStatus) async {
    try {
      await _api.updateTicketStatus(ticketId: ticket.id, status: newStatus, adminNotes: ticket.adminNotes);
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep durumu güncellendi: ${_getStatusDisplayName(newStatus)}'), backgroundColor: themeNotifier.value.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        );
      }
    } catch (e) {
      debugPrint('[Admin] Talep durumu güncellenemedi: $e');
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'open': return 'Açık';
      case 'in_progress': return 'İşlemde';
      case 'resolved': return 'Çözüldü';
      case 'closed': return 'Kapalı';
      default: return status;
    }
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

  Widget _buildCommunitiesTab() {
    final theme = themeNotifier.value;
    final searchLower = _communitySearch.toLowerCase().trim();
    final filtered = _communities.where((c) {
      if (searchLower.isEmpty) return true;
      return c.ad.toLowerCase().contains(searchLower) ||
          c.kategori.toLowerCase().contains(searchLower) ||
          c.baskanAdi.toLowerCase().contains(searchLower);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadCommunities,
      color: theme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Üst İstatistik & Yeni Topluluk Butonu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplam Topluluk',
                        style: TextStyle(color: theme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_communities.length} Aktif Topluluk',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateCommunityDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Yeni Topluluk Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Arama Arayüzü
          TextField(
            onChanged: (v) => setState(() => _communitySearch = v),
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: 'Topluluk adı, kategori veya başkan ara...',
              hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: theme.primary),
              filled: true,
              fillColor: theme.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  _communitySearch.isEmpty
                      ? 'Henüz kaydedilmiş topluluk yok.'
                      : 'Aramanızla eşleşen topluluk bulunamadı.',
                  style: TextStyle(color: theme.textMuted),
                ),
              ),
            )
          else
            ...filtered.map((c) => _AdminCommunityTile(
                  topluluk: c,
                  theme: theme,
                  onEdit: () => _showEditCommunityDialog(c),
                  onDelete: () => _showDeleteCommunityDialog(c),
                )),
        ],
      ),
    );
  }

  Future<void> _showCreateCommunityDialog() async {
    final theme = themeNotifier.value;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'Teknoloji';
    File? pickedImage;
    String? selectedChairmanId;
    bool isSubmitting = false;

    const categories = [
      'Teknoloji',
      'Mühendislik',
      'Bilim',
      'Sosyal',
      'Sosyal Sorumluluk',
      'Sanat & Müzik',
      'Kültür',
      'Spor',
      'Doğa & Gezi',
      'Kariyer',
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.add_business_rounded, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'Yeni Topluluk Oluştur',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Seçici
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final xfile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 80,
                          );
                          if (xfile != null) {
                            setDialogState(() {
                              pickedImage = File(xfile.path);
                            });
                          }
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: theme.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: pickedImage != null
                                    ? Image.file(pickedImage!, fit: BoxFit.cover)
                                    : Center(
                                        child: Icon(
                                          Icons.add_a_photo_outlined,
                                          color: theme.primary,
                                          size: 32,
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Topluluk Logosu Seç (İsteğe Bağlı)',
                        style: TextStyle(color: theme.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 16),

                      // Topluluk Adı
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(color: theme.textColor),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Topluluk adı giriniz'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Topluluk Adı *',
                          hintText: 'Örn: Yazılım ve Yapay Zeka Kulübü',
                          hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Kategori
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        style: TextStyle(color: theme.textColor),
                        dropdownColor: theme.surface,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: categories
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            selectedCategory = v;
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Topluluk Hakkında / Açıklama
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: TextStyle(color: theme.textColor),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Topluluk hakkında bilgi giriniz'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Topluluk Hakkında (Açıklama) *',
                          hintText: 'Topluluk amaçları, faaliyetleri...',
                          hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Başkan Atama (Opsiyonel)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedChairmanId,
                        style: TextStyle(color: theme.textColor),
                        dropdownColor: theme.surface,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Başkan Ata (Opsiyonel)',
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Şimdilik Başkan Atama'),
                          ),
                          for (final u in _users)
                            DropdownMenuItem<String?>(
                              value: u.id,
                              child: Text(
                                '${u.name} (${u.role})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setDialogState(() => selectedChairmanId = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text('İptal', style: TextStyle(color: theme.textMuted)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          String? logoUrl;
                          if (pickedImage != null) {
                            logoUrl = await _api.uploadPostImage(pickedImage!);
                          }

                          String? chairmanName;
                          if (selectedChairmanId != null) {
                            final chairmanUser = _users.firstWhere(
                              (u) => u.id == selectedChairmanId,
                            );
                            chairmanName = chairmanUser.name;
                          }

                          final created = await _api.createCommunity(
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            category: selectedCategory,
                            logoPath: logoUrl,
                            chairmanId: selectedChairmanId,
                            chairmanName: chairmanName,
                          );

                          if (selectedChairmanId != null && chairmanName != null) {
                            await _api.assignChairman(
                              userId: selectedChairmanId!,
                              userName: chairmanName,
                              communityId: created.id,
                            );
                          }

                          await _loadCommunities();
                          await _loadStats();
                          await _loadUsers();

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              _snack(
                                '✨ "${created.ad}" topluluğu başarıyla oluşturuldu!',
                                theme.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[Admin] Topluluk oluşturma hatası: $e');
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              _snack('Topluluk oluşturulamadı: $e', theme.error),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Topluluk Oluştur ✨'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditCommunityDialog(Topluluk c) async {
    final theme = themeNotifier.value;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: c.ad);
    final descCtrl = TextEditingController(text: c.aciklama);
    String selectedCategory = c.kategori;
    File? pickedImage;
    bool isSubmitting = false;

    const categories = [
      'Teknoloji',
      'Mühendislik',
      'Bilim',
      'Sosyal',
      'Sosyal Sorumluluk',
      'Sanat & Müzik',
      'Kültür',
      'Spor',
      'Doğa & Gezi',
      'Kariyer',
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'Topluluğu Düzenle',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final xfile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 80,
                          );
                          if (xfile != null) {
                            setDialogState(() {
                              pickedImage = File(xfile.path);
                            });
                          }
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: theme.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: pickedImage != null
                                    ? Image.file(pickedImage!, fit: BoxFit.cover)
                                    : AppNetworkImage(
                                        path: c.logoPath,
                                        fit: BoxFit.cover,
                                        fallback: () => Icon(
                                          Icons.groups,
                                          color: theme.primary,
                                          size: 32,
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Logo Değiştir (İsteğe Bağlı)',
                        style: TextStyle(color: theme.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(color: theme.textColor),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Topluluk adı giriniz'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Topluluk Adı *',
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: categories.contains(selectedCategory)
                            ? selectedCategory
                            : categories.first,
                        style: TextStyle(color: theme.textColor),
                        dropdownColor: theme.surface,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: categories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedCategory = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: TextStyle(color: theme.textColor),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Topluluk hakkında bilgi giriniz'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Topluluk Hakkında (Açıklama) *',
                          filled: true,
                          fillColor: theme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text('İptal', style: TextStyle(color: theme.textMuted)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          String? logoUrl;
                          if (pickedImage != null) {
                            logoUrl = await _api.uploadPostImage(pickedImage!);
                          }

                          await _api.updateCommunityDetails(
                            communityId: c.id,
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            category: selectedCategory,
                            logoPath: logoUrl,
                          );

                          await _loadCommunities();

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              _snack(
                                'Topluluk bilgileri güncellendi ✅',
                                theme.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              _snack('Güncelleme başarısız: $e', theme.error),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteCommunityDialog(Topluluk c) async {
    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Topluluğu Sil',
          style: TextStyle(color: theme.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${c.ad}" topluluğunu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteCommunity(c.id);
      await _loadCommunities();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snack('${c.ad} silindi.', theme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snack('Silme başarısız: $e', theme.error),
        );
      }
    }
  }

  Future<void> _showSendUpdateNotificationDialog() async {
    final theme = themeNotifier.value;
    final titleCtrl = TextEditingController(text: 'NevGenç Yeni Sürüm Yayınlandı! 🚀');
    final versionCtrl = TextEditingController(text: 'v1.0.25');
    final notesCtrl = TextEditingController(
      text: 'Uygulamamız güncellendi! Yeni özellikler, performans iyileştirmeleri ve hata düzeltmeleri eklendi.',
    );
    final linkCtrl = TextEditingController();
    bool sending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'Güncelleme Bildirimi',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tüm kullanıcılara yeni sürüm duyurusu bildirimi gönderin.',
                    style: TextStyle(color: theme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Bildirim Başlığı *',
                      filled: true,
                      fillColor: theme.background.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: versionCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Sürüm Numarası (Örn: v1.0.25) *',
                      filled: true,
                      fillColor: theme.background.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Güncelleme Açıklaması / Yenilikler *',
                      filled: true,
                      fillColor: theme.background.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'İndirme / Mağaza Bağlantısı (Opsiyonel)',
                      hintText: 'https://play.google.com/store/apps/details?...',
                      hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5), fontSize: 12),
                      filled: true,
                      fillColor: theme.background.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: Text('İptal', style: TextStyle(color: theme.textMuted)),
            ),
            ElevatedButton.icon(
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(sending ? 'Gönderiliyor...' : 'Bildirimi Gönder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final version = versionCtrl.text.trim();
                      final notes = notesCtrl.text.trim();
                      final link = linkCtrl.text.trim();

                      if (title.isEmpty || notes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          _snack('Lütfen başlık ve açıklama alanlarını doldurun.', theme.error),
                        );
                        return;
                      }

                      setDialogState(() => sending = true);
                      try {
                        await _api.sendUpdateAnnouncement(
                          title: title,
                          message: notes,
                          version: version.isNotEmpty ? version : null,
                          storeUrl: link.isNotEmpty ? link : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            _snack('🚀 Güncelleme bildirimi tüm kullanıcılara gönderildi!', theme.primary),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            _snack('Bildirim gönderilemedi: $e', theme.error),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
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
            title: Text(
              'Admin Paneli 👑',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.campaign_rounded),
                tooltip: 'Güncelleme Duyurusu Yap',
                color: theme.primary,
                onPressed: _showSendUpdateNotificationDialog,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: theme.primary,
              unselectedLabelColor: theme.textMuted,
              indicatorColor: theme.primary,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Kullanıcılar'),
                Tab(text: 'Topluluklar'),
                Tab(text: 'Şikayetler'),
                Tab(text: 'Talepler'),
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
                                color: theme.textColor,
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

                // Tab 2: Topluluklar
                _buildCommunitiesTab(),

                // Tab 2: Şikayetler
                _buildReportsTab(),

                // Tab 3: Talepler (user_tickets)
                _buildTicketsTab(),

                // Tab 4: Ayarlar
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SettingsTile(
                      icon: Icons.system_update_rounded,
                      title: 'Güncelleme Duyurusu Yap 🚀',
                      subtitle: 'Tüm kullanıcılara yeni sürüm bildirimi gönder',
                      color: const Color(0xFF9D4EDD),
                      theme: theme,
                      onTap: _showSendUpdateNotificationDialog,
                    ),
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
                      subtitle: 'NevGenç v1.0.25',
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
                style: TextStyle(
                  color: theme.textColor,
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

class _TicketCard extends StatelessWidget {
  final UserTicket ticket;
  final AppTheme theme;
  final Future<void> Function(UserTicket, String) onStatusChanged;

  const _TicketCard({
    required this.ticket,
    required this.theme,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ticket.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ticket.typeIcon, size: 14, color: ticket.statusColor),
                    const SizedBox(width: 4),
                    Text(
                      ticket.typeDisplayName,
                      style: TextStyle(color: ticket.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: ticket.status,
                onSelected: (value) => onStatusChanged(ticket, value),
                icon: Icon(Icons.more_vert, color: theme.textMuted, size: 20),
                itemBuilder: (ctx) => UserTicket.validStatuses.map((s) {
                  final color = _getStatusColor(s);
                  return PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(s == 'open' ? 'Açık' : s == 'in_progress' ? 'İşlemde' : s == 'resolved' ? 'Çözüldü' : 'Kapalı',
                             style: TextStyle(color: theme.textColor)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            style: TextStyle(color: theme.textColor, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            ticket.description,
            style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: theme.textMuted),
              const SizedBox(width: 4),
              Text('Kullanıcı: ${ticket.userId.substring(0, 8)}...', style: TextStyle(color: theme.textMuted, fontSize: 11)),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: theme.textMuted),
              const SizedBox(width: 4),
              Text(_formatDate(ticket.createdAt), style: TextStyle(color: theme.textMuted, fontSize: 11)),
            ],
          ),
          if (ticket.adminNotes != null && ticket.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yönetici Notu:', style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(ticket.adminNotes!, style: TextStyle(color: theme.textColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
    return 'Az önce';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open': return const Color(0xFF2196F3);
      case 'in_progress': return const Color(0xFFFF9800);
      case 'resolved': return const Color(0xFF4CAF50);
      case 'closed': return const Color(0xFF9E9E9E);
      default: return const Color(0xFF9D4EDD);
    }
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
                        style: TextStyle(
                          color: theme.textColor,
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
          style: TextStyle(
            color: theme.textColor,
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
                  style: TextStyle(
                    color: theme.textColor,
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

class _AdminCommunityTile extends StatelessWidget {
  final Topluluk topluluk;
  final AppTheme theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminCommunityTile({
    required this.topluluk,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primary.withValues(alpha: 0.15),
                ),
                child: ClipOval(
                  child: AppNetworkImage(
                    path: topluluk.logoPath,
                    fit: BoxFit.cover,
                    fallback: () => Icon(Icons.groups, color: theme.primary, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topluluk.ad,
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            topluluk.kategori,
                            style: TextStyle(color: theme.primary, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Başkan: ${topluluk.baskanAdi}',
                            style: TextStyle(color: theme.textMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.primary, size: 20),
                onPressed: onEdit,
                tooltip: 'Düzenle',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: theme.error, size: 20),
                onPressed: onDelete,
                tooltip: 'Topluluğu Sil',
              ),
            ],
          ),
          if (topluluk.aciklama.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              topluluk.aciklama,
              style: TextStyle(color: theme.textMuted, fontSize: 12, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

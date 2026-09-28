import 'package:flutter/material.dart';
import '../models/auth_user_model.dart';
import '../models/job_listing_model.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

/// Nev Plus'taki metin tabanlı panolar: aynı ekran, farklı tablo.
enum InfoBoardKind { jobs, menu }

/// Nev Plus > İş İlanları / Menüde Ne Var?
/// Görüntüleme herkese açık (en yeni en üstte); ekleme/düzenleme/silme
/// yalnızca Admin rolüne açık — sunucu tarafı yetki RLS ile de zorlanır
/// (job_listings / menu_items tabloları, bkz. migration).
class JobListingsScreen extends StatefulWidget {
  final AuthUser? user;
  final InfoBoardKind kind;

  const JobListingsScreen({
    super.key,
    this.user,
    this.kind = InfoBoardKind.jobs,
  });

  @override
  State<JobListingsScreen> createState() => _JobListingsScreenState();
}

class _JobListingsScreenState extends State<JobListingsScreen> {
  final _api = SupabaseDataService();
  List<JobListingModel> _listings = [];
  bool _loading = true;

  bool get _isAdmin => widget.user?.isAdmin ?? false;
  bool get _isMenu => widget.kind == InfoBoardKind.menu;

  String get _screenTitle => _isMenu ? 'Menüde Ne Var?' : 'İş İlanları';
  IconData get _screenIcon =>
      _isMenu ? Icons.restaurant_menu : Icons.work_outline;
  IconData get _emptyIcon =>
      _isMenu ? Icons.no_meals_outlined : Icons.work_off_outlined;
  String get _emptyText => _isMenu
      ? 'Şu anda paylaşılmış bir menü yok.'
      : 'Şu anda yayınlanmış bir ilan yok.';
  String get _itemNoun => _isMenu ? 'Menü' : 'İlan';
  String get _titleLabel => _isMenu ? 'Başlık (ör. Pazartesi Menüsü) *' : 'İlan Başlığı *';
  String get _descLabel => _isMenu ? 'Menü İçeriği *' : 'Açıklama *';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached =
        _isMenu ? _api.getCachedMenuItems() : _api.getCachedJobListings();
    if (cached.isNotEmpty && mounted) {
      setState(() { _listings = cached; _loading = false; });
    }
    final fresh =
        _isMenu ? await _api.getMenuItems() : await _api.getJobListings();
    if (mounted) setState(() { _listings = fresh; _loading = false; });
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    final d = dt.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _showEditor({JobListingModel? existing}) async {
    final theme = themeNotifier.value;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Yeni $_itemNoun' : '$_itemNoun Düzenle',
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(labelText: _titleLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(color: theme.textColor),
                    maxLines: 6,
                    decoration: InputDecoration(labelText: _descLabel),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text('İptal', style: TextStyle(color: theme.textMuted)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      if (title.isEmpty || desc.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Başlık ve içerik zorunludur.'),
                            backgroundColor: theme.error,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        if (_isMenu) {
                          if (existing == null) {
                            await _api.createMenuItem(title: title, description: desc);
                          } else {
                            await _api.updateMenuItem(existing.id, title: title, description: desc);
                          }
                        } else if (existing == null) {
                          await _api.createJobListing(title: title, description: desc);
                        } else {
                          await _api.updateJobListing(existing.id, title: title, description: desc);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e'), backgroundColor: theme.error),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white),
              child: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(JobListingModel listing) async {
    final theme = themeNotifier.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('$_itemNoun Sil', style: TextStyle(color: theme.textColor)),
        content: Text(
          '"${listing.title}" kaydını silmek istediğinize emin misiniz?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
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
      if (_isMenu) {
        await _api.deleteMenuItem(listing.id);
      } else {
        await _api.deleteJobListing(listing.id);
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: $e'), backgroundColor: theme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_screenIcon, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  _screenTitle,
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          floatingActionButton: _isAdmin
              ? FloatingActionButton(
                  onPressed: () => _showEditor(),
                  backgroundColor: theme.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
          body: AnimatedThemeBackground(
            child: _loading && _listings.isEmpty
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: theme.primary,
                    child: _listings.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      _emptyIcon,
                                      size: 56,
                                      color: theme.textMuted.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _emptyText,
                                      style: TextStyle(color: theme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, _isAdmin ? 90 : 24),
                            itemCount: _listings.length,
                            itemBuilder: (ctx, i) {
                              final job = _listings[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            job.title,
                                            style: TextStyle(
                                              color: theme.textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (_isAdmin) ...[
                                          IconButton(
                                            icon: Icon(Icons.edit_outlined, color: theme.primary, size: 18),
                                            onPressed: () => _showEditor(existing: job),
                                            tooltip: 'Düzenle',
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, color: theme.error, size: 18),
                                            onPressed: () => _delete(job),
                                            tooltip: 'Sil',
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      job.description,
                                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 12, color: theme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(job.publishedAt),
                                          style: TextStyle(color: theme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        );
      },
    );
  }
}

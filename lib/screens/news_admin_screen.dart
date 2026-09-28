import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

/// Admin: Anasayfa haber bülteni içeriğini yönetir (ekle/düzenle/sil).
/// Sunucu tarafı yetki kontrolü RLS ile yapılır (news_bulletins tablosu,
/// yalnızca role='admin' yazabilir) — bu ekran zaten yalnızca Admin
/// Paneli'nden erişilebilir olsa da savunma amaçlı çift katman sağlar.
class NewsAdminScreen extends StatefulWidget {
  const NewsAdminScreen({super.key});

  @override
  State<NewsAdminScreen> createState() => _NewsAdminScreenState();
}

class _NewsAdminScreenState extends State<NewsAdminScreen> {
  final _api = SupabaseDataService();
  List<NewsModel> _news = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _api.getNews();
    if (mounted) setState(() { _news = list; _loading = false; });
  }

  Future<void> _showEditor({NewsModel? existing}) async {
    final theme = themeNotifier.value;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final summaryCtrl = TextEditingController(text: existing?.summary ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Yeni Haber' : 'Haberi Düzenle',
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
                    decoration: const InputDecoration(labelText: 'Başlık *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryCtrl,
                    style: TextStyle(color: theme.textColor),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Kısa Özet (bülten kartında görünür) *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    style: TextStyle(color: theme.textColor),
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Haber Metni *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: const InputDecoration(
                      labelText: 'Görsel URL (opsiyonel)',
                      hintText: 'https://...',
                    ),
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
                      final summary = summaryCtrl.text.trim();
                      final content = contentCtrl.text.trim();
                      if (title.isEmpty || summary.isEmpty || content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Başlık, özet ve metin zorunludur.'),
                            backgroundColor: theme.error,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        if (existing == null) {
                          await _api.createNews(
                            title: title,
                            summary: summary,
                            content: content,
                            imageUrl: imageCtrl.text.trim(),
                          );
                        } else {
                          await _api.updateNews(
                            existing.id,
                            title: title,
                            summary: summary,
                            content: content,
                            imageUrl: imageCtrl.text.trim(),
                          );
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

  Future<void> _delete(NewsModel news) async {
    final theme = themeNotifier.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Haberi Sil', style: TextStyle(color: theme.textColor)),
        content: Text(
          '"${news.title}" haberini silmek istediğinize emin misiniz?',
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
      await _api.deleteNews(news.id);
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
            title: Text(
              'Haber Bülteni Yönetimi',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showEditor(),
            backgroundColor: theme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: AnimatedThemeBackground(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: theme.primary,
                    child: _news.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Henüz haber eklenmedi.\nSağ alttaki + butonuyla ekleyin.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.textMuted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: _news.length,
                            itemBuilder: (ctx, i) {
                              final n = _news[i];
                              return Card(
                                color: theme.surface,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: theme.primary.withValues(alpha: 0.15)),
                                ),
                                child: ListTile(
                                  title: Text(
                                    n.title,
                                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    n.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: theme.textMuted, fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: theme.primary, size: 20),
                                        onPressed: () => _showEditor(existing: n),
                                        tooltip: 'Düzenle',
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: theme.error, size: 20),
                                        onPressed: () => _delete(n),
                                        tooltip: 'Sil',
                                      ),
                                    ],
                                  ),
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

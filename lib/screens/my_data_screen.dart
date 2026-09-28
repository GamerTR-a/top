import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';

/// Kullanıcının kendi verisini (profil, gönderiler, talepler, rozetler)
/// görüntüleyip JSON olarak kopyalayabildiği ekran (bkz. kontrol.md Bölüm
/// 12.5 — önceden yalnızca e-posta ile talep süreci vardı, uygulama içi
/// self-servis bir görüntüleme/dışa aktarma yoktu). RLS zaten yalnızca
/// kullanıcının kendi verisine erişebilmesini garanti ediyor.
class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final _dataService = SupabaseDataService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final data = await _dataService.exportMyData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Veriler yüklenemedi. Tekrar deneyin.';
        _loading = false;
      });
    }
  }

  void _copyAsJson() {
    final data = _data;
    if (data == null) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: pretty));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verilerin JSON olarak panoya kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Text(
          'Verilerim',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_data != null)
            IconButton(
              tooltip: 'JSON olarak kopyala',
              icon: Icon(Icons.copy_outlined, color: theme.primary),
              onPressed: _copyAsJson,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMsg!, style: TextStyle(color: theme.textMuted)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Aşağıda NevGenç\'te kayıtlı olan kendi verilerin listeleniyor. '
                    'Sağ üstteki simgeyle tamamını JSON olarak panoya kopyalayıp '
                    'kendine e-posta atabilir veya bir dosyaya kaydedebilirsin.',
                    style: TextStyle(color: theme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _section(theme, 'Profil', _profileLines()),
                  const SizedBox(height: 16),
                  _section(
                    theme,
                    'Gönderilerim (${(_data!['posts'] as List).length})',
                    (_data!['posts'] as List)
                        .map(
                          (p) =>
                              (p as Map)['content']?.toString() ?? '(içeriksiz)',
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    theme,
                    'Taleplerim (${(_data!['tickets'] as List).length})',
                    (_data!['tickets'] as List)
                        .map(
                          (t) =>
                              '${(t as Map)['subject']} — ${t['status']}',
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Katıldığın topluluk sayısı: ${_data!['joined_community_count']}',
                    style: TextStyle(color: theme.textColor),
                  ),
                ],
              ),
            ),
    );
  }

  List<String> _profileLines() {
    final profile = _data!['profile'] as Map?;
    if (profile == null) return ['Profil bulunamadı.'];
    return [
      'Ad Soyad: ${profile['name'] ?? '-'}',
      'E-posta: ${profile['email'] ?? '-'}',
      'Bölüm: ${profile['department'] ?? '-'}',
      'Sınıf: ${profile['grade'] ?? '-'}',
      'Rozetler: ${(profile['badges'] as List?)?.join(', ') ?? '-'}',
    ];
  }

  Widget _section(AppTheme theme, String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text('Kayıt yok.', style: TextStyle(color: theme.textMuted))
          else
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: TextStyle(color: theme.textColor)),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/sosyo_texts.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

/// Admin: Nev+ → SOSYO ekranındaki açıklama ve "Hakkında" metinlerini düzenler.
/// Yazma yetkisi sunucuda zorlanır (app_settings: yalnızca role='admin').
class SosyoTextsAdminScreen extends StatefulWidget {
  const SosyoTextsAdminScreen({super.key});

  @override
  State<SosyoTextsAdminScreen> createState() => _SosyoTextsAdminScreenState();
}

class _SosyoTextsAdminScreenState extends State<SosyoTextsAdminScreen> {
  final _api = SupabaseDataService();
  final _descCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var settings = const <String, String>{};
    try {
      settings = await _api.getAppSettings(
        const [SosyoTexts.descriptionKey, SosyoTexts.aboutKey],
      );
    } catch (e) {
      debugPrint('[SosyoAdmin] Metinler alınamadı: $e');
    }
    if (!mounted) return;
    String pick(String key, String fallback) {
      final v = settings[key]?.trim() ?? '';
      return v.isEmpty ? fallback : v;
    }

    setState(() {
      _descCtrl.text =
          pick(SosyoTexts.descriptionKey, SosyoTexts.defaultDescription);
      _aboutCtrl.text = pick(SosyoTexts.aboutKey, SosyoTexts.defaultAbout);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final theme = themeNotifier.value;
    final messenger = ScaffoldMessenger.of(context);
    final description = _descCtrl.text.trim();
    final about = _aboutCtrl.text.trim();
    if (description.isEmpty || about.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('İki metin de boş bırakılamaz.'),
          backgroundColor: theme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.setAppSettings({
        SosyoTexts.descriptionKey: description,
        SosyoTexts.aboutKey: about,
      });
      SosyoTexts.remember(description, about);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('SOSYO metinleri güncellendi.'),
          backgroundColor: theme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: theme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _editor(
    AppTheme theme, {
    required String label,
    required String helper,
    required TextEditingController controller,
    required int maxLines,
    required int maxLength,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(helper, style: TextStyle(color: theme.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: theme.textColor, fontSize: 14, height: 1.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.surface,
            counterStyle: TextStyle(color: theme.textMuted, fontSize: 11),
            border: border(theme.primary.withValues(alpha: 0.2)),
            enabledBorder: border(theme.primary.withValues(alpha: 0.2)),
            focusedBorder: border(theme.primary, 1.5),
          ),
        ),
      ],
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Text(
              'SOSYO Metinleri',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: SafeArea(
            child: AnimatedThemeBackground(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.primary),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _editor(
                          theme,
                          label: 'Açıklama',
                          helper: 'SOSYO ekranının üstündeki kısa tanıtım.',
                          controller: _descCtrl,
                          maxLines: 4,
                          maxLength: 300,
                        ),
                        const SizedBox(height: 16),
                        _editor(
                          theme,
                          label: 'Hakkında',
                          helper: 'Ekranın altındaki uzun tanıtım yazısı.',
                          controller: _aboutCtrl,
                          maxLines: 12,
                          maxLength: 2000,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                        _descCtrl.text =
                                            SosyoTexts.defaultDescription;
                                        _aboutCtrl.text =
                                            SosyoTexts.defaultAbout;
                                      }),
                              icon: Icon(
                                Icons.restore,
                                size: 18,
                                color: theme.textMuted,
                              ),
                              label: Text(
                                'Varsayılan metni getir',
                                style: TextStyle(color: theme.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_outlined,
                                    color: Colors.white,
                                  ),
                            label: const Text(
                              'Kaydet',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

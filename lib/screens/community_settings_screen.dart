import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/topluluk.dart';
import '../models/auth_user_model.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final Topluluk topluluk;
  final AuthUser currentUser;
  const CommunitySettingsScreen({super.key, required this.topluluk, required this.currentUser});

  @override
  State<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  final _svc = SupabaseDataService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  final _discordCtrl = TextEditingController();

  String _selectedCategory = 'Teknoloji';
  File? _pickedLogo;
  String? _logoUrl;
  bool _loading = false;
  bool _saving = false;

  static const _categories = [
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

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.topluluk.ad;
    _descCtrl.text = widget.topluluk.aciklama;
    _selectedCategory = widget.topluluk.kategori;
    _logoUrl = widget.topluluk.logoPath;
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    final links = await _svc.getCommunityLinks(widget.topluluk.id);
    if (mounted) {
      setState(() {
        _telegramCtrl.text = links['telegram'] ?? '';
        _discordCtrl.text = links['discord'] ?? '';
      });
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (xfile != null) {
      setState(() => _pickedLogo = File(xfile.path));
    }
  }

  Future<String?> _uploadLogo() async {
    if (_pickedLogo == null) return _logoUrl;
    try {
      final url = await _svc.uploadPostImage(_pickedLogo!);
      return url;
    } catch (e) {
      debugPrint('[CommunitySettingsScreen] Logo upload failed: $e');
      return _logoUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final logoUrl = await _uploadLogo();
      await _svc.setCommunityLink(widget.topluluk.id, 'telegram', _telegramCtrl.text.trim());
      await _svc.setCommunityLink(widget.topluluk.id, 'discord', _discordCtrl.text.trim());

      // Update community details via admin RPC / direct update
      // Note: Only admin can update communities table directly due to RLS.
      // For president, we'd need an RPC. Fallback: try direct update (will work if policy allows).
      await _svc.updateCommunityDetails(
        communityId: widget.topluluk.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selectedCategory,
        logoPath: logoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayarlar kaydedildi ✅'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // Return true to indicate changes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Topluluğu Sil'),
        content: const Text('Bu işlem geri alınamaz. Topluluk ve tüm verileri silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      // Only admin can delete communities due to RLS
      await _svc.deleteCommunity(widget.topluluk.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Topluluk silindi'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _telegramCtrl.dispose();
    _discordCtrl.dispose();
    super.dispose();
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
              backgroundColor: theme.surface.withValues(alpha: 0.4),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Topluluk Ayarları',
                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            body: SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Logo Section
                    _SectionHeader(title: 'Logo', theme: theme),
                    const SizedBox(height: 12),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.primary.withValues(alpha: 0.3), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primary.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _pickedLogo != null
                                  ? Image.file(_pickedLogo!, fit: BoxFit.cover)
                                  : AppNetworkImage(
                                      path: _logoUrl ?? '',
                                      fit: BoxFit.cover,
                                      fallback: () => Icon(Icons.groups, color: theme.primary, size: 40),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _pickLogo,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: theme.primary.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1),
                                  ],
                                ),
                                child: Icon(Icons.camera_alt, color: theme.background, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Dokunarak değiştir',
                        style: TextStyle(color: theme.textMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    _SectionHeader(title: 'Topluluk Adı', theme: theme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: theme.textColor),
                      decoration: _inputDecoration(theme, 'Topluluk adı'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Ad gerekli' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _SectionHeader(title: 'Kategori', theme: theme),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          dropdownColor: theme.surface,
                          style: TextStyle(color: theme.textColor, fontSize: 15),
                          icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                          items: _categories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCategory = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _SectionHeader(title: 'Açıklama', theme: theme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      style: TextStyle(color: theme.textColor),
                      maxLines: 4,
                      maxLength: 500,
                      decoration: _inputDecoration(theme, 'Topluluk hakkında...').copyWith(
                        counterStyle: TextStyle(color: theme.textMuted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // External Links
                    _SectionHeader(title: 'Harici Bağlantılar', theme: theme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telegramCtrl,
                      style: TextStyle(color: theme.textColor),
                      decoration: _inputDecoration(theme, 'https://t.me/...', prefixIcon: Icons.telegram),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _discordCtrl,
                      style: TextStyle(color: theme.textColor),
                      decoration: _inputDecoration(theme, 'https://discord.gg/...', prefixIcon: Icons.discord),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: theme.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: theme.background, strokeWidth: 2),
                              )
                            : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Danger Zone
                    _SectionHeader(title: 'Tehlikeli Bölge', theme: theme, icon: Icons.warning_amber_rounded, iconColor: theme.error),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Topluluğu Sil',
                            style: TextStyle(color: theme.error, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bu işlem topluluğu ve tüm üyelerini, gönderilerini kalıcı olarak siler. Sadece yöneticiler yapabilir.',
                            style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _deleteCommunity,
                              icon: _loading
                                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: theme.error, strokeWidth: 2))
                                  : Icon(Icons.delete_forever, color: theme.error),
                              label: Text('Topluluğu Sil', style: TextStyle(color: theme.error, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.error, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(AppTheme theme, String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textMuted),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: theme.primary, size: 20) : null,
      filled: true,
      fillColor: theme.surface.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppTheme theme;
  final IconData? icon;
  final Color? iconColor;
  const _SectionHeader({required this.title, required this.theme, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? theme.primary, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
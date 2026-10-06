import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/topluluk.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_network_image.dart';

/// Başkan Paneli — "Bilgiler" sekmesi: topluluk adı, kısaltması, logosu,
/// tanıtımı, başkan adı ve iletişim bilgileri.
class InfoTab extends StatefulWidget {
  final AppTheme theme;
  final Topluluk community;
  final ValueChanged<Topluluk> onSaved;

  const InfoTab({
    super.key,
    required this.theme,
    required this.community,
    required this.onSaved,
  });

  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab> {
  final _api = SupabaseDataService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _chairmanCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  File? _pickedLogo;
  String _logoPath = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fill(widget.community);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant InfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.community.id != widget.community.id) {
      _pickedLogo = null;
      _fill(widget.community);
      _refresh();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortCtrl.dispose();
    _descCtrl.dispose();
    _chairmanCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _fill(Topluluk t) {
    _nameCtrl.text = t.ad;
    _shortCtrl.text = t.kisaltma;
    _descCtrl.text = t.aciklama;
    _chairmanCtrl.text = t.baskanAdi == 'Belirtilmedi' ? '' : t.baskanAdi;
    _emailCtrl.text = t.iletisimEposta;
    _phoneCtrl.text = t.iletisimTelefon;
    _logoPath = t.logoPath;
  }

  /// Panel listesi önbellekten gelmiş olabilir; düzenlemeye güncel kayıtla başla.
  Future<void> _refresh() async {
    final id = widget.community.id;
    final fresh = await _api.getCommunityById(id);
    if (!mounted || fresh == null || widget.community.id != id) return;
    setState(() => _fill(fresh));
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() => _pickedLogo = File(file.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final theme = widget.theme;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      String? newLogo;
      if (_pickedLogo != null) {
        newLogo = await _api.uploadPostImage(_pickedLogo!);
      }
      await _api.updateCommunityProfile(
        communityId: widget.community.id,
        name: _nameCtrl.text.trim(),
        shortName: _shortCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        chairmanName: _chairmanCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        logoPath: newLogo,
      );
      final fresh = await _api.getCommunityById(widget.community.id);
      if (!mounted) return;
      if (fresh != null) {
        setState(() {
          _pickedLogo = null;
          _fill(fresh);
        });
        widget.onSaved(fresh);
      }
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Topluluk bilgileri kaydedildi.'),
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

  InputDecoration _decoration(String hint, IconData icon) {
    final theme = widget.theme;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: theme.primary, size: 20),
      filled: true,
      fillColor: theme.surface,
      counterStyle: TextStyle(color: theme.textMuted, fontSize: 11),
      border: border(theme.primary.withValues(alpha: 0.2)),
      enabledBorder: border(theme.primary.withValues(alpha: 0.2)),
      focusedBorder: border(theme.primary, 1.5),
      errorBorder: border(theme.error),
      focusedErrorBorder: border(theme.error, 1.5),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            style: TextStyle(color: theme.textColor, fontSize: 14),
            decoration: _decoration(hint, icon),
            validator: validator,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _saving ? null : _pickLogo,
              child: Stack(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.surface,
                      border: Border.all(
                        color: theme.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _pickedLogo != null
                          ? Image.file(_pickedLogo!, fit: BoxFit.cover)
                          : AppNetworkImage(
                              path: _logoPath,
                              fit: BoxFit.cover,
                              fallback: () => Icon(
                                Icons.groups,
                                color: theme.primary,
                                size: 38,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.background, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Logoyu değiştirmek için dokunun',
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          _field(
            label: 'Topluluk Adı',
            controller: _nameCtrl,
            hint: 'Örn. Bilgisayar Öğrenci Topluluğu',
            icon: Icons.groups_outlined,
            maxLength: 120,
            capitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Topluluk adı en az 2 karakter olmalı'
                : null,
          ),
          _field(
            label: 'Kısaltma',
            controller: _shortCtrl,
            hint: 'Örn. BÖT',
            icon: Icons.short_text_rounded,
            maxLength: 20,
            capitalization: TextCapitalization.characters,
          ),
          _field(
            label: 'Başkan Adı',
            controller: _chairmanCtrl,
            hint: 'Ad Soyad',
            icon: Icons.person_outline,
            maxLength: 80,
            capitalization: TextCapitalization.words,
          ),
          _field(
            label: 'Topluluk Tanıtımı',
            controller: _descCtrl,
            hint: 'Topluluğunuzu birkaç cümleyle tanıtın',
            icon: Icons.notes_rounded,
            maxLines: 5,
            maxLength: 1000,
            capitalization: TextCapitalization.sentences,
          ),
          _field(
            label: 'İletişim E-postası',
            controller: _emailCtrl,
            hint: 'topluluk@ornek.edu.tr',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                  ? null
                  : 'Geçerli bir e-posta girin';
            },
          ),
          _field(
            label: 'İletişim Telefonu',
            controller: _phoneCtrl,
            hint: '+90 5xx xxx xx xx',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(t)
                  ? null
                  : 'Geçerli bir telefon numarası girin';
            },
          ),
          Text(
            'E-posta ve telefon topluluk sayfasında herkese görünür; '
            'kişisel numaranız yerine topluluğa ait bir iletişim bilgisi '
            'kullanmanız önerilir.',
            style: TextStyle(color: theme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
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
                  : const Icon(Icons.save_outlined, color: Colors.white),
              label: const Text(
                'Bilgileri Kaydet',
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

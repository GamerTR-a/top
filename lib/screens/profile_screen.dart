import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/auth_user_model.dart';
import '../models/user_profile_model.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_data_service.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../widgets/app_text_field.dart';
import '../widgets/options_sheet.dart';
import '../utils/file_validator.dart';
import '../utils/secure_screen.dart';
import '../theme/app_theme.dart';
import 'leaderboard_screen.dart';
import 'profile_achievements_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthUser user;
  final Future<void> Function()? onLogout;

  const ProfileScreen({super.key, required this.user, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseDataService _dataService = SupabaseDataService();
  UserProfileModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Ekran görüntüsü/görev değiştirici önizlemesinde kişisel QR kimliğin
    // (ad/e-posta içerir) görünmesini engelle (bkz. kontrol.md Bölüm 7).
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  UserProfileModel _fallbackProfile() => UserProfileModel(
        adSoyad: widget.user.name,
        email: widget.user.email,
        birthDate: widget.user.birthDate ?? '15.05.2002',
        bolum: widget.user.department ?? 'Bilişim Sistemleri Mühendisliği',
        sinif: widget.user.birthDate ?? '3. Sınıf',
        profilFoto: 'assets/gem.png',
        qrData:
            "NEVGENC KİMLİĞİ\nAd Soyad: ${widget.user.name}\nE-posta: ${widget.user.email}",
        rozetler: [],
        katilinanEtkinlikler: [],
      );

  /// Profil fotoğrafı seçme alt sayfası — galeri veya kamera.
  void _pickProfilePhoto() {
    final theme = themeNotifier.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profil Fotoğrafı',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _photoOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                      theme: theme,
                      onTap: () => _selectPhoto(ImageSource.gallery, ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _photoOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      theme: theme,
                      onTap: () => _selectPhoto(ImageSource.camera, ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String label,
    required AppTheme theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Seçilen fotoğrafı uygulama dizinine kopyala ve profile kaydet.
  Future<void> _selectPhoto(ImageSource source, BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      final validation = await FileValidator.validateXFile(picked);
      if (!validation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validation.errorMessage!),
              backgroundColor: themeNotifier.value.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${widget.user.id}.jpg';
      final savedFile = await File(picked.path).copy(p.join(appDir.path, fileName));

      if (_profile != null && mounted) {
        final updated = _profile!.copyWith(profilFoto: savedFile.path);
        setState(() => _profile = updated);
        final store = await LocalStorageService.getInstance();
        await store.cacheUserProfile(widget.user.id, updated.toJson());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçilirken hata oluştu: $e'),
            backgroundColor: themeNotifier.value.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// Yerel öncelikli profil yükleme: önce cihazdaki önbellek (anında/çevrimdışı),
  /// sonra sunucudan tazeleme (başarılıysa önbellek de güncellenir).
  Future<void> _loadProfile() async {
    final store = await LocalStorageService.getInstance();

    final cached = store.getCachedUserProfile(widget.user.id);
    if (cached != null && mounted) {
      setState(() {
        _profile = UserProfileModel.fromJson(cached);
        _isLoading = false;
      });
    }

    try {
      final profile = await _dataService.getUserProfile(widget.user.id);
      if (profile == null) {
        if (mounted && _profile == null) {
          setState(() {
            _profile = _fallbackProfile();
            _isLoading = false;
          });
        }
        return;
      }
      if (!mounted) return;
      await store.cacheUserProfile(widget.user.id, profile.toJson());
      // `await` sırasında widget unmount olmuş olabilir — setState'ten hemen
      // önce TEKRAR kontrol ediyoruz (bkz. kontrol.md Bölüm 15.4).
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && _profile == null) {
        setState(() {
          _profile = _fallbackProfile();
          _isLoading = false;
        });
      }
    }
  }

  void _showEditDialog() {
    final theme = themeNotifier.value;
    final adCtrl = TextEditingController(
      text: _profile?.adSoyad ?? widget.user.name,
    );
    final bolumCtrl = TextEditingController(text: _profile?.bolum ?? '');
    final sinifCtrl = TextEditingController(text: _profile?.sinif ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Profili Düzenle',
          style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editField(adCtrl, 'Ad Soyad', Icons.person_outline, theme),
              const SizedBox(height: 12),
              _editField(bolumCtrl, 'Bölüm', Icons.school_outlined, theme),
              const SizedBox(height: 12),
              _editField(sinifCtrl, 'Sınıf', Icons.class_outlined, theme),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = adCtrl.text.trim();
              final department = bolumCtrl.text.trim();
              final grade = sinifCtrl.text.trim();
              if (name.isEmpty ||
                  name.length > 100 ||
                  department.length > 100 ||
                  grade.length > 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Ad (1-100), bölüm (≤100) ve sınıf (≤20) sınırlarını kontrol edin.',
                    ),
                    backgroundColor: theme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final previousProfile = _profile;
              final updated = _profile?.copyWith(
                adSoyad: name,
                bolum: department,
                sinif: grade,
              );
              if (updated != null && mounted) {
                setState(() => _profile = updated);
                final store = await LocalStorageService.getInstance();
                await store.cacheUserProfile(widget.user.id, updated.toJson());
              }
              try {
                await _dataService.updateUserProfile(
                  widget.user.id,
                  name: name,
                  department: department,
                  grade: grade,
                );
              } catch (e) {
                debugPrint('[Profile] updateUserProfile error: $e');
                if (!mounted) return;
                // Sunucu yazması başarısız oldu — iyimser (optimistic) yerel
                // güncellemeyi geri al ve kullanıcıyı bilgilendir (bkz.
                // kontrol.md Bölüm 14.8: bu hata daha önce sessizce
                // yutuluyordu, kullanıcı "kaydedildi" sanıyordu).
                if (previousProfile != null) {
                  setState(() => _profile = previousProfile);
                  final store = await LocalStorageService.getInstance();
                  await store.cacheUserProfile(
                    widget.user.id,
                    previousProfile.toJson(),
                  );
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Profil güncellenemedi. Lütfen tekrar deneyin.',
                    ),
                    backgroundColor: themeNotifier.value.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).whenComplete(() {
      adCtrl.dispose();
      bolumCtrl.dispose();
      sinifCtrl.dispose();
    });
  }

  Widget _buildProfilePhoto(String photoPath, double size, AppTheme theme) {
    final placeholder = Container(
      color: theme.surface,
      child: Icon(Icons.person, size: size * 0.55, color: theme.textMuted),
    );
    return AppNetworkImage(
      path: photoPath,
      fit: BoxFit.cover,
      fallback: () => placeholder,
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    AppTheme theme,
  ) {
    return AppTextField(controller: ctrl, hint: hint, icon: icon, theme: theme);
  }

  Color _neutralBorder(AppTheme theme) =>
      theme.isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

  String _memberSinceLabel() {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final d = widget.user.createdAt;
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _infoRow({
    required AppTheme theme,
    required IconData icon,
    required String label,
    required String value,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 19, color: theme.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
              ),
              Flexible(
                flex: 2,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: _neutralBorder(theme)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        if (_isLoading) {
          return Center(child: CircularProgressIndicator(color: theme.primary));
        }

        if (_profile == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.error.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Profil yüklenemedi',
                  style: TextStyle(color: theme.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final displayName = (_profile?.adSoyad.isNotEmpty == true && _profile!.adSoyad != 'Ahmet Safa Zengin')
            ? _profile!.adSoyad
            : widget.user.name;
        final email = widget.user.email;
        final department = (_profile?.bolum.isNotEmpty == true && _profile!.bolum != 'Bilişim Sistemleri Mühendisliği')
            ? _profile!.bolum
            : (widget.user.department ?? 'Bilişim Sistemleri Mühendisliği');
        final grade = (_profile?.sinif.isNotEmpty == true && _profile!.sinif != '3. Sınıf')
            ? _profile!.sinif
            : (widget.user.birthDate ?? '3. Sınıf');
        final formattedQrData =
            "NEVGENC KİMLİĞİ\nAd Soyad: $displayName\nE-posta: $email\nSınıf: $grade\nBölüm: $department";
        final screenWidth = MediaQuery.of(context).size.width;
        final headerSize = (screenWidth * 0.26).clamp(84.0, 108.0);
        final borderColor = _neutralBorder(theme);

        return AnimatedThemeBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Üst satır: Lig — Profilim — Ayarlar
                    Row(
                      children: [
                        _topIconButton(
                          theme: theme,
                          icon: Icons.emoji_events_outlined,
                          tooltip: 'Lig',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Profilim',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _topIconButton(
                          theme: theme,
                          icon: Icons.settings_outlined,
                          tooltip: 'Ayarlar',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (ctx) => OptionsSheet(
                                isSettings: true,
                                isAdmin: widget.user.isAdmin,
                                userName: widget.user.name,
                                onLogout: widget.onLogout,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Üst bölüm: solda QR (NevGenç Kimliği), sağda profil fotoğrafı
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showQrDialog(theme, formattedQrData),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: formattedQrData,
                                    version: QrVersions.auto,
                                    size: headerSize - 20,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black87,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NevGenç Kimliğim',
                                    style: TextStyle(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: headerSize,
                              height: headerSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 2),
                              ),
                              child: ClipOval(
                                child: _buildProfilePhoto(
                                  _profile!.profilFoto,
                                  headerSize,
                                  theme,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickProfilePhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.background,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: _showEditDialog,
                        icon: Icon(Icons.edit_outlined, size: 15, color: theme.primary),
                        label: Text(
                          'Profili Düzenle',
                          style: TextStyle(color: theme.primary, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bilgi listesi — sade, nötr
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            theme: theme,
                            icon: Icons.person_outline,
                            label: 'Ad Soyad',
                            value: displayName,
                          ),
                          _infoRow(
                            theme: theme,
                            icon: Icons.email_outlined,
                            label: 'E-posta',
                            value: email,
                          ),
                          _infoRow(
                            theme: theme,
                            icon: Icons.school_outlined,
                            label: 'Bölüm',
                            value: department,
                          ),
                          _infoRow(
                            theme: theme,
                            icon: Icons.class_outlined,
                            label: 'Sınıf',
                            value: grade,
                          ),
                          _infoRow(
                            theme: theme,
                            icon: Icons.verified_user_outlined,
                            label: 'Üyelik',
                            value: _memberSinceLabel(),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileAchievementsScreen(
                            user: widget.user,
                            profile: _profile!,
                          ),
                        ),
                      ),
                      icon: Icon(Icons.workspace_premium_outlined, color: theme.primary, size: 18),
                      label: Text(
                        'Başarılarım ve Anılarım',
                        style: TextStyle(color: theme.primary, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topIconButton({
    required AppTheme theme,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _neutralBorder(theme)),
          ),
          child: Icon(icon, color: theme.textColor, size: 20),
        ),
      ),
    );
  }

  void _showQrDialog(AppTheme theme, String qrData) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Taratarak Etkinliklere Katılın',
                style: TextStyle(color: theme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

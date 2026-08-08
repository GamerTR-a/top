import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../models/user_profile_model.dart';
import '../services/joined_communities_service.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_data_service.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../widgets/app_text_field.dart';
import '../widgets/options_sheet.dart';
import '../theme/app_theme.dart';
import 'community_detail_screen.dart';
import 'leaderboard_screen.dart';

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

  int _parcelIndex = 0;
  bool _isQrCollapsed = false;

  final List<BadgeParcelItem> _parcelBadges = const [
    BadgeParcelItem(
      id: '1',
      zoneName: 'PARSEL 1',
      title: 'NevGenç Üyesi',
      areaText: '100 sqm',
      icon: Icons.star_rounded,
      color: Color(0xFFE57373), // Salmon Pink
    ),
    BadgeParcelItem(
      id: '2',
      zoneName: 'PARSEL 2',
      title: 'Kitap Kurdu',
      areaText: '105 sqm',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF42A5F5), // Royal Blue
    ),
    BadgeParcelItem(
      id: '3',
      zoneName: 'PARSEL 3',
      title: 'Etkinlik Ustası',
      areaText: '160 sqm',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFAB47BC), // Magenta Purple
    ),
    BadgeParcelItem(
      id: '4',
      zoneName: 'PARSEL 4',
      title: 'Sporcu Genç',
      areaText: '105 sqm',
      icon: Icons.sports_soccer_rounded,
      color: Color(0xFF8D6E63), // Warm Brown
    ),
    BadgeParcelItem(
      id: '5',
      zoneName: 'PARSEL 5',
      title: 'Topluluk Lideri',
      areaText: '100 sqm',
      icon: Icons.military_tech_rounded,
      color: Color(0xFF26C6DA), // Cyan Mint
    ),
    BadgeParcelItem(
      id: '6',
      zoneName: 'PARSEL 6',
      title: 'Gönüllü Genç',
      areaText: '100 sqm',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF78909C), // Slate Grey
    ),
    BadgeParcelItem(
      id: '7',
      zoneName: 'PARSEL 7',
      title: 'Sosyal Kelebek',
      areaText: '100 sqm',
      icon: Icons.flutter_dash_rounded,
      color: Color(0xFFB39DDB), // Soft Purple
    ),
    BadgeParcelItem(
      id: '8',
      zoneName: 'PARSEL 8',
      title: 'Bilgi Şampiyonu',
      areaText: '100 sqm',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFF9CCC65), // Lime Green
    ),
    BadgeParcelItem(
      id: '9',
      zoneName: 'PARSEL 9',
      title: 'Oyun Ustası',
      areaText: '105 sqm',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF7E57C2), // Deep Violet
    ),
    BadgeParcelItem(
      id: '10',
      zoneName: 'PARSEL 10',
      title: 'NEV + Üyesi',
      areaText: '160 sqm',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFCA28), // Amber Gold
    ),
  ];

  final List<Topluluk> _joinedCommunities = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadJoinedCommunities();
    JoinedCommunitiesService.instance.revision.addListener(_loadJoinedCommunities);
  }

  @override
  void dispose() {
    JoinedCommunitiesService.instance.revision
        .removeListener(_loadJoinedCommunities);
    super.dispose();
  }

  /// Katıldığım toplulukları yerel depolamadan oku. "Katıl"/"Ayrıl" her
  /// değişiklikte [JoinedCommunitiesService.revision] artar ve bu listener
  /// tetiklenir — tablar canlı kaldığı için profil anında güncellenir.
  Future<void> _loadJoinedCommunities() async {
    final list =
        await JoinedCommunitiesService.instance.getJoinedCommunities();
    if (!mounted) return;
    setState(() {
      _joinedCommunities
        ..clear()
        ..addAll(list);
    });
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

      // Uygulama belge dizinine kopyala
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${widget.user.id}.jpg';
      final savedFile = await File(picked.path).copy(p.join(appDir.path, fileName));

      // Profili güncelle
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

    // 1) Önce yerel önbellek — anında ve çevrimdışı gösterim
    final cached = store.getCachedUserProfile(widget.user.id);
    if (cached != null && mounted) {
      setState(() {
        _profile = UserProfileModel.fromJson(cached);
        _isLoading = false;
      });
    }

    // 2) Sunucudan tazele
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
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      // Çevrimdışı: önbellek gösteriliyor; yoksa AuthUser'dan fallback
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
              // 1) Yerel: profili hemen güncelle ve cihaza kaydet
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
              // 2) Senkron (best-effort): gönderiler/liderlik/QR tutarlı kalsın
              await _dataService
                  .updateUserProfile(
                    widget.user.id,
                    name: name,
                    department: department,
                    grade: grade,
                  )
                  .catchError(
                    (e) => debugPrint('[Profile] updateUserProfile error: $e'),
                  );
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

  Widget _buildGalleryImage(String path, AppTheme theme) {
    final placeholder = Container(
      color: theme.surface,
      child: Icon(Icons.photo, color: theme.textMuted, size: 32),
    );
    return AppNetworkImage(
      path: path,
      fit: BoxFit.cover,
      fallback: () => placeholder,
    );
  }

  /// Katıldığım topluluk kartı — logo + ad + "Ayrıl" butonu. Karta dokunmak
  /// topluluk detayına gider, "Ayrıl" listeden çıkarır (yerel depolama).
  Widget _buildJoinedCommunityCard(Topluluk t, AppTheme theme) {
    final fallback = Icon(Icons.groups_rounded, color: theme.primary, size: 26);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(topluluk: t),
        ),
      ),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: AppNetworkImage(
                  path: t.logoPath,
                  fit: BoxFit.cover,
                  fallback: () => fallback,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.ad,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: OutlinedButton(
                onPressed: () async {
                  final name = t.ad;
                  await JoinedCommunitiesService.instance.leave(t.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name topluluğundan ayrıldın.'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primary,
                  side: BorderSide(color: theme.primary.withValues(alpha: 0.5)),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ayrıl',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(String photoPath, double size, AppTheme theme) {
    final placeholder = Container(
      color: theme.surface,
      child: Icon(Icons.person, size: size * 0.55, color: Colors.white),
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
        final avatarSize = (screenWidth * 0.27).clamp(80.0, 130.0);

        return AnimatedThemeBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Profilim',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Sol Buton: Lig 🏆 (Kare)
                        Tooltip(
                          message: 'Lig',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LeaderboardScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? theme.surface.withValues(alpha: 0.8)
                                    : theme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.7),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFFFD700),
                                size: 28,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 32),

                        // Profil Fotoğrafı
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                                border:
                                    Border.all(color: theme.primary, width: 3),
                              ),
                              child: ClipOval(
                                child: _buildProfilePhoto(
                                  _profile!.profilFoto,
                                  avatarSize,
                                  theme,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
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
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 32),

                        // Sağ Buton: Ayarlar ⚙️ (Kare)
                        Tooltip(
                          message: 'Ayarlar',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
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
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? theme.surface.withValues(alpha: 0.8)
                                    : theme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.primary.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        theme.primary.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.settings_rounded,
                                color: theme.primary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showEditDialog,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: theme.primary,
                      ),
                      label: Text(
                        'Profili Düzenle',
                        style: TextStyle(color: theme.primary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // NevGenç Kimlik Kartı - QR (Küçültme Özellikli)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? theme.surface.withValues(alpha: 0.6)
                            : theme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.primary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Tıklanabilir Başlık & Küçültme/Büyütme Butonu
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isQrCollapsed = !_isQrCollapsed;
                              });
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        color: theme.primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'NevGenç Kimliğim',
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _isQrCollapsed ? 'Göster' : 'Küçült',
                                          style: TextStyle(
                                            color: theme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _isQrCollapsed
                                              ? Icons.keyboard_arrow_down_rounded
                                              : Icons.keyboard_arrow_up_rounded,
                                          color: theme.primary,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // QR İçeriği (Animasyonlu Gizleme/Gösterme)
                          AnimatedCrossFade(
                            firstChild: const SizedBox(
                              width: double.infinity,
                              height: 0,
                            ),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                bottom: 20,
                              ),
                              child: Column(
                                children: [
                                  Divider(
                                    height: 1,
                                    color: theme.textMuted.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.primary.withValues(alpha: 0.25),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: QrImageView(
                                      data: formattedQrData,
                                      version: QrVersions.auto,
                                      size: (screenWidth * 0.4).clamp(120.0, 200.0),
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Colors.black87,
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Taratarak Etkinliklere Katılın',
                                    style: TextStyle(
                                      color: theme.textMuted,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            crossFadeState: _isQrCollapsed
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Rozetler
                    // Kazandığın Rozetler - Döner 10 Parselli Sistem (3'erli Parseller)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kazandığın Rozetler 🎖️',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Döner Parsel Görünümü (3 Parsel)',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Sol Buton (<)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _parcelIndex =
                                      (_parcelIndex - 1 + _parcelBadges.length) %
                                          _parcelBadges.length;
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  color: theme.primary,
                                  size: 20,
                                ),
                              ),
                              tooltip: 'Önceki Parseller',
                            ),
                            // Sağ Buton (>)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _parcelIndex =
                                      (_parcelIndex + 1) % _parcelBadges.length;
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.primary,
                                  size: 20,
                                ),
                              ),
                              tooltip: 'Sonraki Parseller',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3'erli Parsel Kartları (En Üstteki 3 Görünen Parsel)
                    Builder(
                      builder: (ctx) {
                        final total = _parcelBadges.length;
                        final leftIdx = (_parcelIndex - 1 + total) % total;
                        final centerIdx = _parcelIndex % total;
                        final rightIdx = (_parcelIndex + 1) % total;

                        final visibleIndices = [leftIdx, centerIdx, rightIdx];

                        return Row(
                          children: visibleIndices.map((idx) {
                            final parcel = _parcelBadges[idx];
                            final isCenter = idx == centerIdx;

                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.symmetric(
                                  horizontal: isCenter ? 4 : 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.isDark
                                      ? theme.surface.withValues(alpha: 0.85)
                                      : theme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: parcel.color.withValues(
                                      alpha: isCenter ? 0.8 : 0.4,
                                    ),
                                    width: isCenter ? 2.0 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: parcel.color.withValues(
                                        alpha: isCenter ? 0.25 : 0.08,
                                      ),
                                      blurRadius: isCenter ? 14 : 8,
                                      spreadRadius: isCenter ? 1 : 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Parsel Etiketi
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: parcel.color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        parcel.zoneName,
                                        style: TextStyle(
                                          color: parcel.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Dairesel İkon Kutusu
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: parcel.color.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: parcel.color.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Icon(
                                        parcel.icon,
                                        color: parcel.color,
                                        size: isCenter ? 24 : 20,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Başlık
                                    Text(
                                      parcel.title,
                                      style: TextStyle(
                                        color: theme.textColor,
                                        fontSize: isCenter ? 12 : 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    // Alan Bilgisi
                                    Text(
                                      parcel.areaText,
                                      style: TextStyle(
                                        color: theme.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Hatıra Galerisi
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hatıra Galerisi 🔭',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Katıldığım Topluluklar — yerel depolamadan, anında güncellenir
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Katıldığım Topluluklar 🎯',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_joinedCommunities.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 32,
                              color: theme.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz bir topluluğa katılmadın',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Topluluk kartındaki "Katıl" butonuyla ekle',
                              style: TextStyle(
                                color: theme.textMuted.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 172,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _joinedCommunities.length,
                          itemBuilder: (context, index) =>
                              _buildJoinedCommunityCard(
                            _joinedCommunities[index],
                            theme,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Etkinlik Anıları
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Etkinlik Anıları 📸',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_profile!.katilinanEtkinlikler.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 36,
                              color: theme.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz etkinliğe katılmadın',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: (screenWidth * 0.3).clamp(90.0, 140.0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _profile!.katilinanEtkinlikler.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: (screenWidth * 0.3).clamp(90.0, 140.0),
                              margin: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _buildGalleryImage(
                                    _profile!.katilinanEtkinlikler[index],
                                    theme,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BadgeParcelItem {
  final String id;
  final String title;
  final String zoneName;
  final String areaText;
  final IconData icon;
  final Color color;

  const BadgeParcelItem({
    required this.id,
    required this.title,
    required this.zoneName,
    required this.areaText,
    required this.icon,
    required this.color,
  });
}

class _DecagonParcelWheelPainter extends CustomPainter {
  final List<BadgeParcelItem> parcels;
  final int selectedIndex;
  final bool isDark;

  _DecagonParcelWheelPainter({
    required this.parcels,
    required this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) * 0.44;
    final innerRadius = outerRadius * 0.38;

    final count = parcels.length;
    final anglePerSector = (2 * math.pi) / count;

    // Draw central "O" node
    final centerDotPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
          .withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw sectors (10 trapezoid parcels around center)
    for (int i = 0; i < count; i++) {
      final parcel = parcels[i];
      // Angle offset so index 0 is at top (-pi/2)
      final startAngle =
          -math.pi / 2 + (i * anglePerSector) - (anglePerSector / 2);
      final endAngle = startAngle + anglePerSector;

      // Small gap between parcels
      const gapAngle = 0.04;
      final actualStart = startAngle + gapAngle;
      final actualEnd = endAngle - gapAngle;

      final path = Path();
      // Outer arc corner 1
      final p1 = Offset(
        center.dx + outerRadius * math.cos(actualStart),
        center.dy + outerRadius * math.sin(actualStart),
      );
      // Outer arc corner 2
      final p2 = Offset(
        center.dx + outerRadius * math.cos(actualEnd),
        center.dy + outerRadius * math.sin(actualEnd),
      );
      // Inner arc corner 2
      final p3 = Offset(
        center.dx + innerRadius * math.cos(actualEnd),
        center.dy + innerRadius * math.sin(actualEnd),
      );
      // Inner arc corner 1
      final p4 = Offset(
        center.dx + innerRadius * math.cos(actualStart),
        center.dy + innerRadius * math.sin(actualStart),
      );

      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
      path.close();

      final isSelected = i == selectedIndex;

      final fillPaint = Paint()
        ..color = parcel.color.withValues(alpha: isSelected ? 0.95 : 0.65)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = isSelected ? Colors.white : parcel.color
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);

      // Draw radial line from inner vertex to center O
      canvas.drawLine(center, p4, linePaint);
    }

    // Draw central red "O" node circle
    canvas.drawCircle(center, 7, centerDotPaint);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // Draw "O" label
    final textSpan = TextSpan(
      text: 'O',
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - 22),
    );
  }

  @override
  bool shouldRepaint(covariant _DecagonParcelWheelPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}

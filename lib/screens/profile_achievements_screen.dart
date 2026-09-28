import 'package:flutter/material.dart';
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../models/user_profile_model.dart';
import '../services/joined_communities_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import 'community_detail_screen.dart';
import 'memory_gallery_screen.dart';

/// Profilim ekranından ayrılan rozet/anı/topluluk içerikleri (Görev 9).
/// Ana Profilim ekranı artık sade bir kimlik kartı; oyunlaştırılmış
/// (rozet parselleri, hatıra galerisi, katıldığım topluluklar, etkinlik
/// anıları) içerikler buraya taşındı.
class ProfileAchievementsScreen extends StatefulWidget {
  final AuthUser user;
  final UserProfileModel profile;

  const ProfileAchievementsScreen({
    super.key,
    required this.user,
    required this.profile,
  });

  @override
  State<ProfileAchievementsScreen> createState() =>
      _ProfileAchievementsScreenState();
}

class _ProfileAchievementsScreenState
    extends State<ProfileAchievementsScreen> {
  int _parcelIndex = 0;

  final List<BadgeParcelItem> _parcelBadges = const [
    BadgeParcelItem(
      id: '1',
      zoneName: 'PARSEL 1',
      title: 'NevGenç Üyesi',
      areaText: '100 sqm',
      icon: Icons.star_rounded,
      color: Color(0xFFE57373),
    ),
    BadgeParcelItem(
      id: '2',
      zoneName: 'PARSEL 2',
      title: 'Kitap Kurdu',
      areaText: '105 sqm',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF42A5F5),
    ),
    BadgeParcelItem(
      id: '3',
      zoneName: 'PARSEL 3',
      title: 'Etkinlik Ustası',
      areaText: '160 sqm',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFAB47BC),
    ),
    BadgeParcelItem(
      id: '4',
      zoneName: 'PARSEL 4',
      title: 'Sporcu Genç',
      areaText: '105 sqm',
      icon: Icons.sports_soccer_rounded,
      color: Color(0xFF8D6E63),
    ),
    BadgeParcelItem(
      id: '5',
      zoneName: 'PARSEL 5',
      title: 'Topluluk Lideri',
      areaText: '100 sqm',
      icon: Icons.military_tech_rounded,
      color: Color(0xFF26C6DA),
    ),
    BadgeParcelItem(
      id: '6',
      zoneName: 'PARSEL 6',
      title: 'Gönüllü Genç',
      areaText: '100 sqm',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF78909C),
    ),
    BadgeParcelItem(
      id: '7',
      zoneName: 'PARSEL 7',
      title: 'Sosyal Kelebek',
      areaText: '100 sqm',
      icon: Icons.flutter_dash_rounded,
      color: Color(0xFFB39DDB),
    ),
    BadgeParcelItem(
      id: '8',
      zoneName: 'PARSEL 8',
      title: 'Bilgi Şampiyonu',
      areaText: '100 sqm',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFF9CCC65),
    ),
    BadgeParcelItem(
      id: '9',
      zoneName: 'PARSEL 9',
      title: 'Oyun Ustası',
      areaText: '105 sqm',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF7E57C2),
    ),
    BadgeParcelItem(
      id: '10',
      zoneName: 'PARSEL 10',
      title: 'NEV + Üyesi',
      areaText: '160 sqm',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFCA28),
    ),
  ];

  final List<Topluluk> _joinedCommunities = [];

  @override
  void initState() {
    super.initState();
    _loadJoinedCommunities();
    JoinedCommunitiesService.instance.revision.addListener(
      _loadJoinedCommunities,
    );
  }

  @override
  void dispose() {
    JoinedCommunitiesService.instance.revision.removeListener(
      _loadJoinedCommunities,
    );
    super.dispose();
  }

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

  Widget _buildGalleryImage(String path, AppTheme theme) {
    final placeholder = Container(
      color: theme.surface,
      child: Icon(Icons.photo, color: theme.textMuted, size: 32),
    );
    return AppNetworkImage(path: path, fit: BoxFit.cover, fallback: () => placeholder);
  }

  Widget _buildJoinedCommunityCard(Topluluk t, AppTheme theme) {
    final fallback = Icon(Icons.groups_rounded, color: theme.primary, size: 26);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CommunityDetailScreen(topluluk: t, currentUser: widget.user),
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
                  try {
                    await JoinedCommunitiesService.instance.leave(t.id);
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$name topluluğundan ayrılırken bir sorun oluştu. Lütfen tekrar dene.',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final profile = widget.profile;

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
              'Başarılarım',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rozetler — Döner 10 Parselli Sistem
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

                    const SizedBox(height: 28),

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
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MemoryGalleryScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 28,
                              color: theme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Albümlerimi Görüntüle',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Yerel depolamada güvenle saklanan anılarınız',
                                    style: TextStyle(
                                      color: theme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.textMuted,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Katıldığım Topluluklar
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
                    if (profile.katilinanEtkinlikler.isEmpty)
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
                          itemCount: profile.katilinanEtkinlikler.length,
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
                                    profile.katilinanEtkinlikler[index],
                                    theme,
                                  ),
                                ),
                              ),
                            );
                          },
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

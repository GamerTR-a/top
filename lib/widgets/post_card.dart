import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final Function(PostModel) onSupportTap;
  final Function(PostModel, int) onRatingChanged;
  final Function(PostModel) onReport;

  const PostCard({
    super.key,
    required this.post,
    required this.onSupportTap,
    required this.onRatingChanged,
    required this.onReport,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _myRating = 0;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromPost();
  }

  void _syncFromPost() {
    _myRating = widget.post.myRating ?? 0;
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
      if (diff.inHours < 24) return '${diff.inHours} sa önce';
      if (diff.inDays < 7) return '${diff.inDays} gün önce';
      const months = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _ratingLabel() {
    if (_myRating > 0) {
      final avg = widget.post.ratingCount > 0
          ? ' · ${widget.post.ratingAvg.toStringAsFixed(1)}'
          : '';
      return '$_myRating ⭐$avg';
    }
    if (widget.post.ratingCount > 0) {
      return '${widget.post.ratingAvg.toStringAsFixed(1)} (${widget.post.ratingCount})';
    }
    return 'Oyla';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.isDark
                ? theme.surface.withValues(alpha: 0.5)
                : theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.isDark
                  ? theme.primary.withValues(alpha: 0.2)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Logo, Topluluk Adı, Tarih
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.background,
                        border: Border.all(
                          color: theme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ClipOval(
                        child: _buildLogoImage(widget.post.toplulukLogo, theme),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.toplulukAdi,
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _formatDate(widget.post.tarih),
                            style: TextStyle(
                              color: theme.textMuted.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Üç nokta menüsü — şikayet et
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.textMuted,
                        size: 18,
                      ),
                      color: theme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                size: 16,
                                color: theme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Şikayet Et',
                                style: TextStyle(color: theme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'report') widget.onReport(widget.post);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gönderi Metni
                Text(
                  widget.post.metin,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Varsa Etkinlik Afişi
                if (widget.post.etkinlikGorseli != null &&
                    widget.post.etkinlikGorseli!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildEventImage(widget.post.etkinlikGorseli!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (widget.post.resimUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppNetworkImage(
                        path: widget.post.resimUrl!,
                        fit: BoxFit.cover,
                        placeholder: () => Container(
                          color: theme.background,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        fallback: () => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Divider
                Divider(color: theme.textMuted.withValues(alpha: 0.2)),
                const SizedBox(height: 8),

                // Etkileşimler
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Destek Butonu
                    GestureDetector(
                      onTap: () => widget.onSupportTap(widget.post),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.post.isSupportedByMe
                              ? theme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.post.isSupportedByMe
                                ? theme.primary
                                : theme.textMuted.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.post.isSupportedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: widget.post.isSupportedByMe
                                  ? theme.primary
                                  : theme.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Destekle (${widget.post.destekPuani})',
                              style: TextStyle(
                                color: widget.post.isSupportedByMe
                                    ? theme.primary
                                    : theme.textMuted,
                                fontSize: 13,
                                fontWeight: widget.post.isSupportedByMe
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Kalite Puanı Yıldızları
                    GestureDetector(
                      onTap: () => _showRatingSheet(context, theme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _myRating > 0
                              ? theme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _myRating > 0
                                ? theme.primary
                                : theme.textMuted.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: theme.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _ratingLabel(),
                              style: TextStyle(
                                color: _myRating > 0
                                    ? theme.primary
                                    : theme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _myRating > 0
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                              color: _myRating > 0
                                  ? theme.secondary
                                  : theme.textMuted.withValues(alpha: 0.6),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildEventImage(String path) {
    const errorWidget = ColoredBox(
      color: Color(0x0DFFFFFF),
      child: Center(
        child: Icon(Icons.image_not_supported, color: Colors.white24, size: 30),
      ),
    );
    return AppNetworkImage(
      path: path,
      fit: BoxFit.cover,
      fallback: () => errorWidget,
    );
  }

  Widget _buildLogoImage(String logoPath, AppTheme theme) {
    if (logoPath.isEmpty) {
      return Container(
        color: theme.surface,
        child: Icon(Icons.group, color: theme.textMuted, size: 22),
      );
    }
    return AppNetworkImage(
      path: logoPath,
      fit: BoxFit.cover,
      cacheWidth: 80,
      placeholder: () => Container(color: theme.surface),
      fallback: () => Icon(Icons.group, color: theme.textMuted, size: 22),
    );
  }

  void _showRatingSheet(BuildContext context, AppTheme theme) {
    int tempRating = _myRating;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: theme.primary, width: 2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.post.toplulukAdi} Gönderisini Oyla',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.post.ratingCount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Ortalama: ${widget.post.ratingAvg.toStringAsFixed(1)} '
                        '(${widget.post.ratingCount} oy)',
                        style: TextStyle(color: theme.textMuted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => tempRating = star),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: star <= tempRating
                                  ? theme.warning.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              star <= tempRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: star <= tempRating
                                  ? theme.warning
                                  : theme.textMuted,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (tempRating > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '$tempRating/5',
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: tempRating == 0
                          ? null
                          : () {
                              setState(() {
                                _myRating = tempRating;
                              });
                              widget.onRatingChanged(widget.post, tempRating);
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: theme.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _myRating > 0
                            ? 'Puanı Güncelle'
                            : 'Puan Ver & XP Kazan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../models/discount_model.dart';
import '../theme/app_theme.dart';

class DiscountCarousel extends StatelessWidget {
  final List<DiscountModel> kuponlar;

  const DiscountCarousel({super.key, required this.kuponlar});

  @override
  Widget build(BuildContext context) {
    if (kuponlar.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final carouselHeight = (screenWidth * 0.45).clamp(165.0, 195.0);
        final cardWidth = (screenWidth * 0.44).clamp(155.0, 190.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: theme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Nev Fırsatlar',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Tümünü Gör',
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: theme.primary,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: carouselHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                itemCount: kuponlar.length,
                itemBuilder: (context, index) {
                  return _buildKuponCard(
                    kuponlar[index],
                    index,
                    cardWidth,
                    carouselHeight,
                    theme,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKuponCard(
    DiscountModel kupon,
    int index,
    double cardWidth,
    double cardHeight,
    AppTheme theme,
  ) {
    // Alternate between Cyan and Green themes matching reference design
    final isGreen = index % 2 == 1;

    final List<Color> lightGradient = isGreen
        ? const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]
        : const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)];

    final List<Color> darkGradient = isGreen
        ? const [Color(0xFF064E3B), Color(0xFF047857)]
        : const [Color(0xFF083344), Color(0xFF164E63)];

    final primaryColor = isGreen
        ? const Color(0xFF0F9D58)
        : const Color(0xFF00ACC1);

    final displayDiscountText = kupon.indirimOrani.contains('İndirim')
        ? kupon.indirimOrani
        : '${kupon.indirimOrani} İndirim';

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isDark ? darkGradient : lightGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.isDark
              ? primaryColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-left Icon Circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isGreen ? Colors.white : primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.sell_rounded,
                  color: isGreen ? primaryColor : Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Place Name & Coupon Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    kupon.sirketAd,
                    style: TextStyle(
                      color: theme.isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kupon.kuponAdi,
                    style: TextStyle(
                      color: theme.isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Bottom Pill Badge
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayDiscountText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

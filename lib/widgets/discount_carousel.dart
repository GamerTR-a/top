import 'package:flutter/material.dart';
import '../models/discount_model.dart';
import '../theme/app_theme.dart';
import 'flip_coupon_card.dart';

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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Çift Tıkla 🔒',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.primary,
                          ),
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
                  return FlipCouponCard(
                    kupon: kuponlar[index],
                    index: index,
                    cardWidth: cardWidth,
                    cardHeight: carouselHeight,
                    theme: theme,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}


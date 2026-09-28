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
        final horizontalPadding = screenWidth * 0.04;
        const cardHeight = 165.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 8.0,
              ),
              child: Row(
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
                ],
              ),
            ),
            // Kartlar satırı dolduracak şekilde alt alta dizilir; kaydırmayı
            // üstteki ListView (NevFirsatlarScreen) yapar.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  for (var index = 0; index < kuponlar.length; index++)
                    FlipCouponCard(
                      key: ValueKey(kuponlar[index].id),
                      kupon: kuponlar[index],
                      index: index,
                      cardWidth: double.infinity,
                      cardHeight: cardHeight,
                      theme: theme,
                      margin: const EdgeInsets.only(bottom: 12.0),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


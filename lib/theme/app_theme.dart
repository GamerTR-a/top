import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { starry, geometric, geometricLight, light, custom }

class AppTheme {
  final ThemeType type;
  final String name;
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color textMuted;
  final Color error;
  final Color warning;
  final List<Color> paletteColors;

  final bool isDark;

  const AppTheme({
    required this.type,
    required this.name,
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.textMuted,
    required this.paletteColors,
    this.isDark = true,
    this.error = const Color(0xFFFF5252),
    this.warning = const Color(0xFFFFD700),
  });

  Color get textColor => isDark ? Colors.white : const Color(0xFF0F172A);

  static const starry = AppTheme(
    type: ThemeType.starry,
    name: "Yıldızlı",
    background: Color(0xFF050714),
    surface: Color(0xFF0E132A),
    primary: Color(0xFF6366F1),
    secondary: Color(0xFFFF3B5C),
    textMuted: Color(0xFF94A3B8),
    paletteColors: [Color(0xFF6366F1), Color(0xFFFF3B5C), Color(0xFF38BDF8)],
  );

  static const geometric = AppTheme(
    type: ThemeType.geometric,
    name: "Geometrik",
    background: Color(0xFF090D16),
    surface: Color(0xFF111827),
    primary: Color(0xFF6366F1),
    secondary: Color(0xFF38BDF8),
    textMuted: Color(0xFF94A3B8),
    paletteColors: [Color(0xFF6366F1), Color(0xFF38BDF8), Color(0xFF818CF8)],
  );

  static const geometricLight = AppTheme(
    type: ThemeType.geometricLight,
    name: "Aydınlık Geometrik",
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF4F46E5),
    secondary: Color(0xFF0284C7),
    textMuted: Color(0xFF64748B),
    paletteColors: [Color(0xFF4F46E5), Color(0xFF0284C7), Color(0xFF6366F1)],
    isDark: false,
  );

  static const light = AppTheme(
    type: ThemeType.light,
    name: "Aydınlık Klasik",
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF7C3AED),
    textMuted: Color(0xFF64748B),
    paletteColors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF3B82F6)],
    isDark: false,
  );

  factory AppTheme.fromColors(List<Color> colors) {
    if (colors.isEmpty) return starry;
    final primary = colors[0];
    final secondary = colors.length > 1 ? colors[1] : primary;
    final bg = colors.length > 2 ? colors[2] : const Color(0xFF050714);
    final surface = _darken(bg, 0.2);
    return AppTheme(
      type: ThemeType.custom,
      name: "Özel Tema",
      background: bg,
      surface: surface,
      primary: primary,
      secondary: secondary,
      textMuted: const Color(0xFF94A3B8),
      paletteColors: colors,
      isDark: true,
    );
  }

  static Color _darken(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textColor,
        onError: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textColor, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: primary.withValues(alpha: 0.6), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

final ValueNotifier<AppTheme> themeNotifier = ValueNotifier<AppTheme>(AppTheme.starry);

Future<void> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final typeName = prefs.getString('theme_type') ?? 'starry';
  switch (typeName) {
    case 'starry':
      themeNotifier.value = AppTheme.starry;
    case 'geometric':
      themeNotifier.value = AppTheme.geometric;
    case 'geometricLight':
      themeNotifier.value = AppTheme.geometricLight;
    case 'light':
      themeNotifier.value = AppTheme.light;
    case 'custom':
      final raw = prefs.getStringList('theme_colors') ?? [];
      if (raw.isNotEmpty) {
        final colors = raw.map((s) => Color(int.parse(s))).toList();
        themeNotifier.value = AppTheme.fromColors(colors);
      }
  }
}

Future<void> saveCurrentTheme(AppTheme theme) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_type', theme.type.name);
  if (theme.type == ThemeType.custom) {
    await prefs.setStringList(
      'theme_colors',
      theme.paletteColors.map((c) => c.toARGB32().toString()).toList(),
    );
  }
}


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
    name: "Geo Beyaz",
    background: Color(0xFFDDE6F0),
    surface: Color(0xFFCDDCEB),
    primary: Color(0xFF3B597B),
    secondary: Color(0xFF5B7B9C),
    textMuted: Color(0xFF475569),
    paletteColors: [Color(0xFF3B597B), Color(0xFF5B7B9C), Color(0xFF8BAAC9)],
    isDark: false,
  );

  static const light = AppTheme(
    type: ThemeType.light,
    name: "Beyaz",
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF00ACC1),
    secondary: Color(0xFF0284C7),
    textMuted: Color(0xFF64748B),
    paletteColors: [Color(0xFF00ACC1), Color(0xFF0284C7), Color(0xFF38BDF8)],
    isDark: false,
  );

  factory AppTheme.fromColors(List<Color> colors) {
    assert(colors.isNotEmpty);
    final p = colors[0];
    final s = colors.length > 1 ? colors[1] : Color.lerp(p, Colors.white, 0.5)!;
    final bg = _darken(p, 0.88);
    final surf = _darken(p, 0.72);
    final muted = Color.lerp(p, Colors.white, 0.45)!;
    return AppTheme(
      type: ThemeType.custom,
      name: "Özel",
      background: bg,
      surface: surf,
      primary: p,
      secondary: s,
      textMuted: muted,
      paletteColors: List.unmodifiable(colors),
    );
  }

  static Color _darken(Color c, double amount) => Color.fromRGBO(
    ((c.r * 255.0).round() * (1 - amount)).round().clamp(0, 255),
    ((c.g * 255.0).round() * (1 - amount)).round().clamp(0, 255),
    ((c.b * 255.0).round() * (1 - amount)).round().clamp(0, 255),
    1,
  );

  ThemeData get themeData {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      iconTheme: IconThemeData(color: primary),
    );
  }
}

final ValueNotifier<AppTheme> themeNotifier = ValueNotifier<AppTheme>(
  AppTheme.starry,
);

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

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

class ThemeCustomizerScreen extends StatefulWidget {
  const ThemeCustomizerScreen({super.key});

  @override
  State<ThemeCustomizerScreen> createState() => _ThemeCustomizerScreenState();
}

class _ThemeCustomizerScreenState extends State<ThemeCustomizerScreen> {
  late AppTheme _originalTheme;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _originalTheme = themeNotifier.value;
  }

  void _applyPreset(AppTheme preset) {
    _applied = true;
    themeNotifier.value = preset;
    saveCurrentTheme(preset);
    Navigator.pop(context);
  }

  void _cancel() {
    themeNotifier.value = _originalTheme;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_applied) themeNotifier.value = _originalTheme;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedThemeBackground(
          child: SafeArea(
            child: ValueListenableBuilder<AppTheme>(
              valueListenable: themeNotifier,
              builder: (context, theme, _) {
                return Column(
                  children: [
                    _buildHeader(theme),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _buildSectionLabel('Hazır Temalar', theme),
                            const SizedBox(height: 16),
                            _buildPresetRow(theme),
                            const SizedBox(height: 16),
                            _buildSystemToggle(theme),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: theme.primary),
            onPressed: _cancel,
            tooltip: 'Geri',
          ),
          Expanded(
            child: Text(
              'Tema Seçimi',
              style: TextStyle(
                color: theme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, AppTheme theme) {
    return Text(
      label,
      style: TextStyle(
        color: theme.primary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPresetRow(AppTheme theme) {
    final presets = [
      (AppTheme.starry, '✦'),
      (AppTheme.geometric, '⬡'),
      (AppTheme.geometricLight, '✧'),
      (AppTheme.light, '☀️'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: presets.map((item) {
        final preset = item.$1;
        final iconStr = item.$2;
        return FractionallySizedBox(
          widthFactor: 0.48,
          child: _buildPresetCard(preset, iconStr, theme),
        );
      }).toList(),
    );
  }

  Widget _buildSystemToggle(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Sistemi Kullan',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Cihazının karanlık/aydınlık moduna göre otomatik değişir',
          style: TextStyle(color: theme.textMuted, fontSize: 12),
        ),
        value: isFollowingSystemBrightness,
        activeThumbColor: theme.primary,
        onChanged: (value) {
          if (value) {
            _applied = true;
            useSystemTheme();
            Navigator.pop(context);
          } else {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildPresetCard(AppTheme preset, String iconSymbol, AppTheme currentTheme) {
    final isActive =
        !isFollowingSystemBrightness && currentTheme.type == preset.type;
    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? preset.primary.withValues(alpha: 0.25)
              : preset.background.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? preset.primary
                : preset.primary.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: preset.primary.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Text(
              iconSymbol,
              style: TextStyle(
                color: preset.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      color: preset.textColor,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: preset.paletteColors.map((c) {
                      return Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: preset.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

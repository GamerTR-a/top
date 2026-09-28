import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

/// Kıble Pusulası — cihazın pusulasını gerçek kuzeye hizalar,
/// Kabe yönünü (kıble) altın iğne ile gösterir. Sakarya dışında da çalışır.
class QiblaCompassScreen extends StatefulWidget {
  const QiblaCompassScreen({super.key});

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  bool _locating = true;
  double? _qiblaBearing;
  double? _kaabaKm;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      final bearing = LocationService.qiblaBearing(pos.latitude, pos.longitude);
      final km = LocationService.distanceToKaabaKm(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _qiblaBearing = bearing;
        _kaabaKm = km;
        _locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = 'Konum alınamadı. GPS\'i açıp tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: theme.textColor),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Text(
              'Kıble Pusulası 🧭',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<CompassEvent?>(
                      stream: FlutterCompass.events,
                      builder: (context, snap) {
                        final heading = snap.data?.heading;
                        return Center(
                          child: _locating
                              ? const CircularProgressIndicator()
                              : _buildCompass(
                                  theme,
                                  heading,
                                  _qiblaBearing ?? 0,
                                ),
                        );
                      },
                    ),
                  ),
                  _buildInfoCard(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompass(AppTheme theme, double? heading, double bearing) {
    final headingRad = (heading ?? 0) * math.pi / 180;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kadran + kıble iğnesi: birlikte -heading kadar döner
        // (kuzey her zaman gerçek kuzeyi gösterir).
        Transform.rotate(
          angle: -headingRad,
          child: CustomPaint(
            size: const Size(280, 280),
            painter: _CompassPainter(
              dialColor: theme.isDark ? theme.surface : Colors.white,
              tickColor: theme.textMuted,
              cardinalColor: theme.textColor,
              primary: theme.primary,
              gold: const Color(0xFFFFD700),
              bearing: bearing,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (heading == null)
          Text(
            'Pusula sensörü bulunamadı — iğne sabit kaldı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.warning, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildInfoCard(AppTheme theme) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.error, fontSize: 13),
        ),
      );
    }
    final bearing = _qiblaBearing;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.surface.withValues(alpha: 0.8)
            : theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(theme, Icons.explore_rounded, 'Kıble Yönü',
              bearing == null ? '--' : '${bearing.round()}°'),
          Container(
            width: 1,
            height: 36,
            color: theme.textMuted.withValues(alpha: 0.3),
          ),
          _stat(theme, Icons.near_me_rounded, 'Kabe Uzaklığı',
              _kaabaKm == null ? '--' : '~${_kaabaKm!.round()} km'),
        ],
      ),
    );
  }

  Widget _stat(AppTheme theme, IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  final Color dialColor;
  final Color tickColor;
  final Color cardinalColor;
  final Color primary;
  final Color gold;
  final double bearing;

  _CompassPainter({
    required this.dialColor,
    required this.tickColor,
    required this.cardinalColor,
    required this.primary,
    required this.gold,
    required this.bearing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;

    // Zemin + çerçeve
    canvas.drawCircle(c, radius, Paint()..color = dialColor);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 5°'lik taksimatlar; her 30°'de belirgin
    for (var i = 0; i < 72; i++) {
      final deg = i * 5.0;
      final isMajor = i % 6 == 0;
      final a = deg * math.pi / 180;
      final dx = math.sin(a);
      final dy = -math.cos(a);
      final rInner = isMajor ? radius - 22 : radius - 14;
      final rOuter = radius - 6;
      canvas.drawLine(
        Offset(c.dx + dx * rInner, c.dy + dy * rInner),
        Offset(c.dx + dx * rOuter, c.dy + dy * rOuter),
        Paint()
          ..color = tickColor
          ..strokeWidth = isMajor ? 3 : 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Ana yön harfleri (Kuzey-Doğu-Güney-Batı)
    _drawLabel(canvas, c, radius - 42, 0, 'K', true);
    _drawLabel(canvas, c, radius - 42, 90, 'D', false);
    _drawLabel(canvas, c, radius - 42, 180, 'G', false);
    _drawLabel(canvas, c, radius - 42, 270, 'B', false);

    // Kıble iğnesi: bearing yönünü gösteren altın ok
    final b = bearing * math.pi / 180;
    final dir = Offset(math.sin(b), -math.cos(b)); // yukarıdan saat yönünde
    final perp = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (radius - 36);
    final tail = c + dir * 16;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tail.dx + perp.dx * 15, tail.dy + perp.dy * 15)
      ..lineTo(tail.dx - perp.dx * 15, tail.dy - perp.dy * 15)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = gold
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawPath(path, Paint()..color = gold);
    canvas.drawPath(
      path,
      Paint()
        ..color = gold.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Merkez nokta (Kabe)
    canvas.drawCircle(c, 5, Paint()..color = gold);
  }

  void _drawLabel(Canvas canvas, Offset c, double r, double deg, String text,
      bool strong) {
    final a = deg * math.pi / 180;
    final pos = Offset(c.dx + math.sin(a) * r, c.dy - math.cos(a) * r);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: strong ? primary : cardinalColor,
          fontSize: strong ? 20 : 15,
          fontWeight: strong ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.dialColor != dialColor ||
      old.tickColor != tickColor ||
      old.cardinalColor != cardinalColor ||
      old.primary != primary ||
      old.bearing != bearing;
}

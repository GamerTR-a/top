import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedThemeBackground extends StatefulWidget {
  final Widget child;
  final AppTheme? themeOverride;

  const AnimatedThemeBackground({
    super.key,
    required this.child,
    this.themeOverride,
  });

  @override
  State<AnimatedThemeBackground> createState() =>
      _AnimatedThemeBackgroundState();
}

class _AnimatedThemeBackgroundState extends State<AnimatedThemeBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Starry Data
  late final List<_StarData> _stars;
  late final List<_ShooterData> _shooters;
  late final List<_LaserData> _lasers;

  // Geometric Data
  late final List<_NodeData> _nodes;

  // Custom Bubble Data
  late final List<_BubbleData> _bubbles;
  late final List<_StripData> _strips;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3600), // continuous long running time tick
    );
    // Sistem "Hareketi Azalt" tercihi didChangeDependencies'te uygulanır
    // (MediaQuery burada henüz hazır değil) — bkz. kontrol.md Bölüm 21.8.

    final rng = Random(42);

    // Starry Init
    _stars = List.generate(
      120,
      (i) => _StarData(
        xRatio: rng.nextDouble(),
        yRatio: rng.nextDouble(),
        radius: rng.nextDouble() > 0.7 ? (rng.nextDouble() * 1.5 + 1.0) : (rng.nextDouble() * 0.8 + 0.3),
        speed: rng.nextDouble() * 1.5 + 0.5,
        phase: rng.nextDouble() * pi * 2,
        isBright: rng.nextDouble() > 0.7,
        isBlue: rng.nextDouble() > 0.5,
      ),
    );

    _shooters = List.generate(
      3,
      (i) => _ShooterData(
        startDelay: i * 3.5,
        duration: 1.8,
        startXRatio: rng.nextDouble() * 0.7,
        startYRatio: rng.nextDouble() * 0.4,
        dx: rng.nextDouble() * 250 + 200,
        dy: rng.nextDouble() * 150 + 100,
        length: 110 + rng.nextDouble() * 60,
      ),
    );

    _lasers = List.generate(
      4,
      (i) => _LaserData(
        startDelay: i * 2.2,
        duration: 2.2,
        startXRatio: rng.nextDouble() * 0.8 - 0.1,
        startYRatio: rng.nextDouble() * 0.6 - 0.1,
        angle: pi / 6 + rng.nextDouble() * (pi / 5),
        speed: 400 + rng.nextDouble() * 200,
        length: 220 + rng.nextDouble() * 120,
        width: 1.0 + rng.nextDouble() * 0.8,
      ),
    );

    // Geometric Init
    _nodes = List.generate(
      45,
      (i) => _NodeData(
        xRatio: rng.nextDouble(),
        yRatio: rng.nextDouble(),
        vx: (rng.nextDouble() - 0.5) * 0.12,
        vy: (rng.nextDouble() - 0.5) * 0.12,
        radius: rng.nextDouble() * 2.0 + 1.5,
      ),
    );

    // Fallback Bubbles
    _bubbles = List.generate(
      12,
      (i) => _BubbleData(
        x: rng.nextDouble(),
        radius: 10 + rng.nextDouble() * 32,
        speed: 0.08 + rng.nextDouble() * 0.12,
        phase: rng.nextDouble(),
        colorIndex: i % 3,
      ),
    );
    _strips = List.generate(
      5,
      (i) => _StripData(
        phase: rng.nextDouble(),
        width: 0.04 + rng.nextDouble() * 0.07,
        angle: -0.7 + rng.nextDouble() * 0.5,
        speed: 0.03 + rng.nextDouble() * 0.05,
        colorIndex: i % 3,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kullanıcı sistem ayarlarından "Hareketi Azalt"ı açıp kapatırsa bu
    // metod tekrar çağrılır (MediaQuery değişikliği) — sürekli dönen dekoratif
    // animasyon durur/yeniden başlar, arka plan yine de statik olarak görünür.
    // (.stop()/.repeat() zaten aynı durumdaysa no-op'tur, ekstra kontrole gerek yok.)
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, themeFromNotifier, _) {
        final theme = widget.themeOverride ?? themeFromNotifier;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: theme.type == ThemeType.geometricLight
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFC7D7E8),
                      Color(0xFFF4F8FA),
                      Color(0xFFD3E1F0),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  )
                : null,
            color: theme.type == ThemeType.geometricLight ? null : theme.background,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    final elapsed = _controller.value * 3600.0;
                    switch (theme.type) {
                      case ThemeType.starry:
                        return CustomPaint(
                          painter: _StarryPainter(
                            elapsed: elapsed,
                            stars: _stars,
                            shooters: _shooters,
                            lasers: _lasers,
                          ),
                        );
                      case ThemeType.geometric:
                        return CustomPaint(
                          painter: _GeometricPainter(
                            elapsed: elapsed,
                            nodes: _nodes,
                          ),
                        );
                      case ThemeType.geometricLight:
                        return CustomPaint(
                          painter: _GeometricPainter(
                            elapsed: elapsed,
                            nodes: _nodes,
                            isLight: true,
                          ),
                        );
                      case ThemeType.light:
                        return const SizedBox.shrink();
                      case ThemeType.custom:
                        return CustomPaint(
                          painter: _DecorPainter(
                            colors: theme.paletteColors,
                            t: elapsed % 14.0 / 14.0,
                            bubbles: _bubbles,
                            strips: _strips,
                          ),
                        );
                    }
                  },
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 1. STARRY PAINTER (Yıldızlı Tema)
// ==========================================
class _StarryPainter extends CustomPainter {
  final double elapsed;
  final List<_StarData> stars;
  final List<_ShooterData> shooters;
  final List<_LaserData> lasers;

  _StarryPainter({
    required this.elapsed,
    required this.stars,
    required this.shooters,
    required this.lasers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Stars
    for (final s in stars) {
      final pulse = (sin(elapsed * s.speed + s.phase) + 1.0) * 0.5;
      final alpha = s.isBright ? (pulse * 0.7 + 0.28) : (pulse * 0.42 + 0.08);
      final color = s.isBlue
          ? Color.fromRGBO(140, 210, 255, alpha)
          : Color.fromRGBO(235, 245, 255, alpha);

      final center = Offset(s.xRatio * size.width, s.yRatio * size.height);

      if (s.isBright) {
        final haloRadius = s.radius * 5.0;
        canvas.drawCircle(
          center,
          haloRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                s.isBlue
                    ? Color.fromRGBO(80, 190, 255, alpha * 0.35)
                    : Color.fromRGBO(200, 230, 255, alpha * 0.25),
                const Color.fromRGBO(0, 0, 0, 0),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
        );
      }

      canvas.drawCircle(center, s.radius, Paint()..color = color);
    }

    // 2. Shooting Stars
    for (final sh in shooters) {
      final cycleTime = (elapsed + sh.startDelay) % 6.0;
      if (cycleTime < sh.duration) {
        final progress = cycleTime / sh.duration;
        final alpha = (1.0 - progress).clamp(0.0, 1.0);

        final headX = (sh.startXRatio * size.width) + (sh.dx * progress);
        final headY = (sh.startYRatio * size.height) + (sh.dy * progress);
        final tailX = headX - (sh.dx / sqrt(sh.dx * sh.dx + sh.dy * sh.dy)) * sh.length;
        final tailY = headY - (sh.dy / sqrt(sh.dx * sh.dx + sh.dy * sh.dy)) * sh.length;

        final head = Offset(headX, headY);
        final tail = Offset(tailX, tailY);

        // Core line
        final corePaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color.fromRGBO(120, 210, 255, 0),
              Color.fromRGBO(200, 235, 255, 0.7 * alpha),
              Color.fromRGBO(255, 255, 255, alpha),
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(Rect.fromPoints(tail, head))
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(tail, head, corePaint);
      }
    }

    // 3. Red Laser Lines
    for (final l in lasers) {
      final cycleTime = (elapsed + l.startDelay) % 4.5;
      if (cycleTime < l.duration) {
        final progress = cycleTime / l.duration;
        final alpha = sin(progress * pi) * 0.85; // smooth fade in and out

        final dist = progress * l.speed;
        final headX = (l.startXRatio * size.width) + cos(l.angle) * dist;
        final headY = (l.startYRatio * size.height) + sin(l.angle) * dist;
        final tailX = headX - cos(l.angle) * l.length;
        final tailY = headY - sin(l.angle) * l.length;

        final head = Offset(headX, headY);
        final tail = Offset(tailX, tailY);

        // Outer Red Glow
        final outerPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color.fromRGBO(200, 0, 30, 0),
              Color.fromRGBO(220, 10, 40, 0.2 * alpha),
              Color.fromRGBO(255, 30, 60, 0.45 * alpha),
            ],
          ).createShader(Rect.fromPoints(tail, head))
          ..strokeWidth = l.width * 12.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(tail, head, outerPaint);

        // Mid Glow
        final midPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color.fromRGBO(230, 0, 40, 0),
              Color.fromRGBO(240, 20, 50, 0.55 * alpha),
              Color.fromRGBO(255, 40, 70, 0.9 * alpha),
            ],
          ).createShader(Rect.fromPoints(tail, head))
          ..strokeWidth = l.width * 3.5
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(tail, head, midPaint);

        // Sharp Core
        final corePaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color.fromRGBO(255, 60, 80, 0),
              Color.fromRGBO(255, 60, 80, 0.8 * alpha),
              Color.fromRGBO(255, 220, 225, alpha),
            ],
          ).createShader(Rect.fromPoints(tail, head))
          ..strokeWidth = l.width;

        canvas.drawLine(tail, head, corePaint);

        // Tip Flash
        canvas.drawCircle(
          head,
          l.width * 6.0,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.fromRGBO(255, 200, 210, 0.9 * alpha),
                Color.fromRGBO(255, 40, 70, 0.4 * alpha),
                const Color.fromRGBO(200, 0, 30, 0),
              ],
            ).createShader(Rect.fromCircle(center: head, radius: l.width * 6.0)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarryPainter oldDelegate) => true;
}

// ==========================================
// 2. GEOMETRIC PAINTER (Geometrik Tema)
// ==========================================
class _GeometricPainter extends CustomPainter {
  final double elapsed;
  final List<_NodeData> nodes;
  final bool isLight;

  _GeometricPainter({
    required this.elapsed,
    required this.nodes,
    this.isLight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxDist = size.width < 500 ? 120.0 : 150.0;

    final nodeColor = isLight
        ? const Color.fromRGBO(91, 123, 156, 0.55)
        : const Color.fromRGBO(99, 102, 241, 0.65);

    final positions = <Offset>[];
    for (final n in nodes) {
      double curX = (n.xRatio + n.vx * elapsed) % 1.0;
      double curY = (n.yRatio + n.vy * elapsed) % 1.0;
      if (curX < 0) curX += 1.0;
      if (curY < 0) curY += 1.0;

      final pos = Offset(curX * size.width, curY * size.height);
      positions.add(pos);

      // Draw Node
      canvas.drawCircle(
        pos,
        n.radius,
        Paint()..color = nodeColor,
      );
    }

    // Draw connecting lines
    final linePaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < positions.length - 1; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final dx = positions[i].dx - positions[j].dx;
        final dy = positions[i].dy - positions[j].dy;
        final d = sqrt(dx * dx + dy * dy);

        if (d < maxDist) {
          final alpha = (1.0 - d / maxDist) * (isLight ? 0.32 : 0.35);
          linePaint.color = isLight
              ? Color.fromRGBO(91, 123, 156, alpha)
              : Color.fromRGBO(99, 102, 241, alpha);
          canvas.drawLine(positions[i], positions[j], linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeometricPainter oldDelegate) => true;
}

// ==========================================
// 3. DEFAULT BUBBLE PAINTER (Özel)
// ==========================================
// 4. DEFAULT BUBBLE PAINTER (Orman/Okyanus/Özel)
// ==========================================
class _DecorPainter extends CustomPainter {
  final List<Color> colors;
  final double t;
  final List<_BubbleData> bubbles;
  final List<_StripData> strips;

  _DecorPainter({
    required this.colors,
    required this.t,
    required this.bubbles,
    required this.strips,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    for (final s in strips) {
      _drawStrip(canvas, size, s);
    }
    for (final b in bubbles) {
      _drawBubble(canvas, size, b);
    }
  }

  void _drawBubble(Canvas canvas, Size size, _BubbleData b) {
    final color = colors[b.colorIndex % colors.length];
    final normalizedY = 1.0 - ((t * b.speed + b.phase) % 1.0);
    final x = b.x * size.width;
    final y = normalizedY * size.height;
    final r = b.radius;

    canvas.drawCircle(
      Offset(x, y),
      r * 2.4,
      Paint()
        ..color = color.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.06),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
    );

    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawCircle(
      Offset(x - r * 0.28, y - r * 0.28),
      r * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  void _drawStrip(Canvas canvas, Size size, _StripData s) {
    final color = colors[s.colorIndex % colors.length];
    final phase = (t * s.speed + s.phase) % 1.0;
    final x = phase * size.width * 1.7 - size.width * 0.35;
    final w = s.width * size.width;
    final h = size.height * 3.0;

    canvas.save();
    canvas.translate(x, size.height / 2);
    canvas.rotate(s.angle);

    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DecorPainter old) => old.t != t || old.colors != colors;
}

// Data Helper Classes
class _StarData {
  final double xRatio, yRatio, radius, speed, phase;
  final bool isBright, isBlue;
  const _StarData({
    required this.xRatio,
    required this.yRatio,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.isBright,
    required this.isBlue,
  });
}

class _ShooterData {
  final double startDelay, duration, startXRatio, startYRatio, dx, dy, length;
  const _ShooterData({
    required this.startDelay,
    required this.duration,
    required this.startXRatio,
    required this.startYRatio,
    required this.dx,
    required this.dy,
    required this.length,
  });
}

class _LaserData {
  final double startDelay, duration, startXRatio, startYRatio, angle, speed, length, width;
  const _LaserData({
    required this.startDelay,
    required this.duration,
    required this.startXRatio,
    required this.startYRatio,
    required this.angle,
    required this.speed,
    required this.length,
    required this.width,
  });
}

class _NodeData {
  final double xRatio, yRatio, vx, vy, radius;
  const _NodeData({
    required this.xRatio,
    required this.yRatio,
    required this.vx,
    required this.vy,
    required this.radius,
  });
}


class _BubbleData {
  final double x, radius, speed, phase;
  final int colorIndex;
  const _BubbleData({
    required this.x,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.colorIndex,
  });
}

class _StripData {
  final double phase, width, angle, speed;
  final int colorIndex;
  const _StripData({
    required this.phase,
    required this.width,
    required this.angle,
    required this.speed,
    required this.colorIndex,
  });
}


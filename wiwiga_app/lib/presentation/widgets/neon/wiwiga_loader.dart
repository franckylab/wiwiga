import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Loader WIWIGA — LJ DUAL (2 lumières 1.8s + W double 0.85s)
///
/// Choix validé V2 : LJ — DUAL
/// - Cadre : 2 lumières opposées parcourant le squircle sans fin (1.8s linear)
///   Lumière 1 : #2DD4BF (primary) — Lumière 2 : #F59E0B (secondary)
///   Segment 32/328 dash, offset 0 et 0.5 (180°)
/// - W : double battement cœur 0.85s ease-in-out (1 → 1.16 → 0.96 → 1.16 → 1)
/// - Contexte : avec cadre en splash/PWA (100/48), sans cadre en inline/bouton (20/16) — W seul bat
///
/// Usage :
/// ```dart
/// WiwigaLoader(size: 100, withFrame: true)  // splash
/// WiwigaLoader(size: 48, withFrame: true)   // overlay
/// WiwigaLoader(size: 20, withFrame: false) // inline
/// ```
class WiwigaLoader extends StatefulWidget {
  final double size;
  final bool withFrame;
  final Color? color;
  final Color? secondaryColor;

  const WiwigaLoader({
    super.key,
    this.size = 48,
    this.withFrame = true,
    this.color,
    this.secondaryColor,
  });

  @override
  State<WiwigaLoader> createState() => _WiwigaLoaderState();
}

class _WiwigaLoaderState extends State<WiwigaLoader>
    with TickerProviderStateMixin {
  late AnimationController _cadreController;
  late AnimationController _heartController;
  late Animation<double> _heartAnim;

  @override
  void initState() {
    super.initState();
    // Cadre : 1.8s linear infini
    _cadreController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    // W : double battement 0.85s
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 850),
      vsync: this,
    )..repeat();

    // Courbe cœur double : 0→0.12→0.22→0.32→0.48→1
    // On approxime avec TweenSequence
    _heartAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.16, end: 0.96).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.16).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.16, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.linear)), weight: 52),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _cadreController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect prefers-reduced-motion : si animation désactivée, figer
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;

    if (reduceMotion) {
      return _buildStatic();
    }

    final primary = widget.color ?? NeonColors.primary;
    final secondary = widget.secondaryColor ?? NeonColors.secondary;

    if (!widget.withFrame) {
      // Sans cadre : W seul qui bat
      return AnimatedBuilder(
        animation: _heartAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _heartAnim.value,
            child: child,
          );
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _WOnlyPainter(color: primary, withCadreW: false),
          ),
        ),
      );
    }

    // Avec cadre : Stack cadre dim + 2 lumières + W battant
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cadre dim de fond
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _CadreDimPainter(color: primary),
            ),
          ),
          // Lumières
          AnimatedBuilder(
            animation: _cadreController,
            builder: (context, _) {
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _DualLightPainter(
                    progress: _cadreController.value,
                    color1: primary,
                    color2: secondary,
                  ),
                ),
              );
            },
          ),
          // W battant
          AnimatedBuilder(
            animation: _heartAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: _heartAnim.value,
                child: child,
              );
            },
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _WOnlyPainter(color: primary, withCadreW: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatic() {
    final primary = widget.color ?? NeonColors.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _WOnlyPainter(color: primary, withCadreW: widget.withFrame),
      ),
    );
  }
}

/// W seul (sans ou avec cadre coords)
class _WOnlyPainter extends CustomPainter {
  final Color color;
  final bool withCadreW;

  _WOnlyPainter({required this.color, required this.withCadreW});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _wStroke(s, withCadreW)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final path = Path();
    double px(double v) => v / 100 * s;
    if (withCadreW) {
      // Avec cadre : M22 36 L33 67 L44 44.5 L56 44.5 L67 67 L78 36
      path.moveTo(px(22), px(36));
      path.lineTo(px(33), px(67));
      path.lineTo(px(44), px(44.5));
      path.lineTo(px(56), px(44.5));
      path.lineTo(px(67), px(67));
      path.lineTo(px(78), px(36));
    } else {
      // Sans cadre : M20 36 L32 68 L44.5 44 L55.5 44 L68 68 L80 36
      path.moveTo(px(20), px(36));
      path.lineTo(px(32), px(68));
      path.lineTo(px(44.5), px(44));
      path.lineTo(px(55.5), px(44));
      path.lineTo(px(68), px(68));
      path.lineTo(px(80), px(36));
    }
    canvas.drawPath(path, paint);
  }

  double _wStroke(double s, bool withCadre) {
    if (withCadre) {
      if (s <= 20) return s * 0.11;
      if (s <= 34) return s * 0.075;
      return s * 0.048;
    } else {
      if (s <= 20) return s * 0.11;
      if (s <= 34) return s * 0.072;
      return s * 0.062;
    }
  }

  @override
  bool shouldRepaint(covariant _WOnlyPainter old) => color != old.color || withCadreW != old.withCadreW;
}

/// Cadre dim de fond (hairline faible)
class _CadreDimPainter extends CustomPainter {
  final Color color;
  _CadreDimPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final x = s * 0.11;
    final y = s * 0.11;
    final w = s * 0.78;
    final h = s * 0.78;
    final rx = s * 0.24;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx));
    final paint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, paint);
  }
  @override
  bool shouldRepaint(covariant _CadreDimPainter old) => color != old.color;
}

/// 2 lumières opposées parcourant le cadre
class _DualLightPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color1;
  final Color color2;

  _DualLightPainter({required this.progress, required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Construire le path du cadre (squircle)
    final x = s * 0.11;
    final y = s * 0.11;
    final w = s * 0.78;
    final h = s * 0.78;
    final rx = s * 0.24;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx));
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final total = metric.length;
    // dash 32/360 => 8.9% du périmètre
    final dash = total * 0.089;
    // On dessine 2 segments opposés
    _drawSegment(canvas, metric, total, dash, progress, color1, s);
    _drawSegment(canvas, metric, total, dash, (progress + 0.5) % 1.0, color2, s);
  }

  void _drawSegment(Canvas canvas, ui.PathMetric metric, double total, double dash, double prog, Color color, double size) {
    final start = prog * total;
    final end = start + dash;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.022 // lumière un peu plus épaisse que hairline (1.2% -> 2.2%)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (end <= total) {
      final seg = metric.extractPath(start, end);
      canvas.drawPath(seg, paint);
      // Glow subtil
      final glow = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.04
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..isAntiAlias = true;
      canvas.drawPath(seg, glow);
    } else {
      // Wrap autour
      final seg1 = metric.extractPath(start, total);
      final seg2 = metric.extractPath(0, end - total);
      canvas.drawPath(seg1, paint);
      canvas.drawPath(seg2, paint);
      final glow = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.04
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..isAntiAlias = true;
      canvas.drawPath(seg1, glow);
      canvas.drawPath(seg2, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _DualLightPainter old) =>
      progress != old.progress || color1 != old.color1 || color2 != old.color2;
}

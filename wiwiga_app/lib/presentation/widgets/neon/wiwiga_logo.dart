import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Logo WIWIGA — Q CADRE GRAS (hairline 1.2 + W plein)
///
/// Choix validé : Q — cadre hairline fin + W plein.
/// - [LogoVariant.icon] : glyph seul
///   - sans cadre (par défaut) → W plein fin (header, favicon 16/32/48)
///   - avec cadre (withFrame: true) → W plein + squircle hairline (PWA 192/512, stores)
/// - [LogoVariant.full] : icon + texte "WIWIGA" (Orbitron)
/// - [LogoVariant.text] : texte seul
///
/// Design sobre, 1 couleur, trait fin, optimisé favicon.
/// Favicon 16px : stroke épaissi auto (11% vs 6.2% en grand) pour lisibilité.
class WiwigaLogo extends StatelessWidget {
  final LogoVariant variant;
  final double size;
  final bool animated;
  final Color? color;
  final bool withFrame;

  const WiwigaLogo({
    super.key,
    this.variant = LogoVariant.full,
    this.size = 48,
    this.animated = false,
    this.color,
    this.withFrame = false,
  });

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return _AnimatedLogo(
        variant: variant,
        size: size,
        color: color,
        withFrame: withFrame,
      );
    }
    switch (variant) {
      case LogoVariant.full:
        return _buildFullLogo();
      case LogoVariant.icon:
        return _buildIcon();
      case LogoVariant.text:
        return _buildText();
    }
  }

  Widget _buildFullLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(),
        const SizedBox(width: 10),
        _buildText(),
      ],
    );
  }

  Widget _buildIcon() {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _QLogoPainter(
          color: color,
          withFrame: withFrame,
        ),
      ),
    );
  }

  Widget _buildText() {
    return Text(
      'WIWIGA',
      style: TextStyle(
        fontSize: size * 0.48,
        fontWeight: FontWeight.w800,
        color: color ?? NeonColors.primary,
        fontFamily: 'Orbitron',
        letterSpacing: 3.2,
        // Sobre : pas de glow par défaut (glow uniquement au hover si besoin)
      ),
    );
  }
}

enum LogoVariant { full, icon, text }

/// Painter Q — deux rendus :
/// - sans cadre : W plein fin (M20 36 ...) stroke 6.2% (11% si ≤24px)
/// - avec cadre : squircle rx24 stroke 1.2% + W M22 36 ... stroke 4.8%
class _QLogoPainter extends CustomPainter {
  final Color? color;
  final bool withFrame;

  _QLogoPainter({this.color, this.withFrame = false});

  @override
  void paint(Canvas canvas, Size size) {
    final primaryColor = color ?? NeonColors.primary;
    final s = size.width; // carré
    // Stroke adaptatif favicon-first
    final double wStroke;
    final double cadreStroke;
    if (withFrame) {
      if (s <= 20) {
        wStroke = s * 0.11;
        cadreStroke = s * 0.045;
      } else if (s <= 34) {
        wStroke = s * 0.075;
        cadreStroke = s * 0.028;
      } else {
        wStroke = s * 0.048;
        cadreStroke = s * 0.012;
      }
    } else {
      if (s <= 20) {
        wStroke = s * 0.11;
        cadreStroke = 0;
      } else if (s <= 34) {
        wStroke = s * 0.072;
        cadreStroke = 0;
      } else {
        wStroke = s * 0.062;
        cadreStroke = 0;
      }
    }

    if (withFrame) {
      _drawCadre(canvas, size, primaryColor, cadreStroke);
      _drawWAvecCadre(canvas, size, primaryColor, wStroke);
    } else {
      _drawWSansCadre(canvas, size, primaryColor, wStroke);
    }
  }

  void _drawCadre(Canvas canvas, Size size, Color color, double strokeWidth) {
    final s = size.width;
    // Cadre : x11 y11 w78 h78 rx24 in viewBox 100
    final double x = s * 0.11;
    final double y = s * 0.11;
    final double w = s * 0.78;
    final double h = s * 0.78;
    final double rx = s * 0.24;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(rx),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, paint);
  }

  // Q sans cadre : M20 36 L32 68 L44.5 44 L55.5 44 L68 68 L80 36
  void _drawWSansCadre(Canvas canvas, Size size, Color color, double strokeWidth) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();
    // Points scaled 0-100 -> 0-s
    double px(double v) => v / 100 * s;
    path.moveTo(px(20), px(36));
    path.lineTo(px(32), px(68));
    path.lineTo(px(44.5), px(44));
    path.lineTo(px(55.5), px(44));
    path.lineTo(px(68), px(68));
    path.lineTo(px(80), px(36));
    canvas.drawPath(path, paint);
  }

  // Q avec cadre : M22 36 L33 67 L44 44.5 L56 44.5 L67 67 L78 36
  void _drawWAvecCadre(Canvas canvas, Size size, Color color, double strokeWidth) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();
    double px(double v) => v / 100 * s;
    path.moveTo(px(22), px(36));
    path.lineTo(px(33), px(67));
    path.lineTo(px(44), px(44.5));
    path.lineTo(px(56), px(44.5));
    path.lineTo(px(67), px(67));
    path.lineTo(px(78), px(36));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QLogoPainter oldDelegate) =>
      color != oldDelegate.color || withFrame != oldDelegate.withFrame;
}

/// Logo animé — pulse subtil (optionnel, sobre)
class _AnimatedLogo extends StatefulWidget {
  final LogoVariant variant;
  final double size;
  final Color? color;
  final bool withFrame;

  const _AnimatedLogo({
    required this.variant,
    required this.size,
    this.color,
    this.withFrame = false,
  });

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: child,
        );
      },
      child: WiwigaLogo(
        variant: widget.variant,
        size: widget.size,
        color: widget.color,
        withFrame: widget.withFrame,
      ),
    );
  }
}

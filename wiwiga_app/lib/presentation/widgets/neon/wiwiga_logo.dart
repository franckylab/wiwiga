import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Logo WIWIGA dessine en CustomPainter
/// 
/// Variantes disponibles :
/// - [full] : Icone hexagonale + texte "WIWIGA"
/// - [icon] : Icone hexagonale seule
/// - [text] : Texte "WIWIGA" seul
class WiwigaLogo extends StatelessWidget {
  final LogoVariant variant;
  final double size;
  final bool animated;
  final Color? color;

  const WiwigaLogo({
    super.key,
    this.variant = LogoVariant.full,
    this.size = 48,
    this.animated = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return _AnimatedLogo(variant: variant, size: size, color: color);
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
        const SizedBox(width: 8),
        _buildText(),
      ],
    );
  }

  Widget _buildIcon() {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoIconPainter(color: color),
      ),
    );
  }

  Widget _buildText() {
    return Text(
      'WIWIGA',
      style: TextStyle(
        fontSize: size * 0.5,
        fontWeight: FontWeight.bold,
        color: color ?? NeonColors.primary,
        fontFamily: 'Orbitron',
        letterSpacing: 2,
        shadows: [
          Shadow(
            color: (color ?? NeonColors.primary).withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

enum LogoVariant { full, icon, text }

class _LogoIconPainter extends CustomPainter {
  final Color? color;

  _LogoIconPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final primaryColor = color ?? NeonColors.primary;

    // Glow externe
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(_hexPath(center, radius * 0.92), glowPaint);

    // Fond hexagonal
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.3),
          primaryColor.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(_hexPath(center, radius * 0.88), bgPaint);

    // Bordure hexagonale
    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, NeonColors.accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06;
    canvas.drawPath(_hexPath(center, radius * 0.88), borderPaint);

    // "W" interieur
    _drawW(canvas, center, radius, primaryColor);
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawW(Canvas canvas, Offset center, double radius, Color color) {
    final wPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = radius * 0.45;
    final h = radius * 0.35;
    final sx = center.dx - w;
    final sy = center.dy - h;

    final path = Path();
    path.moveTo(sx, sy);
    path.lineTo(sx + w * 0.5, sy + h * 2);
    path.lineTo(sx + w * 0.75, sy + h * 0.8);
    path.lineTo(sx + w * 1.25, sy + h * 0.8);
    path.lineTo(sx + w * 1.5, sy + h * 2);
    path.lineTo(sx + w * 2, sy);

    canvas.drawPath(path, wPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      color != (oldDelegate as _LogoIconPainter).color;
}

/// Logo anime avec glow pulse et rotation subtile
class _AnimatedLogo extends StatefulWidget {
  final LogoVariant variant;
  final double size;
  final Color? color;

  const _AnimatedLogo({
    required this.variant,
    required this.size,
    this.color,
  });

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
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
        return Transform.rotate(
          angle: _rotateAnimation.value,
          child: Opacity(
            opacity: 0.85 + (_glowAnimation.value * 0.15),
            child: child,
          ),
        );
      },
      child: WiwigaLogo(
        variant: widget.variant,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}

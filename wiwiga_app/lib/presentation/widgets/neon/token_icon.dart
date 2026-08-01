import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Icone de jeton WIWIGA dessinee en CustomPainter
/// 
/// Represente une piece hexagonale neon avec un "W" stylise.
/// Utilise en inline dans toute l'app pour designer les jetons.
class TokenIcon extends StatelessWidget {
  final double size;
  final TokenVariant variant;
  final bool animated;

  const TokenIcon({
    super.key,
    this.size = 24,
    this.variant = TokenVariant.normal,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return _AnimatedTokenIcon(size: size, variant: variant);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TokenPainter(variant: variant),
      ),
    );
  }
}

enum TokenVariant {
  normal,   // Emeraude neon
  gold,     // Dore premium
  silver,   // Argent
  small,    // Reduit inline
}

class _TokenPainter extends CustomPainter {
  final TokenVariant variant;

  _TokenPainter({this.variant = TokenVariant.normal});

  Color get _primaryColor {
    switch (variant) {
      case TokenVariant.normal:
      case TokenVariant.small:
        return NeonColors.tokenPrimary;
      case TokenVariant.gold:
        return NeonColors.tokenGold;
      case TokenVariant.silver:
        return NeonColors.tokenSilver;
    }
  }

  Color get _secondaryColor {
    switch (variant) {
      case TokenVariant.normal:
      case TokenVariant.small:
        return NeonColors.tokenGlow;
      case TokenVariant.gold:
        return const Color(0xFFFFA500);
      case TokenVariant.silver:
        return const Color(0xFFE8E8E8);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Hexagone externe avec glow
    final glowPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(_hexagonPath(center, radius * 0.95), glowPaint);

    // Hexagone principal
    final hexPaint = Paint()
      ..shader = LinearGradient(
        colors: [_primaryColor, _secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(_hexagonPath(center, radius * 0.85), hexPaint);

    // Bordure hexagonale
    final borderPaint = Paint()
      ..color = _primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06;
    canvas.drawPath(_hexagonPath(center, radius * 0.85), borderPaint);

    // Cercle interieur
    final innerPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04;
    canvas.drawCircle(center, radius * 0.6, innerPaint);

    // Lettre "W" stylisee
    _drawW(canvas, center, radius);
  }

  Path _hexagonPath(Offset center, double radius) {
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

  void _drawW(Canvas canvas, Offset center, double radius) {
    final wPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = radius * 0.5;
    final h = radius * 0.4;
    final startX = center.dx - w;
    final startY = center.dy - h;

    final wPath = Path();
    wPath.moveTo(startX, startY);
    wPath.lineTo(startX + w * 0.5, startY + h * 2);
    wPath.lineTo(startX + w * 0.75, startY + h * 0.8);
    wPath.lineTo(startX + w * 1.25, startY + h * 0.8);
    wPath.lineTo(startX + w * 1.5, startY + h * 2);
    wPath.lineTo(startX + w * 2, startY);

    // Glow behind W
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(wPath, glowPaint);

    canvas.drawPath(wPath, wPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Version animee avec rotation et pulse
class _AnimatedTokenIcon extends StatefulWidget {
  final double size;
  final TokenVariant variant;

  const _AnimatedTokenIcon({required this.size, required this.variant});

  @override
  State<_AnimatedTokenIcon> createState() => _AnimatedTokenIconState();
}

class _AnimatedTokenIconState extends State<_AnimatedTokenIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
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
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: TokenIcon(
        size: widget.size,
        variant: widget.variant,
      ),
    );
  }
}

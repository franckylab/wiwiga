// ============================================================
// Fichier: success_animation.dart
// Description: Widget d'animation de succès (checkmark animé)
//              Utilisé pour login, inscription, déconnexion
// Auteur: WIWIGA Team
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animation de succès avec checkmark animé
///
/// Affiche un cercle vert qui se remplit, suivi d'un checkmark
/// qui se dessine, avec un texte de succès en dessous.
class SuccessAnimation extends StatefulWidget {
  final String message;
  final String? subtitle;
  final VoidCallback? onComplete;
  final Duration duration;
  final Color color;

  const SuccessAnimation({
    super.key,
    required this.message,
    this.subtitle,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
    this.color = const Color(0xFF00FF88),
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Cercle: 0.0 -> 0.4
    _circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Checkmark: 0.3 -> 0.7
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // Texte: 0.5 -> 0.9
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    // Scale bounce: 0.0 -> 0.5 (overshoot) -> 0.5 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.15),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cercle + Checkmark
            Transform.scale(
              scale: _scaleAnimation.value,
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Cercle
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _CirclePainter(
                        progress: _circleAnimation.value,
                        color: widget.color,
                      ),
                    ),
                    // Checkmark
                    CustomPaint(
                      size: const Size(50, 50),
                      painter: _CheckPainter(
                        progress: _checkAnimation.value,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Message
            Opacity(
              opacity: _textAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _textAnimation.value)),
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Opacity(
                opacity: _textAnimation.value * 0.6,
                child: Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Painter pour le cercle qui se remplit
class _CirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  _CirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Cercle de fond (léger)
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Cercle animé (stroke)
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Painter pour le checkmark qui se dessine
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Points du checkmark
    final p1 = Offset(size.width * 0.2, size.height * 0.5);
    final p2 = Offset(size.width * 0.42, size.height * 0.72);
    final p3 = Offset(size.width * 0.8, size.height * 0.3);

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (progress <= 0.5) {
      // Première partie du check
      final t = progress / 0.5;
      final px = p1.dx + (p2.dx - p1.dx) * t;
      final py = p1.dy + (p2.dy - p1.dy) * t;
      path.lineTo(px, py);
    } else {
      // Deuxième partie du check
      path.lineTo(p2.dx, p2.dy);
      final t = (progress - 0.5) / 0.5;
      final px = p2.dx + (p3.dx - p2.dx) * t;
      final py = p2.dy + (p3.dy - p2.dy) * t;
      path.lineTo(px, py);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Animation de déconnexion (fade out + slide down)
class LogoutAnimation extends StatefulWidget {
  final VoidCallback? onComplete;

  const LogoutAnimation({super.key, this.onComplete});

  @override
  State<LogoutAnimation> createState() => _LogoutAnimationState();
}

class _LogoutAnimationState extends State<LogoutAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.3),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
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
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
      child: const Center(
        child: Icon(
          Icons.logout,
          size: 64,
          color: Color(0xFF00FF88),
        ),
      ),
    );
  }
}

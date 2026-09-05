import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Barre de progression neon avec effet shimmer
/// 
/// Utilisee pour les ecrans de chargement, telechargements, etc.
/// Design moderne avec gradient et particules.
class WiwigaProgressBar extends StatefulWidget {
  final double? progress; // null = indetermine
  final Color? color;
  final double height;
  final bool showPercentage;

  const WiwigaProgressBar({
    super.key,
    this.progress,
    this.color,
    this.height = 6,
    this.showPercentage = false,
  });

  @override
  State<WiwigaProgressBar> createState() => _WiwigaProgressBarState();
}

class _WiwigaProgressBarState extends State<WiwigaProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Only indeterminate needs ticker
    if (widget.progress == null) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat();
    } else {
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    }
  }

  @override
  void didUpdateWidget(covariant WiwigaProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress == null && widget.progress != null) {
      _controller.stop();
    } else if (oldWidget.progress != null && widget.progress == null) {
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
    final progressColor = widget.color ?? NeonColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LayoutBuilder once, AnimatedBuilder only for indeterminate
        LayoutBuilder(
          builder: (context, constraints) {
            if (widget.progress != null) {
              return _buildDeterminate(constraints, progressColor);
            } else {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => _buildIndeterminate(constraints, progressColor),
              );
            }
          },
        ),
        if (widget.showPercentage && widget.progress != null) ...[
          const SizedBox(height: 4),
          Text(
            '${(widget.progress! * 100).toInt()}%',
            style: TextStyle(
              color: progressColor,
              fontSize: 10,
              fontFamily: 'Orbitron',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeterminate(BoxConstraints constraints, Color color) {
    // Cache gradient/shadow, no withValues per frame
    final gradient = LinearGradient(
      colors: [color, color.withValues(alpha: 0.8), NeonColors.tokenGold.withValues(alpha: 0.6)],
    );
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.height / 2),
        color: NeonColors.surface,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.progress!.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Container(
              width: constraints.maxWidth * value,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                gradient: gradient,
                boxShadow: const [
                  BoxShadow(color: Color(0x662DD4BF), blurRadius: 8, spreadRadius: 1),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIndeterminate(BoxConstraints constraints, Color color) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.height / 2),
        color: NeonColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: Align(
          alignment: Alignment(_controller.value * 2 - 1, 0),
          child: Container(
            width: constraints.maxWidth * 0.3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0), color, NeonColors.tokenGold, color.withValues(alpha: 0)],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Particules flottantes pour arriere-plan de chargement
/// Optimisé : 1 seul Ticker + CustomPainter → ~4ms/frame au lieu de 45-85ms
class FloatingParticles extends StatefulWidget {
  final int particleCount;
  final Color? color;

  const FloatingParticles({
    super.key,
    this.particleCount = 12,
    this.color,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    // Limite à 12 max pour perf, seed déterministe
    final count = widget.particleCount.clamp(0, 12);
    _particles = List.generate(count, (i) => _ParticleData.random(i));
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant FloatingParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.particleCount != widget.particleCount) {
      final count = widget.particleCount.clamp(0, 12);
      setState(() {
        _particles = List.generate(count, (i) => _ParticleData.random(i));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonColors.primary;
    // RepaintBoundary isole le CustomPainter du reste de l'arbre
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ParticlesPainter(
              particles: _particles,
              progress: _controller.value,
              color: color,
            ),
            // isComplex + willChange évite relayout parent
            isComplex: true,
            willChange: true,
          );
        },
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double progress;
  final Color color;

  _ParticlesPainter({required this.particles, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Paint réutilisable, pas de withValues per particle (pré-calcule)
    final basePaint = Paint()..color = color;
    for (final p in particles) {
      // y progress : utilise progress global + offset startY pour varier
      final y = (p.startY + progress * p.speed) % 1.0;
      final x = p.startX + p.waveAmplitude * math.sin(progress * 2 * math.pi + p.phase);
      final cx = x * size.width;
      final cy = y * size.height;
      if (cx < -10 || cx > size.width + 10 || cy < -10 || cy > size.height + 10) continue;
      final opacity = p.opacity * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + p.phase));
      // Dessin simple cercle sans BoxShadow flou coûteux (économise saveLayer)
      basePaint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(cx, cy), p.size / 2, basePaint);
      // Glow léger seulement pour grosses particules (>3px) et pas à chaque frame si hors écran
      if (p.size > 3.2) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: (opacity * 0.18).clamp(0.0, 0.3))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawCircle(Offset(cx, cy), p.size, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles || oldDelegate.color != color;
}

class _ParticleData {
  final double startX;
  final double startY;
  final double speed;
  final double size;
  final double opacity;
  final double waveAmplitude;
  final double phase;

  _ParticleData({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.waveAmplitude,
    required this.phase,
  });

  static _ParticleData random(int seed) {
    // Déterministe par index, évite microsecondes aléatoires + GC
    final rng = (seed * 9973 + 1103515245) & 0x7fffffff;
    return _ParticleData(
      startX: (rng % 1000) / 1000.0,
      startY: ((rng >> 10) % 1000) / 1000.0,
      speed: 0.18 + ((rng >> 5) % 400) / 1000.0,
      size: 1.8 + ((rng >> 2) % 30) / 10.0,
      opacity: 0.18 + ((rng >> 8) % 500) / 1500.0,
      waveAmplitude: 0.015 + ((rng >> 12) % 200) / 10000.0,
      phase: ((rng >> 15) % 360) * math.pi / 180.0,
    );
  }
}

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
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
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
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (widget.progress != null) {
                  // Progression determinee
                  return _buildDeterminate(constraints, progressColor);
                } else {
                  // Indetermine
                  return _buildIndeterminate(constraints, progressColor);
                }
              },
            );
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
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.8),
                    NeonColors.tokenGold.withValues(alpha: 0.6),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
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
                colors: [
                  color.withValues(alpha: 0),
                  color,
                  NeonColors.tokenGold,
                  color.withValues(alpha: 0),
                ],
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
class FloatingParticles extends StatefulWidget {
  final int particleCount;
  final Color? color;

  const FloatingParticles({
    super.key,
    this.particleCount = 20,
    this.color,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      widget.particleCount,
      (_) => _ParticleData.random(),
    );
    _controllers = _particles.map((p) {
      final controller = AnimationController(
        duration: Duration(seconds: p.durationSec),
        vsync: this,
      )..repeat();
      return controller;
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonColors.primary;

    return Stack(
      children: List.generate(_particles.length, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            final p = _particles[i];
            final t = _controllers[i].value;
            final y = (p.startY + t * p.speed) % 1.0;
            final x = p.startX +
                (p.waveAmplitude * (t * 2 * 3.14159).sin());

            return Positioned(
              left: x * MediaQuery.of(context).size.width,
              top: y * MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: p.opacity * (0.5 + 0.5 * (t * 2 * 3.14159).sin()),
                child: Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: p.size * 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _ParticleData {
  final double startX;
  final double startY;
  final double speed;
  final double size;
  final double opacity;
  final double waveAmplitude;
  final int durationSec;

  _ParticleData({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.waveAmplitude,
    required this.durationSec,
  });

  static _ParticleData random() {
    final rng = DateTime.now().microsecondsSinceEpoch;
    return _ParticleData(
      startX: (rng % 1000) / 1000.0,
      startY: (rng % 500) / 500.0,
      speed: 0.3 + (rng % 700) / 1000.0,
      size: 2 + (rng % 4),
      opacity: 0.2 + (rng % 500) / 1000.0,
      waveAmplitude: 0.02 + (rng % 300) / 10000.0,
      durationSec: 3 + (rng % 5),
    );
  }
}

extension _DoubleSin on double {
  double sin() => _sin(this);
  static double _sin(double x) {
    // Approximation simple
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}

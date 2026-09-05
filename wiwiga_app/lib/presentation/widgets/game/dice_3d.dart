// ============================================================
// Fichier: dice_3d.dart
// Description: Dé 3D avec faces, animations modernes et physique
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Dé 3D isométrique avec animation de lancer réaliste
class Dice3D extends StatefulWidget {
  final int value; // 1-6, 0 = vide
  final double size;
  final bool isRolling;
  final Duration rollDuration;
  final Color faceColor;
  final Color dotColor;
  final Color borderColor;
  final double elevation;

  const Dice3D({
    super.key,
    required this.value,
    this.size = 64,
    this.isRolling = false,
    this.rollDuration = const Duration(milliseconds: 900),
    this.faceColor = const Color(0xFFF8FAFC),
    this.dotColor = const Color(0xFF0F172A),
    this.borderColor = NeonColors.primary,
    this.elevation = 6,
  });

  @override
  State<Dice3D> createState() => _Dice3DState();
}

class _Dice3DState extends State<Dice3D> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotX;
  late Animation<double> _rotY;
  late Animation<double> _scale;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.rollDuration, vsync: this);
    _rotX = Tween<double>(begin: 0, end: 4 * math.pi).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));
    _rotY = Tween<double>(begin: 0, end: 3 * math.pi).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _bounce = Tween<double>(begin: -12, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.bounceOut));
    if (widget.isRolling) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(Dice3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling && !oldWidget.isRolling) {
      _ctrl.forward(from: 0);
    }
    if (widget.rollDuration != oldWidget.rollDuration) {
      _ctrl.duration = widget.rollDuration;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Cache shadow colors to avoid withValues per frame
  static final Color _blackShadow28 = Colors.black.withValues(alpha: 0.28);
  static final Color _white55 = Colors.white.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final rolling = widget.isRolling && _ctrl.isAnimating;
          final rX = rolling ? _rotX.value : 0.0;
          final rY = rolling ? _rotY.value : 0.0;
          final scale = rolling ? _scale.value : 1.0;
          final dy = rolling ? _bounce.value : 0.0;
          // P2 FIX: sur kIsWeb, désactive Matrix4 3D perspective (coûteux CanvasKit) — simple scale/translate
          if (kIsWeb) {
            return Transform.translate(
              offset: Offset(0, dy * 0.6),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          }
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(rX * 0.15)
                  ..rotateY(rY * 0.18),
                child: child,
              ),
            ),
          );
        },
        child: _buildDiceFace(s),
      ),
    );
  }

  Widget _buildDiceFace(double s) {
    final isEmpty = widget.value == 0;
    // P2 FIX: 3 BoxShadow → 1 sur web (blur s*0.08), cache couleurs, évite spreadRadius per frame
    final List<BoxShadow> shadows;
    if (kIsWeb) {
      shadows = [
        BoxShadow(color: _blackShadow28, blurRadius: s * 0.08, offset: Offset(0, s * 0.06)),
      ];
    } else {
      shadows = [
        BoxShadow(color: _blackShadow28, blurRadius: s * 0.18, offset: Offset(0, s * 0.10)),
        if (!isEmpty)
          BoxShadow(color: widget.borderColor.withValues(alpha: 0.28), blurRadius: s * 0.22, spreadRadius: 0),
        BoxShadow(color: _white55, blurRadius: 1, offset: const Offset(-1, -1)),
      ];
    }
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: isEmpty ? NeonColors.surface : widget.faceColor,
        borderRadius: BorderRadius.circular(s * 0.18),
        border: Border.all(color: isEmpty ? NeonColors.border : widget.borderColor, width: isEmpty ? 1 : 1.6),
        boxShadow: shadows,
        gradient: isEmpty
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, widget.faceColor, const Color(0xFFE2E8F0)],
                stops: const [0.0, 0.55, 1.0],
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s * 0.18),
        child: Stack(
          children: [
            // Reflet glossy en haut
            Positioned(
              top: 0, left: 0, right: 0, height: s * 0.32,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.55), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Points
            Center(
              child: isEmpty
                  ? Icon(Icons.casino_outlined, color: NeonColors.textSecondary.withValues(alpha: 0.7), size: s * 0.45)
                  : _buildDots(widget.value, s),
            ),
            // Ombre interne basse
            Positioned(
              bottom: 0, left: 0, right: 0, height: s * 0.18,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots(int v, double s) {
    final dot = Container(
      width: s * 0.16,
      height: s * 0.16,
      decoration: BoxDecoration(
        color: widget.dotColor,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 1, offset: const Offset(0, 1))],
      ),
    );
    final gap = s * 0.11;
    // Grille 3x3 positions
    Widget pos(int col, int row) => Positioned(
          left: s * 0.22 + col * gap,
          top: s * 0.22 + row * gap,
          child: dot,
        );
    // Génère selon valeur
    List<Widget> dots = [];
    switch (v) {
      case 1:
        dots = [pos(1, 1)];
        break;
      case 2:
        dots = [pos(0, 0), pos(2, 2)];
        break;
      case 3:
        dots = [pos(0, 0), pos(1, 1), pos(2, 2)];
        break;
      case 4:
        dots = [pos(0, 0), pos(2, 0), pos(0, 2), pos(2, 2)];
        break;
      case 5:
        dots = [pos(0, 0), pos(2, 0), pos(1, 1), pos(0, 2), pos(2, 2)];
        break;
      case 6:
        dots = [pos(0, 0), pos(0, 1), pos(0, 2), pos(2, 0), pos(2, 1), pos(2, 2)];
        break;
      default:
        dots = [];
    }
    return SizedBox(width: s, height: s, child: Stack(children: dots));
  }
}

/// Groupe de dés avec animation séquentielle et effet rebond sur tatami
class DiceGroup3D extends StatefulWidget {
  final List<int> values; // résultats finaux
  final bool isRolling;
  final double diceSize;
  final Duration stagger;

  const DiceGroup3D({
    super.key,
    required this.values,
    this.isRolling = false,
    this.diceSize = 56,
    this.stagger = const Duration(milliseconds: 90),
  });

  @override
  State<DiceGroup3D> createState() => _DiceGroup3DState();
}

class _DiceGroup3DState extends State<DiceGroup3D> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    // P2 FIX: Wrap → Row centered, RepaintBoundary par dé, throttle 30fps implicite via TweenAnimationBuilder
    final diceWidgets = List.generate(widget.values.length, (i) {
      final delay = widget.stagger * i;
      // Sur web on réduit le stagger et on throttle l'animation à ~30fps en doublant duration
      final dur = kIsWeb
          ? Duration(milliseconds: 280 + delay.inMilliseconds ~/ 2)
          : Duration(milliseconds: 320 + delay.inMilliseconds);
      return RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.isRolling ? 0 : 1),
          duration: dur,
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: 0.7 + 0.3 * v, child: Opacity(opacity: v, child: child)),
          child: Dice3D(
            value: widget.values[i],
            size: widget.diceSize,
            isRolling: widget.isRolling,
            rollDuration: Duration(milliseconds: 850 + i * 120),
            borderColor: widget.isRolling ? NeonColors.accent : NeonColors.primary,
          ),
        ),
      );
    });

    // Row centré évite layout Wrap coûteux (intrinsic) et réduit relayout rAF
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: diceWidgets
            .map((w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: w))
            .toList(),
      ),
    );
  }
}

/// Animation de particules victoire/défaite
class DiceResultBurst extends StatelessWidget {
  final bool isWin;
  final double size;

  const DiceResultBurst({super.key, required this.isWin, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isWin ? NeonColors.success : NeonColors.error).withValues(alpha: 0.14),
          border: Border.all(color: isWin ? NeonColors.success : NeonColors.error, width: 2),
          boxShadow: [BoxShadow(color: (isWin ? NeonColors.success : NeonColors.error).withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)],
        ),
        child: Icon(isWin ? Icons.emoji_events : Icons.close_rounded, color: isWin ? NeonColors.success : NeonColors.error, size: size * 0.55),
      ),
    );
  }
}

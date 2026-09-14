// ============================================================
// Fichier: dice_scene.dart
// Description: Éléments de scène 3D sans GLSL : ombre portée, plateau,
//              halo de résultat. Lumières simulées par gradients Canvas.
// Auteur: WIWIGA Team
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/neon_theme.dart';

/// Ombre portée sous le dé.
/// Pourquoi 1 Container sans blur animé : `BoxShadow.blurRadius` animé à
/// 60 FPS coûte cher sur mobile ; ici seule la taille/opacité bougent.
class DiceShadow extends StatelessWidget {
  /// Taille du dé associé.
  final double size;

  /// 1.0 = dé posé. > 1 = dé en l'air (ombre plus petite et diffuse).
  final double heightFactor;

  const DiceShadow({
    super.key,
    required this.size,
    this.heightFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final h = heightFactor.clamp(1.0, 3.0);
    return Container(
      width: size * (1.05 / h + 0.2),
      height: size * 0.15,
      decoration: BoxDecoration(
        color: NeonColors.surface.withValues(alpha: (0.85 / h).clamp(0.2, 0.85)),
        borderRadius: BorderRadius.circular(size * 0.075),
      ),
    );
  }
}

/// Plateau tatami : sol + lumière directionnelle simulée (gradient) +
/// bordure néon. À placer sous le [Dice3D].
class DiceTable extends StatelessWidget {
  final Widget child;

  /// Largeur du plateau.
  final double width;

  /// Hauteur du plateau.
  final double height;

  const DiceTable({
    super.key,
    required this.child,
    this.width = 340,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    // P2 perf (déjà appliqué dans dice_3d legacy) : ombre simple sur web.
    final shadows = kIsWeb
        ? [
            BoxShadow(
              color: NeonColors.surface.withValues(alpha: 0.7),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ]
        : [
            BoxShadow(
              color: NeonColors.surface.withValues(alpha: 0.85),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: NeonColors.primary.withValues(alpha: 0.12),
              blurRadius: 32,
            ),
          ];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeonColors.border, // key light haut-gauche
            NeonColors.surface, // fill bas-droit
          ],
        ),
        border: Border.all(
          color: NeonColors.primary.withValues(alpha: 0.4),
        ),
        boxShadow: shadows,
      ),
      child: Center(child: child),
    );
  }
}

/// Halo de résultat (victoire/défaite), affiché après [onRollEnd].
class DiceResultHalo extends StatelessWidget {
  final bool isWin;
  final double size;

  const DiceResultHalo({super.key, required this.isWin, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final color = isWin ? NeonColors.success : NeonColors.error;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(
          isWin ? Icons.emoji_events : Icons.close_rounded,
          color: color,
          size: size * 0.55,
        ),
      ),
    );
  }
}

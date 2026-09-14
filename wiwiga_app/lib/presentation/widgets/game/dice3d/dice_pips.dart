// ============================================================
// Fichier: dice_pips.dart
// Description: Face du dé (fond + points 1..6). Couleurs adossées
//              aux tokens NeonColors (reflet/ombres = lumière physique).
// Auteur: WIWIGA Team
// ============================================================

import 'package:flutter/material.dart';

import '../../../../core/theme/neon_theme.dart';
import 'dice_theme.dart';

/// Dessine une face de dé (valeur 0 = vide, icône casino).
/// Pourquoi un widget pur : testable en widget-test sans moteur 3D.
class DicePips extends StatelessWidget {
  final int value;
  final double size;
  final DiceTheme theme;

  const DicePips({
    super.key,
    required this.value,
    required this.size,
    this.theme = const DiceTheme.ivory(),
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == 0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: isEmpty ? NeonColors.border : theme.edge,
          width: isEmpty ? 1 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.edge.withValues(alpha: theme.glowOpacity),
            blurRadius: size * 0.22,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEmpty
              ? [NeonColors.card, NeonColors.surface]
              : [theme.faceTop, theme.faceBottom],
          stops: const [0.0, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Stack(
          children: [
            _gloss(size),
            Center(
              child: isEmpty
                  ? Icon(
                      Icons.casino_outlined,
                      color: NeonColors.textSecondary.withValues(alpha: 0.7),
                      size: size * 0.45,
                    )
                  : _dots(value, size),
            ),
            _innerShadow(size),
          ],
        ),
      ),
    );
  }

  /// Reflet glossy haut (lumière directionnelle simulée).
  Widget _gloss(double s) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: s * 0.32,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              NeonColors.textPrimary.withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// Ombre interne basse (profondeur matière).
  Widget _innerShadow(double s) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: s * 0.18,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              NeonColors.surface.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// Points selon la valeur (grille 3x3).
  Widget _dots(int v, double s) {
    final dot = Container(
      width: s * 0.16,
      height: s * 0.16,
      decoration: BoxDecoration(
        color: theme.pip,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: NeonColors.surface.withValues(alpha: 0.25),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
    final gap = s * 0.24;
    final c = s / 2 - s * 0.08; // centre compensé taille point
    Widget pos(double dx, double dy) => Positioned(
          left: c + dx * gap,
          top: c + dy * gap,
          child: dot,
        );
    final List<Widget> dots = switch (v) {
      1 => [pos(0, 0)],
      2 => [pos(-1, -1), pos(1, 1)],
      3 => [pos(-1, -1), pos(0, 0), pos(1, 1)],
      4 => [pos(-1, -1), pos(1, -1), pos(-1, 1), pos(1, 1)],
      5 => [pos(-1, -1), pos(1, -1), pos(0, 0), pos(-1, 1), pos(1, 1)],
      6 => [pos(-1, -1), pos(-1, 0), pos(-1, 1), pos(1, -1), pos(1, 0), pos(1, 1)],
      _ => <Widget>[],
    };
    return SizedBox(width: s, height: s, child: Stack(children: dots));
  }
}

// ============================================================
// Fichier: dice_theme.dart
// Description: Thèmes visuels du dé (ivoire / néon / or).
//              Couleurs adossées aux tokens NeonColors (règle design
//              system) : les 3 hex restants sont la matière physique du dé
//              (ivoire plastique, ivoire ombré, brun de contraste), pas des
//              choix de palette UI — documentés comme _kIvory* ci-dessous.
// Auteur: WIWIGA Team
// ============================================================

import 'package:flutter/material.dart';

import '../../../../core/theme/neon_theme.dart';

/// Matière physique du dé (hors palette UI) : plastique ivoire et ombre.
/// Pourquoi des hex ici : aucun token néon ne décrit un plastique blanc ;
/// centralisés et const, usage limité aux faces du dé.
const Color _kIvoryTop = Color(0xFFFFFFFF);
const Color _kIvoryShade = Color(0xFFE2E8F0);
const Color _kGoldLight = Color(0xFFFFF7E0);
const Color _kGoldBrown = Color(0xFF78350F);

/// Thème changeable du dé 3D (couleurs, matière simulée).
/// Pourquoi une classe dédiée : changer de thème ne touche ni au moteur
/// physique ni au widget (ouvert/fermé).
class DiceTheme {
  /// Couleur haute (lumière ambiante + reflet glossy).
  final Color faceTop;

  /// Couleur basse (ombre portée interne).
  final Color faceBottom;

  /// Couleur des points (pips).
  final Color pip;

  /// Couleur de bordure + lueur.
  final Color edge;

  /// Opacité de la lueur de bordure.
  final double glowOpacity;

  const DiceTheme({
    required this.faceTop,
    required this.faceBottom,
    required this.pip,
    required this.edge,
    this.glowOpacity = 0.28,
  });

  /// Plastique ivoire classique (défaut, lisible en plein soleil).
  const DiceTheme.ivory()
      : faceTop = _kIvoryTop,
        faceBottom = _kIvoryShade,
        pip = NeonColors.surface,
        edge = NeonColors.primary,
        glowOpacity = 0.28;

  /// Néon sombre (cohérent avec le design system WIWIGA).
  const DiceTheme.neon()
      : faceTop = NeonColors.card,
        faceBottom = NeonColors.surface,
        pip = NeonColors.primary,
        edge = NeonColors.accent,
        glowOpacity = 0.45;

  /// Or premium (récompenses, victoire).
  const DiceTheme.gold()
      : faceTop = _kGoldLight,
        faceBottom = NeonColors.secondary,
        pip = _kGoldBrown,
        edge = NeonColors.secondary,
        glowOpacity = 0.4;

  /// Presets const pour les affichages statiques (évite une allocation
  /// par build + satisfait prefer_const_constructors aux call sites).
  static const DiceTheme ivoryPlain = DiceTheme(
    faceTop: _kIvoryTop,
    faceBottom: _kIvoryShade,
    pip: NeonColors.surface,
    edge: NeonColors.border,
  );

  /// Variante vainqueur (bordure verte).
  static const DiceTheme ivoryWinner = DiceTheme(
    faceTop: _kIvoryTop,
    faceBottom: _kIvoryShade,
    pip: NeonColors.surface,
    edge: NeonColors.success,
  );

  /// Mini-prévisualisation (bordure néon pleine, const, zéro alloc).
  static const DiceTheme miniPreview = DiceTheme(
    faceTop: _kIvoryTop,
    faceBottom: _kIvoryShade,
    pip: NeonColors.surface,
    edge: NeonColors.primary,
  );

  DiceTheme copyWith({
    Color? faceTop,
    Color? faceBottom,
    Color? pip,
    Color? edge,
    double? glowOpacity,
  }) {
    return DiceTheme(
      faceTop: faceTop ?? this.faceTop,
      faceBottom: faceBottom ?? this.faceBottom,
      pip: pip ?? this.pip,
      edge: edge ?? this.edge,
      glowOpacity: glowOpacity ?? this.glowOpacity,
    );
  }
}

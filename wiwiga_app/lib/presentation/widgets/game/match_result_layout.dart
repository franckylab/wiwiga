// ============================================================
// Fichier: match_result_layout.dart
// Description: Décisions de mise en page (pures, testables) pour la
//              fenêtre de résultat final du match de dés.
//              - Largeur/hauteur déduites de l'espace DISPONIBLE (jamais du
//                plein écran : la barre d'app et l'en-tête réduisent la place
//                réelle, surtout sur desktop aux fenêtres peu hautes).
//              - Barre de défilement visible sur desktop (découvrabilité du
//                contenu : manches, score, gains, revanche).
//              - Tailles réduites sur petits écrans (>300px) et faibles hauteurs.
// Auteur: WIWIGA Team
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mise en page de la fenêtre de résultat final (fonctions pures).
class MatchResultLayout {
  const MatchResultLayout._();

  /// Largeur standard d'un dialogue (règle responsive : max 480px tablette+).
  static const double maxDialogWidth = 480.0;

  /// Marges de sécurité autour de la fenêtre.
  static const double horizontalMargin = 12.0;
  static const double verticalMargin = 8.0;

  /// Seuil "étroit" (mobile compact) et "bas" (fenêtre peu haute).
  static const double narrowBreakpoint = 380.0;
  static const double shortBreakpoint = 560.0;

  /// Breakpoint desktop pour la barre de défilement (cohérent avec l'écran).
  static const double desktopBreakpoint = 620.0;

  /// Largeur max de la fenêtre : espace dispo moins marges, plafonnée.
  /// Garantit >= 280px de contenu utile même à 320px de large.
  static double dialogMaxWidth(double availWidth) {
    return (availWidth - horizontalMargin * 2).clamp(280.0, maxDialogWidth);
  }

  /// Hauteur max de la fenêtre : espace dispo moins marges, plancher 240px
  /// (le contenu défile en dessous, rien n'est coupé sans recours).
  static double dialogMaxHeight(double availHeight) {
    return math.max(availHeight - verticalMargin * 2, 240.0);
  }

  /// Barre de défilement visible en permanence sur desktop uniquement :
  /// c'est là que le défilement molette est indécouvrable sans pouce visible.
  /// Sur mobile, le pouce apparaît pendant le geste (comportement natif).
  static bool showScrollbar({
    required bool isWeb,
    required TargetPlatform platform,
    required double width,
  }) {
    if (isWeb) return width >= desktopBreakpoint;
    return switch (platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia =>
        false,
    };
  }

  /// Écran étroit : typographies et espacements resserrés (>300px inclus).
  static bool isNarrow(double availWidth) => availWidth < narrowBreakpoint;

  /// Fenêtre peu haute : en-tête compact pour laisser la place au contenu.
  static bool isShort(double availHeight) => availHeight < shortBreakpoint;

  /// Diamètre du trophée : 52px par défaut, 44px si étroit ou bas.
  static double trophySize({
    required double availWidth,
    required double availHeight,
  }) {
    if (isNarrow(availWidth) || isShort(availHeight)) return 44.0;
    return 52.0;
  }

  /// Taille du titre VICTOIRE/DÉFAITE.
  static double titleFontSize(double availWidth) {
    return isNarrow(availWidth) ? 18.0 : 20.0;
  }

  /// Padding interne de la zone défilante.
  static EdgeInsets dialogPadding({
    required double availWidth,
    required double availHeight,
  }) {
    final compact = isNarrow(availWidth) || isShort(availHeight);
    final padding = compact ? 12.0 : 16.0;
    return EdgeInsets.all(padding);
  }
}

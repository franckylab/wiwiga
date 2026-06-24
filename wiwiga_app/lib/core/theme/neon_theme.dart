// ============================================================
// Fichier: neon_theme.dart
// Description: Constantes du design system néon gaming WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-24
// ============================================================

import 'package:flutter/material.dart';

/// Palette de couleurs principale Néon Gaming
class NeonColors {
  // Couleurs principales
  static const Color primary = Color(0xFF2DD4BF);      // Vert émeraude
  static const Color secondary = Color(0xFFF59E0B);    // Orange/doré chaud
  static const Color accent = Color(0xFF00D9FF);       // Cyan pour effets
  
  // Couleurs de fond
  static const Color background = Color(0xFF1E293B);   // Gris-bleu profond
  static const Color surface = Color(0xFF0F172A);      // Plus sombre
  static const Color card = Color(0xFF1E293B);         // Cartes
  
  // Couleurs financières
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Couleurs de texte
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  
  // Couleurs des rangs
  static const Color rankBronze = Color(0xFFCD7F32);
  static const Color rankSilver = Color(0xFFC0C0C0);
  static const Color rankGold = Color(0xFFFFD700);
  static const Color rankPlatinum = Color(0xFFE5E4E2);
  static const Color rankDiamond = Color(0xFFB9F2FF);
  
  // Couleurs des méthodes de paiement
  static const Color paymentMTN = Color(0xFFFFCC00);
  static const Color paymentOrange = Color(0xFFFF6600);
  static const Color paymentCampay = Color(0xFF00A650); // À confirmer
  
  // Couleurs des statuts de jeu
  static const Color gameInProgress = Color(0xFF2DD4BF);
  static const Color gameCompleted = Color(0xFF10B981);
  static const Color gameCancelled = Color(0xFFEF4444);
  static const Color gamePending = Color(0xFFF59E0B);
}

/// Paramètres des effets Glow
class NeonGlow {
  // Opacités pour les effets de lueur
  static const double opacityLow = 0.3;
  static const double opacityMedium = 0.5;
  static const double opacityHigh = 0.7;
  
  // Blur radius pour les effets de lueur
  static const double blurSmall = 4.0;
  static const double blurMedium = 8.0;
  static const double blurLarge = 16.0;
  static const double blurExtraLarge = 24.0;
  
  // Épaisseur des bordures lumineuses
  static const double borderWidthThin = 1.0;
  static const double borderWidthMedium = 1.5;
  static const double borderWidthThick = 2.0;
}

/// Paramètres des ombres
class NeonShadows {
  // Opacité maximale des ombres
  static const double maxOpacity = 0.15;
  
  // Ombres prédéfinies
  static List<BoxShadow> small(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> medium(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> large(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> glow(Color color, {double opacity = 0.5}) => [
    BoxShadow(
      color: color.withOpacity(opacity),
      blurRadius: NeonGlow.blurMedium,
      spreadRadius: 2,
    ),
  ];
}

/// Paramètres des gradients (uniquement CTA et balance)
class NeonGradients {
  // Gradient pour boutons primaires
  static const LinearGradient primary = LinearGradient(
    colors: [NeonColors.primary, NeonColors.accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Gradient pour boutons secondaires
  static const LinearGradient secondary = LinearGradient(
    colors: [NeonColors.secondary, Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Gradient pour carte de solde
  static const LinearGradient balance = LinearGradient(
    colors: [NeonColors.primary, NeonColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Gradient pour cartes de jeu (hover)
  static const LinearGradient gameCard = LinearGradient(
    colors: [NeonColors.primary, NeonColors.accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Paramètres des animations
class NeonAnimations {
  // Durées
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration transition = Duration(milliseconds: 300);
  
  // Courbes
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve bounce = Curves.elasticOut;
}

/// Paramètres des coins arrondis
class NeonRadius {
  static const double small = 8.0;   // Boutons, inputs
  static const double medium = 12.0; // Cartes
  static const double large = 16.0;  // Modals
  static const double extraLarge = 24.0; // Éléments spéciaux
}

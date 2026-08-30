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
  
  // Bordures
  static const Color border = Color(0xFF334155);
  
  // Couleurs financières
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color danger = Color(0xFFEF4444); // Alias pour error
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
  static const Color paymentCampay = Color(0xFF00A650);
  
  // Couleurs des statuts de jeu
  static const Color gameInProgress = Color(0xFF2DD4BF);
  static const Color gameCompleted = Color(0xFF10B981);
  static const Color gameCancelled = Color(0xFFEF4444);
  static const Color gamePending = Color(0xFFF59E0B);
  
  // Couleurs wiga WIWIGA — système 3D
  static const Color tokenPrimary = Color(0xFF2DD4BF);    // Emeraude neon
  static const Color tokenGold = Color(0xFFFFD700);       // Or premium
  static const Color tokenSilver = Color(0xFFC0C0C0);     // Argent
  static const Color tokenBronze = Color(0xFFCD7F32);     // Bronze
  static const Color tokenGlow = Color(0xFF00FFD4);       // Lueur wiga
  static const Color tokenDiamond = Color(0xFFB9F2FF);    // Diamant / holographic clair
  static const Color tokenEdgeEmerald = Color(0xFF0B3D36); // Tranche émeraude
  static const Color tokenEdgeGold = Color(0xFF6B5300);   // Tranche or
  static const Color tokenEdgeSilver = Color(0xFF5A6470); // Tranche argent
  static const Color tokenEdgeBronze = Color(0xFF5A2E12); // Tranche bronze
  static const Color tokenHoloMid = Color(0xFF7C3AED);    // Holo mid (violet)
  static const Color tokenHoloEnd = Color(0xFFFF2E93);    // Holo end (rose)

  // Couleurs admin / analytics
  static const Color adminCyan = Color(0xFF00FFFF);       // Cyan données
  static const Color adminMagenta = Color(0xFFFF00FF);    // Magenta analytics
  static const Color adminPurple = Color(0xFFAA00FF);     // Purple metrics
  static const Color adminBlue = Color(0xFF4488FF);       // Blue systèmes
  static const Color adminAmber = Color(0xFFFFAA00);      // Amber warnings
}

/// Paramètres des effets Glow
class NeonGlow {
  // Opacités pour les effets de lueur
  static const double opacityLow = 0.3;
  static const double opacityMedium = 0.5;
  static const double opacityHigh = 0.7;
  
  // Blur radius
  static const double blurSmall = 4.0;
  static const double blurMedium = 8.0;
  static const double blurLarge = 16.0;
  static const double blurExtraLarge = 24.0;
  
  // Épaisseur des bordures
  static const double borderWidth = 1.0;
  static const double borderWidthThick = 2.0;
}

/// Paramètres des ombres
class NeonShadows {
  static const double smallBlur = 4.0;
  static const double mediumBlur = 8.0;
  static const double largeBlur = 16.0;
  static const double offset = 2.0;
}

/// Métaux wiga — gradients & ombres 3D
class TokenMetals {
  static const Color emeraldBase = NeonColors.tokenPrimary;
  static const Color emeraldMid = Color(0xFF00FFD4);
  static const Color emeraldDark = Color(0xFF0A3D36);
  static const Color goldBase = NeonColors.tokenGold;
  static const Color goldMid = Color(0xFFFFF2A8);
  static const Color goldDark = Color(0xFF8A6D00);
  static const Color silverBase = NeonColors.tokenSilver;
  static const Color silverMid = Color(0xFFF1F5F9);
  static const Color silverDark = Color(0xFF6B7280);
  static const Color bronzeBase = NeonColors.tokenBronze;
  static const Color bronzeMid = Color(0xFFF5B07A);
  static const Color bronzeDark = Color(0xFF6B3A16);
  static const Color diamondBase = NeonColors.tokenDiamond;
  static const Color diamondMid = Color(0xFFFFFFFF);
  static const Color diamondDark = Color(0xFF3A6B7A);

  static List<Color> colorsFor(TokenMetal metal) {
    switch (metal) {
      case TokenMetal.emerald: return const [emeraldBase, emeraldMid, emeraldDark];
      case TokenMetal.gold: return const [goldBase, goldMid, goldDark];
      case TokenMetal.silver: return const [silverBase, silverMid, silverDark];
      case TokenMetal.bronze: return const [bronzeBase, bronzeMid, bronzeDark];
      case TokenMetal.diamond: return const [diamondBase, diamondMid, diamondDark];
      case TokenMetal.holographic: return const [NeonColors.accent, NeonColors.tokenHoloMid, NeonColors.tokenHoloEnd, NeonColors.tokenGold];
    }
  }

  static Color edgeFor(TokenMetal metal) {
    switch (metal) {
      case TokenMetal.emerald: return NeonColors.tokenEdgeEmerald;
      case TokenMetal.gold: return NeonColors.tokenEdgeGold;
      case TokenMetal.silver: return NeonColors.tokenEdgeSilver;
      case TokenMetal.bronze: return NeonColors.tokenEdgeBronze;
      case TokenMetal.diamond: return const Color(0xFF2A4E5E);
      case TokenMetal.holographic: return const Color(0xFF1E1A4A);
    }
  }

  static Color glowFor(TokenMetal metal) {
    switch (metal) {
      case TokenMetal.emerald: return const Color(0x6B2DD4BF);
      case TokenMetal.gold: return const Color(0x70FFD700);
      case TokenMetal.silver: return const Color(0x5BC0C0C0);
      case TokenMetal.bronze: return const Color(0x5BCD7F32);
      case TokenMetal.diamond: return const Color(0x6BB9F2FF);
      case TokenMetal.holographic: return const Color(0x6B00D9FF);
    }
  }
}

enum TokenMetal { emerald, gold, silver, bronze, diamond, holographic }

enum TokenLod { flat, bevel, edge, full }

enum TokenEffect { none, pulse, shimmer, spin, float, flip }

/// Gradients prédéfinis
class NeonGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [NeonColors.primary, NeonColors.accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondary = LinearGradient(
    colors: [NeonColors.secondary, Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cta = LinearGradient(
    colors: [NeonColors.primary, NeonColors.success],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient card = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
  );
  
  /// Gradient principal pour les wiga (emeraude -> dore)
  static const LinearGradient token = LinearGradient(
    colors: [NeonColors.tokenPrimary, NeonColors.tokenGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Gradient splash screen
  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
  );
}

/// Constantes d'animation
class NeonAnimations {
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration transition = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
  
  static const Duration glowPulse = Duration(seconds: 2);
  static const Duration shimmer = Duration(seconds: 1);
  
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve bounce = Curves.elasticOut;
}

/// Paramètres des coins arrondis
class NeonRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double extraLarge = 24.0;
  static const double borderRadius = 12.0;
}

/// Thèmes Material Design
class NeonTheme {
  NeonTheme._();
  
  static const double borderRadius = 12.0;
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: NeonColors.primary,
      scaffoldBackgroundColor: NeonColors.background,
      colorScheme: const ColorScheme.dark(
        primary: NeonColors.primary,
        secondary: NeonColors.secondary,
        surface: NeonColors.surface,
        error: NeonColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NeonColors.background,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: NeonColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeonRadius.borderRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeonColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NeonRadius.borderRadius),
          borderSide: const BorderSide(color: NeonColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NeonRadius.borderRadius),
          borderSide: const BorderSide(color: NeonColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NeonRadius.borderRadius),
          borderSide: const BorderSide(color: NeonColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NeonColors.primary,
          foregroundColor: NeonColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeonRadius.borderRadius),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: NeonColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: NeonColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: NeonColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: NeonColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: NeonColors.textSecondary,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return darkTheme;
  }
}

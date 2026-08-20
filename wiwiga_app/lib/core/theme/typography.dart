// ============================================================
// Fichier: typography.dart
// Description: Typographie WIWIGA - Inter + Orbitron
// Auteur: WIWIGA Team
// Date: 2026-06-24
// ============================================================

import 'package:flutter/material.dart';
import 'neon_theme.dart';

/// Thème typographique WIWIGA
class AppTypography {
  // Police principale pour le texte courant
  static const String fontFamilyBody = 'Inter';
  
  // Police pour les titres et montants (gaming)
  static const String fontFamilyDisplay = 'Orbitron';
  
  // Polices de secours pour caractères non couverts (emoji, CJK, arabe, etc.)
  // Noto Sans couvre les ranges Unicode manquants dans Inter/Orbitron.
  // La font est chargée via google_fonts dans main.dart.
  static const List<String> fontFamilyFallback = ['Noto Sans', 'Arial'];
  
  /// TextTheme sombre par défaut
  static const TextTheme darkTheme = TextTheme(
    // Headlines - Orbitron pour effet gaming
    displayLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
      letterSpacing: -0.5,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
    ),
    
    // Titres - Orbitron
    titleLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: NeonColors.textSecondary,
    ),
    
    // Body - Inter pour lisibilité
    bodyLarge: TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: NeonColors.textPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: NeonColors.textSecondary,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: NeonColors.textMuted,
      height: 1.4,
    ),
    
    // Labels
    labelLarge: TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: NeonColors.textSecondary,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: NeonColors.textMuted,
      letterSpacing: 0.5,
    ),
  );
  
  /// Style spécial pour les montants financiers (Orbitron)
  static TextStyle balanceAmount({double fontSize = 36}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: NeonColors.primary,
      letterSpacing: 1,
    );
  }
  
  /// Style pour les montants sur mobile (minimum 20px)
  static TextStyle balanceAmountMobile() {
    return balanceAmount(fontSize: 20);
  }
  
  /// Style pour les labels de jeux
  static TextStyle gameLabel({double fontSize = 14}) {
    return TextStyle(
      fontFamily: fontFamilyBody,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: NeonColors.textSecondary,
    );
  }
  
  // Aliases pour compatibilité
  static TextStyle get heading1 => const TextStyle();
  static TextStyle get heading2 => const TextStyle();
  static TextStyle get heading3 => const TextStyle();
  static TextStyle get heading4 => const TextStyle();
  static TextStyle get heading5 => const TextStyle();
  static TextStyle get heading6 => const TextStyle();
  static TextStyle get subtitle => headlineSmall;
  
  // Ajout des méthodes pour accéder aux styles
  static TextStyle get displayLarge => darkTheme.displayLarge!;
  static TextStyle get displayMedium => darkTheme.displayMedium!;
  static TextStyle get displaySmall => darkTheme.displaySmall!;
  static TextStyle get headlineLarge => darkTheme.headlineLarge!;
  static TextStyle get headlineMedium => darkTheme.headlineMedium!;
  static TextStyle get headlineSmall => darkTheme.headlineSmall!;
  static TextStyle get bodyLarge => darkTheme.bodyLarge!;
  static TextStyle get bodyMedium => darkTheme.bodyMedium!;
  static TextStyle get bodySmall => darkTheme.bodySmall!;
  static TextStyle get labelLarge => darkTheme.labelLarge!;
  static TextStyle get labelMedium => darkTheme.labelMedium!;
  static TextStyle get labelSmall => darkTheme.labelSmall!;
}

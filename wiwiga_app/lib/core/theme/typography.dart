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
  
  /// TextTheme sombre par défaut
  static const TextTheme darkTheme = TextTheme(
    // Headlines - Orbitron pour effet gaming
    displayLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
      letterSpacing: -0.5,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: NeonColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
    ),
    
    // Titres - Orbitron
    titleLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: NeonColors.textSecondary,
    ),
    
    // Body - Inter pour lisibilité
    bodyLarge: TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: NeonColors.textPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: NeonColors.textSecondary,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: NeonColors.textMuted,
      height: 1.4,
    ),
    
    // Labels
    labelLarge: TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: NeonColors.textPrimary,
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: NeonColors.textSecondary,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamilyBody,
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
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: NeonColors.textSecondary,
    );
  }
}

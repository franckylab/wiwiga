// ============================================================
// Fichier: app_theme.dart
// Description: Thème responsive WIWIGA avec couleurs et styles
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'neon_theme.dart';
import 'typography.dart';

/// Thème principal de l'application WIWIGA - Design Néon Gaming
class AppTheme {
  // Utiliser les couleurs du design system néon
  static const Color primaryColor = NeonColors.primary;
  static const Color secondaryColor = NeonColors.secondary;
  static const Color accentColor = NeonColors.accent;
  
  // Couleurs financières (alias vers NeonColors)
  static const Color successColor = NeonColors.success;
  static const Color warningColor = NeonColors.warning;
  static const Color errorColor = NeonColors.error;
  static const Color infoColor = NeonColors.info;
  
  // Couleurs de fond
  static const Color darkBackground = NeonColors.background;
  static const Color darkSurface = NeonColors.surface;
  static const Color darkCard = NeonColors.card;
  
  // Couleurs de texte
  static const Color textLight = NeonColors.textPrimary;
  static const Color textDark = NeonColors.background;
  static const Color textLightSecondary = NeonColors.textSecondary;
  static const Color textDarkSecondary = NeonColors.textMuted;
  
  // Thème sombre (par défaut)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkSurface,
      error: errorColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    textTheme: AppTypography.darkTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
  
  // Thème clair
  static final ThemeData lightTheme = darkTheme.copyWith(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.grey[100],
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Colors.white,
      error: errorColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textDark),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

// ============================================================
// Fichier: neon_theme.dart (suite)
// Description: Thèmes Material Design avec style néon
// ============================================================

/// Thèmes Material Design
class NeonTheme {
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
      cardTheme: CardTheme(
        color: NeonColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeonColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NeonColors.textMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NeonColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NeonColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NeonColors.primary,
          foregroundColor: NeonColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
    return darkTheme; // Pour l'instant, on utilise le thème dark
  }
}

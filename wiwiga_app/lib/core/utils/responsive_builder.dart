// ============================================================
// Fichier: responsive_builder.dart
// Description: Système de responsivité progressive 17 breakpoints (50px-2300px+)
//              Optimisé pour Mobile Android (50px-480px)
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';

/// Catégories d'écran avec 17 breakpoints
enum ScreenCategory {
  ultraSmall,      // 50px - 100px
  extraSmall,      // 100px - 150px
  verySmall,       // 150px - 200px
  smallPhone,      // 200px - 250px
  phone,           // 250px - 300px
  largePhone,      // 300px - 350px
  phablet,         // 350px - 400px
  tablet,          // 400px - 480px
  smallTablet,     // 480px - 600px
  mediumTablet,    // 600px - 768px
  largeTablet,     // 768px - 900px
  laptop,          // 900px - 1024px
  desktop,         // 1024px - 1280px
  largeDesktop,    // 1280px - 1440px
  extraDesktop,    // 1440px - 1680px
  ultraDesktop,    // 1680px - 1920px
  superDesktop,    // 1920px - 2300px
  megaDesktop,     // 2300px+
}

/// Configuration responsive calculée dynamiquement
class ResponsiveConfig {
  final double screenWidth;
  final double screenHeight;
  final ScreenCategory category;
  final double scaleFactor;
  
  // Dimensions adaptées proportionnellement
  final double iconSize;
  final double fontSize;
  final double fontSizeSmall;
  final double fontSizeLarge;
  final double spacing;
  final double spacingSmall;
  final double spacingLarge;
  final double padding;
  final double borderRadius;
  final double buttonHeight;
  final double inputHeight;
  final double cardPadding;
  final double minimumTouchTarget;
  
  // Indicateurs de type d'écran
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final bool isUltraSmall;
  
  const ResponsiveConfig({
    required this.screenWidth,
    required this.screenHeight,
    required this.category,
    required this.scaleFactor,
    required this.iconSize,
    required this.fontSize,
    required this.fontSizeSmall,
    required this.fontSizeLarge,
    required this.spacing,
    required this.spacingSmall,
    required this.spacingLarge,
    required this.padding,
    required this.borderRadius,
    required this.buttonHeight,
    required this.inputHeight,
    required this.cardPadding,
    required this.minimumTouchTarget,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.isUltraSmall,
  });
  
  /// Fabrique principale : calcule la configuration depuis la taille d'écran
  factory ResponsiveConfig.fromSize({
    required double width,
    required double height,
  }) {
    final category = _getScreenCategory(width);
    final baseScale = _getScaleFactor(width);
    
    // Échelle proportionnelle pour tous les éléments UI
    return ResponsiveConfig(
      screenWidth: width,
      screenHeight: height,
      category: category,
      scaleFactor: baseScale,
      
      // Icons : 12px -> 48px+
      iconSize: _scaleValue(baseScale, 24),
      
      // Textes : 10px -> 28px+
      fontSize: _scaleValue(baseScale, 16),
      fontSizeSmall: _scaleValue(baseScale, 12),
      fontSizeLarge: _scaleValue(baseScale, 24),
      
      // Espacements : 4px -> 32px+
      spacing: _scaleValue(baseScale, 16),
      spacingSmall: _scaleValue(baseScale, 8),
      spacingLarge: _scaleValue(baseScale, 24),
      
      // Padding : 8px -> 48px+
      padding: _scaleValue(baseScale, 16),
      
      // Bordures : 4px -> 20px+
      borderRadius: _scaleValue(baseScale, 12),
      
      // Boutons : 32px -> 72px+
      buttonHeight: _scaleValue(baseScale, 48),
      inputHeight: _scaleValue(baseScale, 48),
      cardPadding: _scaleValue(baseScale, 16),
      
      // Touch target minimum (accessibilité)
      minimumTouchTarget: baseScale < 0.5 ? 40.0 : 48.0,
      
      // Indicateurs
      isMobile: width < 480,
      isTablet: width >= 480 && width < 900,
      isDesktop: width >= 900,
      isUltraSmall: width < 200,
    );
  }
  
  /// Détermine la catégorie d'écran (17 breakpoints)
  static ScreenCategory _getScreenCategory(double width) {
    if (width < 100) return ScreenCategory.ultraSmall;
    if (width < 150) return ScreenCategory.extraSmall;
    if (width < 200) return ScreenCategory.verySmall;
    if (width < 250) return ScreenCategory.smallPhone;
    if (width < 300) return ScreenCategory.phone;
    if (width < 350) return ScreenCategory.largePhone;
    if (width < 400) return ScreenCategory.phablet;
    if (width < 480) return ScreenCategory.tablet;
    if (width < 600) return ScreenCategory.smallTablet;
    if (width < 768) return ScreenCategory.mediumTablet;
    if (width < 900) return ScreenCategory.largeTablet;
    if (width < 1024) return ScreenCategory.laptop;
    if (width < 1280) return ScreenCategory.desktop;
    if (width < 1440) return ScreenCategory.largeDesktop;
    if (width < 1680) return ScreenCategory.extraDesktop;
    if (width < 1920) return ScreenCategory.ultraDesktop;
    if (width < 2300) return ScreenCategory.superDesktop;
    return ScreenCategory.megaDesktop;
  }
  
  /// Calcule le facteur d'échelle (0.25x -> 2.2x+)
  static double _getScaleFactor(double width) {
    // Base : 400px = 1.0x
    final baseWidth = 400.0;
    final rawScale = width / baseWidth;
    
    // Limite l'échelle entre 0.25x et 2.2x
    return rawScale.clamp(0.25, 2.2);
  }
  
  /// Applique le facteur d'échelle à une valeur de base
  static double _scaleValue(double scaleFactor, double baseValue) {
    return (baseValue * scaleFactor).roundToDouble();
  }
  
  /// Obtient la configuration depuis un BuildContext
  static ResponsiveConfig of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ResponsiveConfig.fromSize(
      width: size.width,
      height: size.height,
    );
  }
}

/// Widget builder responsive
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveConfig config) builder;
  
  const ResponsiveBuilder({super.key, required this.builder});
  
  @override
  Widget build(BuildContext context) {
    final config = ResponsiveConfig.of(context);
    return builder(context, config);
  }
}

/// Widget utilitaire pour les grilles adaptatives
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
  });
  
  @override
  Widget build(BuildContext context) {
    final config = ResponsiveConfig.of(context);
    
    // Nombre de colonnes selon la largeur
    int crossAxisCount;
    if (config.screenWidth < 300) {
      crossAxisCount = 1;
    } else if (config.screenWidth < 600) {
      crossAxisCount = 2;
    } else if (config.screenWidth < 900) {
      crossAxisCount = 3;
    } else if (config.screenWidth < 1280) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 6;
    }
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: config.spacingSmall,
      mainAxisSpacing: config.spacingSmall,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

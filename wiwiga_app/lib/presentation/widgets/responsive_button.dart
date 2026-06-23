// ============================================================
// Fichier: responsive_button.dart
// Description: Bouton responsive avec adaptation automatique
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/theme/app_theme.dart';

/// Bouton responsive pour WIWIGA
class ResponsiveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? borderRadius;
  final bool isLoading;
  
  const ResponsiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final config = ResponsiveConfig.of(context);
    
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? config.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppTheme.primaryColor,
          foregroundColor: foregroundColor ?? Colors.white,
          disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? config.borderRadius),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? SizedBox(
                width: config.iconSize * 0.8,
                height: config.iconSize * 0.8,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              )
            : child,
      ),
    );
  }
}

/// Bouton secondaire (outline)
class ResponsiveOutlineButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? height;
  final Color? borderColor;
  final Color? foregroundColor;
  
  const ResponsiveOutlineButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height,
    this.borderColor,
    this.foregroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final config = ResponsiveConfig.of(context);
    
    return SizedBox(
      height: height ?? config.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: borderColor ?? AppTheme.primaryColor,
            width: 2,
          ),
          foregroundColor: foregroundColor ?? AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.borderRadius),
          ),
        ),
        child: child,
      ),
    );
  }
}

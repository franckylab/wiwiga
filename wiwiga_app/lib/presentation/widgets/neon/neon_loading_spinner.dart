// ============================================================
// Fichier: neon_loading_spinner.dart
// Description: Widget spinner néon réutilisable
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Spinner de chargement néon, utilisé dans tous les écrans.
/// Remplace les `CircularProgressIndicator(color: NeonColors.primary)` dupliqués.
class NeonLoadingSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const NeonLoadingSpinner({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color,
  });

  /// Spinner centré dans un Center (cas le plus courant)
  const factory NeonLoadingSpinner.center({double size, double strokeWidth, Color? color}) =
      _CenteredNeonSpinner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: color ?? NeonColors.primary,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _CenteredNeonSpinner extends NeonLoadingSpinner {
  const _CenteredNeonSpinner({
    super.size = 24,
    super.strokeWidth = 2.5,
    super.color,
  }) : super();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color ?? NeonColors.primary,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

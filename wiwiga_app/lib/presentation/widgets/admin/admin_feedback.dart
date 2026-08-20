// ============================================================
// Fichier: admin_feedback.dart
// Description: Helpers SnackBar et feedback visuel admin
//              Élimine la duplication des patterns SnackBar
// Auteur: WIWIGA Team
// Date: 2026-08-18
// ============================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/neon_theme.dart';

/// Extension BuildContext pour les SnackBar admin
extension AdminSnackBar on BuildContext {
  /// SnackBar succès (vert)
  void showSuccess(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NeonColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// SnackBar erreur (rouge)
  void showError(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NeonColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// SnackBar info (primary)
  void showInfo(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NeonColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// SnackBar warning (orange)
  void showWarning(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NeonColors.warning,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// SnackBar succès/erreur conditionnel
  void showResult(bool success, {required String successMsg, required String errorMsg}) {
    if (success) {
      showSuccess(successMsg);
    } else {
      showError(errorMsg);
    }
  }
}

/// Dialog de confirmation admin partagé
/// Retourne true si l'utilisateur confirme, false sinon
Future<bool> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  Color confirmColor = NeonColors.primary,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NeonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: confirmColor, size: 20), const SizedBox(width: 8)],
          Text(title, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(message, style: const TextStyle(color: NeonColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: const TextStyle(color: NeonColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: NeonColors.background)),
        ),
      ],
    ),
  );
  return result ?? false;
}

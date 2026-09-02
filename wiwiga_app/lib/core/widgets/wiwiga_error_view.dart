// ============================================================
// WIWIGA - Error Views UX (Best Practices: NN/g, LogRocket, Flutter)
// ============================================================
// Jamais de technique exposée : utilise ErrorHandler.userMessage
// Sévérité-aware: inline / snackbar / fullscreen
// Retry, offline, préservation saisie

import 'package:flutter/material.dart';
import '../errors/error_handler.dart';
import '../theme/neon_theme.dart';
import '../../presentation/widgets/neon/neon_widgets.dart';

/// Vue plein écran pour erreur bloquante (écran qui ne peut pas charger)
class WiwigaErrorView extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? title;
  final bool showDetailsInDebug;

  const WiwigaErrorView({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.title,
    this.showDetailsInDebug = false,
  });

  @override
  Widget build(BuildContext context) {
    final msg = ErrorHandler.userMessage(error);
    final isOffline = ErrorHandler.isOffline(error);
    final icon =
        isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    final color = isOffline ? NeonColors.warning : NeonColors.error;

    // Log technique séparé, jamais affiché
    ErrorHandler.logError(
      error,
      stackTrace,
      context: title ?? 'WiwigaErrorView',
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? (isOffline ? 'Hors ligne' : 'Oups !'),
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (isOffline) ...[
              const SizedBox(height: 8),
              const Text(
                'Vos données sont conservées. Réessayez dès que le réseau revient.',
                style: TextStyle(color: NeonColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            if (onRetry != null)
              NeonButton(
                text: ErrorHandler.retryLabel(error),
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// SnackBar humain, jamais technique, avec action retry si pertinent
class WiwigaSnack {
  static void showError(
    BuildContext context,
    Object error, {
    String? fallback,
    VoidCallback? onRetry,
  }) {
    final msg = ErrorHandler.userMessage(error, fallback: fallback);
    ErrorHandler.logError(error, null, context: 'SnackBar');
    final isRetryable = ErrorHandler.isRetryable(error) && onRetry != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: NeonColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        action: isRetryable
            ? SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: NeonColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: NeonColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Inline error pour champs (validation) — proche de la source, accessible
class WiwigaFieldError extends StatelessWidget {
  final String? message;
  const WiwigaFieldError({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: NeonColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                message!,
                style: const TextStyle(
                  color: NeonColors.error,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

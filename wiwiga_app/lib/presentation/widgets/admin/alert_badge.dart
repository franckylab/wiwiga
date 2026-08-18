// ============================================================
// Fichier: alert_badge.dart
// Description: Widget badge d'alerte admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Badge de compteur de notifications/alertes
class AdminAlertBadge extends StatelessWidget {
  final int count;
  final bool showZero;
  final Widget child;

  const AdminAlertBadge({
    super.key,
    required this.count,
    this.showZero = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0 || showZero)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: count > 0 ? NeonColors.error : NeonColors.textMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NeonColors.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Indicateur de sévérité d'alerte
class SeverityIndicator extends StatelessWidget {
  final String severity;
  final double size;

  const SeverityIndicator({
    super.key,
    required this.severity,
    this.size = 10,
  });

  Color get _color {
    switch (severity) {
      case 'critical':
        return NeonColors.error;
      case 'warning':
        return NeonColors.warning;
      case 'info':
        return NeonColors.info;
      default:
        return NeonColors.textMuted;
    }
  }

  String get _label {
    switch (severity) {
      case 'critical':
        return 'Critique';
      case 'warning':
        return 'Attention';
      case 'info':
        return 'Info';
      default:
        return severity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Tuile d'alerte avec action
class AdminAlertTile extends StatelessWidget {
  final String title;
  final String message;
  final String severity;
  final DateTime timestamp;
  final bool isResolved;
  final VoidCallback? onResolve;
  final VoidCallback? onDismiss;

  const AdminAlertTile({
    super.key,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isResolved = false,
    this.onResolve,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isResolved
              ? NeonColors.border
              : _severityColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SeverityIndicator(severity: severity),
              Text(
                _formatTime(timestamp),
                style: const TextStyle(
                  color: NeonColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isResolved ? NeonColors.textMuted : NeonColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: isResolved ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isResolved && (onResolve != null || onDismiss != null)) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onDismiss != null)
                  TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Ignorer', style: TextStyle(fontSize: 11)),
                  ),
                if (onResolve != null)
                  ElevatedButton(
                    onPressed: onResolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NeonColors.success.withValues(alpha: 0.2),
                      foregroundColor: NeonColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Résoudre'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color get _severityColor {
    switch (severity) {
      case 'critical':
        return NeonColors.error;
      case 'warning':
        return NeonColors.warning;
      default:
        return NeonColors.info;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }
}

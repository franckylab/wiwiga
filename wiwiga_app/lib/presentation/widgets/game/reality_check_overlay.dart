// ============================================================
// Fichier: reality_check_overlay.dart
// Description: Overlay de rappel "Jeu responsable" - Vérifie
//              périodiquement la durée de session et affiche
//              un rappel configurable par l'admin.
// Auteur: WIWIGA Team
// Date: 2026-08-17
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/responsible_gaming_provider.dart';
import '../../providers/config_provider.dart';

/// Overlay de contrôle de réalité (jeu responsable).
/// À placer dans le widget tree des écrans de jeu.
/// Intervalle = préférence personnelle (`reality_check_interval_minutes`),
/// repli config globale admin (30 min par défaut). Affiche le temps écoulé
/// et le prochain rappel ; "Faire une pause" quitte vers l'accueil.
class RealityCheckOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const RealityCheckOverlay({super.key, required this.child});

  @override
  ConsumerState<RealityCheckOverlay> createState() => _RealityCheckOverlayState();
}

class _RealityCheckOverlayState extends ConsumerState<RealityCheckOverlay> {
  Timer? _checkTimer;
  DateTime? _sessionStart;
  int _lastCheckMinutes = 0;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    // Charger la préférence personnelle (repli silencieux si indisponible).
    Future.microtask(() {
      try {
        ref.read(responsibleGamingProvider.notifier).loadLimits();
      } catch (_) {}
    });
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  /// Intervalle effectif en minutes : préférence perso, sinon globale admin.
  /// Borné à >= 1 minute (évite le dialogue en boucle).
  int _effectiveIntervalMinutes() {
    final personal =
        ref.read(responsibleGamingProvider).realityCheckIntervalMinutes;
    if (personal != null && personal > 0) return personal;

    final globalMs = ref.read(featureConfigProvider).when(
          data: (c) => c.realityCheckIntervalMs,
          loading: () => 1800000, // 30 min par défaut
          error: (_, __) => 1800000,
        );
    final fromGlobal = (globalMs / 60000).round();
    return fromGlobal >= 1 ? fromGlobal : 30;
  }

  void _startPeriodicCheck() {
    // Vérifier toutes les 60s si un rappel est nécessaire
    _checkTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || _sessionStart == null) return;

      final intervalMinutes = _effectiveIntervalMinutes();
      final elapsedMinutes = DateTime.now().difference(_sessionStart!).inMinutes;

      // Afficher le rappel si l'intervalle est atteint
      if (elapsedMinutes >= _lastCheckMinutes + intervalMinutes && elapsedMinutes > 0) {
        _lastCheckMinutes = elapsedMinutes;
        _showRealityCheckDialog(elapsedMinutes, intervalMinutes);
      }
    });
  }

  void _showRealityCheckDialog(int elapsedMinutes, int intervalMinutes) {
    final hours = elapsedMinutes ~/ 60;
    final minutes = elapsedMinutes % 60;
    final durationStr = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}min'
        : '${minutes}min';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: NeonColors.warning, size: 24),
            SizedBox(width: 8),
            Text(
              'Jeu Responsable',
              style: TextStyle(
                color: NeonColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous jouez depuis $durationStr.',
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prochain rappel dans $intervalMinutes min.',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pensez à faire des pauses régulières. Le jeu doit rester un plaisir.',
              style: TextStyle(color: NeonColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // L'utilisateur choisit de continuer
            },
            child: const Text(
              'Continuer',
              style: TextStyle(color: NeonColors.primary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Quitter vers l'accueil (la partie continue côté serveur
              // selon ses règles de forfait — le joueur est informé).
              if (mounted) context.go('/home');
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Faire une pause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonColors.warning,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

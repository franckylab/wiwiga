// ============================================================
// Fichier: admin_games_live_screen.dart
// Description: Supervision des parties en temps réel
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/admin/analytics_helpers.dart';
import '../../widgets/admin/admin_feedback.dart';

/// Écran de supervision des parties en direct
class AdminGamesLiveScreen extends ConsumerStatefulWidget {
  const AdminGamesLiveScreen({super.key});

  @override
  ConsumerState<AdminGamesLiveScreen> createState() => _AdminGamesLiveScreenState();
}

class _AdminGamesLiveScreenState extends ConsumerState<AdminGamesLiveScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminGamesLiveProvider.notifier).loadActiveGames();
      ref.read(adminGamesLiveProvider.notifier).loadStatsSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminGamesLiveProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Parties en direct', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminGamesLiveProvider.notifier).loadActiveGames(),
          ),
        ],
      ),
      body: state.isLoading
          ? const NeonLoadingSpinner.center()
          : RefreshIndicator(
              color: NeonColors.primary,
              onRefresh: () => ref.read(adminGamesLiveProvider.notifier).loadActiveGames(),
              child: _buildContent(state),
            ),
    );
  }

  Widget _buildContent(AdminGamesLiveState state) {
    final games = state.activeGames;
    final stats = state.statsSummary;

    if (games.isEmpty && stats == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videogame_asset_off, color: NeonColors.textMuted, size: 48),
                SizedBox(height: 12),
                Text('Aucune partie en cours', style: TextStyle(color: NeonColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé stats
        if (stats != null) _buildStatsSummary(stats),
        const SizedBox(height: 16),
        // Liste des parties actives
        const Text(
          'Parties actives',
          style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: games.length,
              itemBuilder: (context, index) => _buildGameTile(games[index] as Map<String, dynamic>),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsSummary(Map<String, dynamic> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final children = [
          _statItem('Actives', '${stats['active_games'] ?? 0}', NeonColors.accent),
          _statItem('Total aujourd\'hui', '${stats['total_games_today'] ?? 0}', NeonColors.primary),
          _statItem('Mise moy.', AnalyticsFormat.amount(stats['average_bet'] ?? 0), NeonColors.secondary),
        ];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NeonColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NeonColors.border),
          ),
          child: isWide
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children)
              : Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.spaceAround, children: children),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildGameTile(Map<String, dynamic> game) {
    final gameType = game['game_type'] ?? 'dice';
    final players = game['players'] ?? [];
    final totalBet = game['total_bet'] ?? game['pot'] ?? 0;
    final status = game['status'] ?? 'active';
    final gameId = game['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: NeonColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      gameType.toUpperCase(),
                      style: const TextStyle(color: NeonColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: NeonColors.gameInProgress.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: NeonColors.gameInProgress, fontSize: 10),
                    ),
                  ),
                ],
              ),
              Text(
                'Pot: ${AnalyticsFormat.amount(totalBet)}',
                style: const TextStyle(color: NeonColors.secondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${players is List ? players.length : 0} joueurs',
                style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
              ),
              if (gameId.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmForceClose(gameId),
                  icon: const Icon(Icons.close, size: 14, color: NeonColors.error),
                  label: const Text('Forcer clôture', style: TextStyle(fontSize: 11, color: NeonColors.error)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmForceClose(String gameId) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Forcer la clôture',
      message: 'Êtes-vous sûr de vouloir forcer la clôture de cette partie ?',
      confirmColor: NeonColors.error,
    );
    if (confirmed) {
      ref.read(adminGamesLiveProvider.notifier).forceCloseGame(gameId);
    }
  }
}

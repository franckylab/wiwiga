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
          ? const Center(child: CircularProgressIndicator(color: NeonColors.primary))
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
        ...games.map((game) => _buildGameTile(game as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildStatsSummary(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Actives', '${stats['active_games'] ?? 0}', NeonColors.accent),
          _statItem('Total aujourd\'hui', '${stats['total_games_today'] ?? 0}', NeonColors.primary),
          _statItem('Mise moy.', _formatCurrency(stats['average_bet'] ?? 0), NeonColors.secondary),
        ],
      ),
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
                'Pot: ${_formatCurrency(totalBet)}',
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

  void _confirmForceClose(String gameId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Forcer la clôture', style: TextStyle(color: NeonColors.textPrimary)),
        content: const Text(
          'Êtes-vous sûr de vouloir forcer la clôture de cette partie ?',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminGamesLiveProvider.notifier).forceCloseGame(gameId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.error),
            child: const Text('Forcer'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final num amount = (value is num) ? value : double.tryParse(value.toString()) ?? 0;
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}

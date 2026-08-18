// ============================================================
// Fichier: admin_game_analytics_screen.dart
// Description: Écran analytics jeux - Performance par type de jeu
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../../providers/admin_analytics_provider.dart';
import '../../../widgets/admin/metric_card.dart';
import '../../../widgets/admin/chart_widget.dart';

/// Écran Game Analytics (performance par type de jeu)
class AdminGameAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminGameAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminGameAnalyticsScreen> createState() => _AdminGameAnalyticsScreenState();
}

class _AdminGameAnalyticsScreenState extends ConsumerState<AdminGameAnalyticsScreen> {
  static const _periods = ['24h', '7d', '30d', '90d'];
  static const _periodLabels = ['24h', '7j', '30j', '90j'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminGameAnalyticsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminGameAnalyticsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Game Analytics'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: state.selectedPeriod,
              dropdownColor: NeonColors.surface,
              style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13),
              underline: const SizedBox(),
              items: List.generate(_periods.length, (i) {
                return DropdownMenuItem(value: _periods[i], child: Text(_periodLabels[i]));
              }),
              onChanged: (value) {
                if (value != null) {
                  final notifier = ref.read(adminGameAnalyticsProvider.notifier);
                  notifier.setPeriod(value);
                  notifier.load(period: value);
                }
              },
            ),
          ),
        ],
      ),
      body: state.isLoading && state.data == null
          ? const Center(child: CircularProgressIndicator(color: NeonColors.primary))
          : state.error != null && state.data == null
              ? _buildError(state.error!)
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminGameAnalyticsState state) {
    final data = state.data ?? {};
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final games = data['games'] as List<dynamic>? ?? [];
    final timeseries = data['timeseries'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: () => ref.read(adminGameAnalyticsProvider.notifier).load(),
      color: NeonColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé global
            _buildSummaryCards(summary),
            const SizedBox(height: 20),

            // Performance par jeu (cartes)
            _buildSectionTitle('Performance par Type de Jeu'),
            const SizedBox(height: 8),
            _buildGameCards(games),
            const SizedBox(height: 20),

            // Graphique mises vs gains
            if (games.isNotEmpty) ...[
              _buildSectionTitle('Mises vs Gains par Jeu'),
              const SizedBox(height: 8),
              _buildMisesVsGainsChart(games),
              const SizedBox(height: 20),
            ],

            // Évolution parties/jour
            if (timeseries.isNotEmpty) ...[
              _buildSectionTitle('Évolution Parties/Jour'),
              const SizedBox(height: 8),
              AdminLineChart(
                data: timeseries.map((t) => (t['matches'] as num?)?.toDouble() ?? 0.0).toList(),
                lineColor: NeonColors.primary,
                height: 180,
              ),
              const SizedBox(height: 20),
            ],

            // Tableau indicateurs équilibre
            _buildBalanceTable(games),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossCount = isWide ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.4 : 1.2,
          children: [
            AdminMetricCard(
              title: 'Total Parties',
              value: _formatNumber(summary['total_matches']),
              icon: Icons.sports_esports,
              color: NeonColors.primary,
            ),
            AdminMetricCard(
              title: 'Total Mises',
              value: _formatAmount(summary['total_wagered']),
              icon: Icons.casino,
              color: NeonColors.secondary,
            ),
            AdminMetricCard(
              title: 'Total Gains',
              value: _formatAmount(summary['total_won']),
              icon: Icons.emoji_events,
              color: NeonColors.success,
            ),
            AdminMetricCard(
              title: 'GGR Global',
              value: _formatAmount(summary['total_ggr']),
              icon: Icons.trending_up,
              color: NeonColors.accent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameCards(List<dynamic> games) {
    return Column(
      children: games.map((game) {
        final gameType = game['game_type'] as String? ?? '';
        final ggr = (game['ggr'] as num?)?.toDouble() ?? 0;
        final matches = game['matches'] as int? ?? 0;
        final players = game['unique_players'] as int? ?? 0;
        final houseEdge = (game['house_edge'] as num?)?.toDouble() ?? 0;
        final colors = [NeonColors.primary, NeonColors.secondary, NeonColors.accent, NeonColors.success, NeonColors.info];
        final color = colors[gameType.hashCode.abs() % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NeonColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.sports_esports, color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(gameType.toUpperCase(), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (houseEdge >= 0 ? NeonColors.success : NeonColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Edge: ${houseEdge.toStringAsFixed(1)}%',
                      style: TextStyle(color: houseEdge >= 0 ? NeonColors.success : NeonColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('GGR', _formatAmount(ggr)),
                  _buildStatColumn('Parties', '$matches'),
                  _buildStatColumn('Joueurs', '$players'),
                  _buildStatColumn('Mise moy.', _formatAmount(game['avg_bet'])),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMisesVsGainsChart(List<dynamic> games) {
    final misesData = games.map((g) => (g['total_wagered'] as num?)?.toDouble() ?? 0.0).toList();
    final gainsData = games.map((g) => (g['total_won'] as num?)?.toDouble() ?? 0.0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLegendDot(NeonColors.secondary, 'Mises'),
              const SizedBox(width: 16),
              _buildLegendDot(NeonColors.success, 'Gains'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AdminBarChart(data: misesData.isEmpty ? [0] : misesData, barColor: NeonColors.secondary, height: 160)),
              const SizedBox(width: 8),
              Expanded(child: AdminBarChart(data: gainsData.isEmpty ? [0] : gainsData, barColor: NeonColors.success, height: 160)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTable(List<dynamic> games) {
    if (games.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Indicateurs Équilibre', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Table(
            border: TableBorder.all(color: NeonColors.border.withValues(alpha: 0.5)),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFF1E293B)),
                children: [
                  Padding(padding: EdgeInsets.all(8), child: Text('Jeu', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('House Edge', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Plus gros gain', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Ratio M/J', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
              ),
              ...games.map((g) {
                final houseEdge = (g['house_edge'] as num?)?.toDouble() ?? 0;
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text((g['game_type'] as String? ?? '').toUpperCase(), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('${houseEdge.toStringAsFixed(1)}%', style: TextStyle(color: houseEdge >= 0 ? NeonColors.success : NeonColors.error, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(_formatAmount(g['biggest_win']), style: const TextStyle(color: NeonColors.secondary, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(8), child: Text((g['house_player_ratio'] as num?)?.toDouble().toStringAsFixed(2) ?? '-', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11))),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: NeonColors.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: NeonColors.error, size: 48),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: NeonColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(adminGameAnalyticsProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600));
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '0 FCFA';
    final amount = (value as num).toDouble();
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K FCFA';
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final n = (value as num).toDouble();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

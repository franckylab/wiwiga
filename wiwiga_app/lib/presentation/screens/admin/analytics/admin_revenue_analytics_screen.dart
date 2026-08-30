// ============================================================
// Fichier: admin_revenue_analytics_screen.dart
// Description: Écran analytics revenue - GGR, NGR, ARPU, ARPPU
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../../providers/admin_analytics_provider.dart';
import '../../../widgets/admin/metric_card.dart';
import '../../../widgets/admin/chart_widget.dart';
import '../../../widgets/admin/empty_state.dart';
import '../../../widgets/admin/analytics_helpers.dart';
import '../../../widgets/neon/neon_widgets.dart';

/// Écran Revenue Analytics (GGR, NGR, Commissions, ARPU, ARPPU)
class AdminRevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminRevenueAnalyticsScreen> createState() => _AdminRevenueAnalyticsScreenState();
}

class _AdminRevenueAnalyticsScreenState extends ConsumerState<AdminRevenueAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminRevenueAnalyticsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminRevenueAnalyticsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Analytique Revenus'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          AnalyticsPeriodSelector(
            value: state.selectedPeriod,
            onChanged: (value) {
              if (value != null) {
                final notifier = ref.read(adminRevenueAnalyticsProvider.notifier);
                notifier.setPeriod(value);
                notifier.load(period: value);
              }
            },
          ),
        ],
      ),
      body: state.isLoading && state.data == null
          ? const NeonLoadingSpinner.center()
          : state.error != null && state.data == null
              ? AdminErrorState(error: state.error!, onRetry: () => ref.read(adminRevenueAnalyticsProvider.notifier).load())
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminRevenueAnalyticsState state) {
    final data = state.data ?? {};
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final deltas = data['deltas'] as Map<String, dynamic>? ?? {};
    final timeseries = data['timeseries'] as List<dynamic>? ?? [];
    final commissionsByGame = data['commissions_by_game'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: () => ref.read(adminRevenueAnalyticsProvider.notifier).load(),
      color: NeonColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            _buildKpiCards(summary, deltas),
            const SizedBox(height: 20),

            // Graphique GGR/NGR timeseries
            if (timeseries.isNotEmpty) ...[
              const AnalyticsSectionTitle('Évolution Revenu'),
              const SizedBox(height: 8),
              _buildRevenueChart(timeseries),
              const SizedBox(height: 20),
            ],

            // Commissions par jeu
            if (commissionsByGame.isNotEmpty) ...[
              const AnalyticsSectionTitle('Commissions par Jeu'),
              const SizedBox(height: 8),
              _buildCommissionChart(commissionsByGame),
              const SizedBox(height: 20),
            ],

            // Tableau top joueurs
            _buildTopPlayersTable(data['top_players'] as List<dynamic>? ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(Map<String, dynamic> summary, Map<String, dynamic> deltas) {
    return AnalyticsKpiGrid(
      children: [
        AdminMetricCard(
          title: 'GGR',
          value: AnalyticsFormat.amount(summary['ggr']),
          icon: Icons.account_balance_wallet,
          color: NeonColors.primary,
          deltaPercent: AnalyticsFormat.toDouble(deltas['ggr_delta']),
          subtitle: 'Revenu brut des jeux',
        ),
        AdminMetricCard(
          title: 'NGR',
          value: AnalyticsFormat.amount(summary['ngr']),
          icon: Icons.savings,
          color: NeonColors.success,
          deltaPercent: AnalyticsFormat.toDouble(deltas['ngr_delta']),
          subtitle: 'Revenu net des jeux',
        ),
        AdminMetricCard(
          title: 'Commissions',
          value: AnalyticsFormat.amount(summary['total_commissions']),
          icon: Icons.percent,
          color: NeonColors.secondary,
          deltaPercent: AnalyticsFormat.toDouble(deltas['commissions_delta']),
        ),
        AdminMetricCard(
          title: 'ARPU',
          value: AnalyticsFormat.amount(summary['arpu']),
          icon: Icons.people_alt,
          color: NeonColors.accent,
          deltaPercent: AnalyticsFormat.toDouble(deltas['arpu_delta']),
          subtitle: 'Revenu / utilisateur',
        ),
        AdminMetricCard(
          title: 'ARPPU',
          value: AnalyticsFormat.amount(summary['arppu']),
          icon: Icons.workspace_premium,
          color: NeonColors.info,
          deltaPercent: AnalyticsFormat.toDouble(deltas['arppu_delta']),
          subtitle: 'Revenu / payant',
        ),
      ],
    );
  }

  Widget _buildRevenueChart(List<dynamic> timeseries) {
    final ggrData = timeseries.map((t) => (t['ggr'] as num?)?.toDouble() ?? 0.0).toList();
    final ngrData = timeseries.map((t) => (t['ngr'] as num?)?.toDouble() ?? 0.0).toList();

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
          const Row(
            children: [
              AnalyticsLegendDot(NeonColors.primary, 'GGR'),
              SizedBox(width: 16),
              AnalyticsLegendDot(NeonColors.success, 'NGR'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(child: AdminLineChart(data: ggrData, lineColor: NeonColors.primary, height: 180)),
                const SizedBox(width: 8),
                Expanded(child: AdminLineChart(data: ngrData, lineColor: NeonColors.success, height: 180)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionChart(List<dynamic> commissionsByGame) {
    final labels = commissionsByGame.map((g) => g['game_type'] as String? ?? '').toList();
    final values = commissionsByGame.map((g) => (g['commission_amount'] as num?)?.toDouble() ?? 0.0).toList();

    return AdminBarChart(
      data: values.isEmpty ? [0] : values,
      barColor: NeonColors.secondary,
      label: 'Commissions wiga',
      height: 180,
      labels: labels,
    );
  }

  Widget _buildTopPlayersTable(List<dynamic> players) {
    if (players.isEmpty) return const SizedBox.shrink();

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
            child: Text('Top Joueurs par Revenu', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Table(
            border: TableBorder.all(color: NeonColors.border.withValues(alpha: 0.5)),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(1)},
            children: [
              const TableRow(
                decoration: BoxDecoration(color: NeonColors.background),
                children: [
                  Padding(padding: EdgeInsets.all(8), child: Text('Joueur', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Mises', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('GGR', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Parties', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
              ),
              ...players.take(10).map((p) => TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(p['username'] as String? ?? '#${p['user_id']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(AnalyticsFormat.amount(p['total_wagered']), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(AnalyticsFormat.amount(p['ggr']), style: const TextStyle(color: NeonColors.success, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text('${p['matches'] ?? 0}', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11))),
                ],
              ),),
            ],
          ),
        ],
      ),
    );
  }

}

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

/// Écran Revenue Analytics (GGR, NGR, Commissions, ARPU, ARPPU)
class AdminRevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminRevenueAnalyticsScreen> createState() => _AdminRevenueAnalyticsScreenState();
}

class _AdminRevenueAnalyticsScreenState extends ConsumerState<AdminRevenueAnalyticsScreen> {
  static const _periods = ['24h', '7d', '30d', '90d'];
  static const _periodLabels = ['24h', '7j', '30j', '90j'];

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
        title: const Text('Revenue Analytics'),
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
                return DropdownMenuItem(
                  value: _periods[i],
                  child: Text(_periodLabels[i]),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  final notifier = ref.read(adminRevenueAnalyticsProvider.notifier);
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
              _buildSectionTitle('Évolution Revenue'),
              const SizedBox(height: 8),
              _buildRevenueChart(timeseries),
              const SizedBox(height: 20),
            ],

            // Commissions par jeu
            if (commissionsByGame.isNotEmpty) ...[
              _buildSectionTitle('Commissions par Jeu'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossCount = isWide ? 5 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.4 : 1.2,
          children: [
            AdminMetricCard(
              title: 'GGR',
              value: _formatAmount(summary['ggr']),
              icon: Icons.account_balance_wallet,
              color: NeonColors.primary,
              deltaPercent: _toDouble(deltas['ggr_delta']),
              subtitle: 'Gross Gaming Revenue',
            ),
            AdminMetricCard(
              title: 'NGR',
              value: _formatAmount(summary['ngr']),
              icon: Icons.savings,
              color: NeonColors.success,
              deltaPercent: _toDouble(deltas['ngr_delta']),
              subtitle: 'Net Gaming Revenue',
            ),
            AdminMetricCard(
              title: 'Commissions',
              value: _formatAmount(summary['total_commissions']),
              icon: Icons.percent,
              color: NeonColors.secondary,
              deltaPercent: _toDouble(deltas['commissions_delta']),
            ),
            AdminMetricCard(
              title: 'ARPU',
              value: _formatAmount(summary['arpu']),
              icon: Icons.people_alt,
              color: NeonColors.accent,
              deltaPercent: _toDouble(deltas['arpu_delta']),
              subtitle: 'Rev / utilisateur',
            ),
            AdminMetricCard(
              title: 'ARPPU',
              value: _formatAmount(summary['arppu']),
              icon: Icons.workspace_premium,
              color: NeonColors.info,
              deltaPercent: _toDouble(deltas['arppu_delta']),
              subtitle: 'Rev / payant',
            ),
          ],
        );
      },
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
          Row(
            children: [
              _buildLegendDot(NeonColors.primary, 'GGR'),
              const SizedBox(width: 16),
              _buildLegendDot(NeonColors.success, 'NGR'),
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
      label: 'Commissions FCFA',
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
            child: Text('Top Joueurs par Revenue', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Table(
            border: TableBorder.all(color: NeonColors.border.withValues(alpha: 0.5)),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(1)},
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFF1E293B)),
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
                  Padding(padding: const EdgeInsets.all(8), child: Text(_formatAmount(p['total_wagered']), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(_formatAmount(p['ggr']), style: const TextStyle(color: NeonColors.success, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text('${p['matches'] ?? 0}', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11))),
                ],
              ),),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: NeonColors.error, size: 48),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: NeonColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(adminRevenueAnalyticsProvider.notifier).load(),
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

  String _formatAmount(dynamic value) {
    if (value == null) return '0 FCFA';
    final amount = (value as num).toDouble();
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K FCFA';
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    return (value as num).toDouble();
  }
}

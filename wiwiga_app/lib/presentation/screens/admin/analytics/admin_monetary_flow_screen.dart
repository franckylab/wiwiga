// ============================================================
// Fichier: admin_monetary_flow_screen.dart
// Description: Écran flux monétaire - KPI gaming, graphiques,
//              timeseries, Sankey, tooltips explicatifs
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

/// Écran Flux Monétaire (depos -> wallet -> mises -> gains -> retraits + commission)
///
/// Affiche les KPI gaming standards iGaming :
/// - GGR (Gross Gaming Revenue) = Mises - Gains
/// - NGR (Net Gaming Revenue) = GGR - Commissions
/// - Taux de redistribution = Gains / Mises
/// - Vélocité = Volume total / Solde moyen
class AdminMonetaryFlowScreen extends ConsumerStatefulWidget {
  const AdminMonetaryFlowScreen({super.key});

  @override
  ConsumerState<AdminMonetaryFlowScreen> createState() => _AdminMonetaryFlowScreenState();
}

class _AdminMonetaryFlowScreenState extends ConsumerState<AdminMonetaryFlowScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminMonetaryFlowProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminMonetaryFlowProvider);
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Flux Monétaire'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          AnalyticsPeriodSelector(
            value: state.selectedPeriod,
            onChanged: (value) {
              if (value != null) {
                final notifier = ref.read(adminMonetaryFlowProvider.notifier);
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
              ? AdminErrorState(error: state.error!, onRetry: () => ref.read(adminMonetaryFlowProvider.notifier).load())
              : _buildContent(state),
    );
  }

  // ========================================
  // CONTENU PRINCIPAL
  // ========================================

  Widget _buildContent(AdminMonetaryFlowState state) {
    final data = state.data ?? {};
    final deposits = data['deposits'] as Map<String, dynamic>? ?? {};
    final withdrawals = data['withdrawals'] as Map<String, dynamic>? ?? {};
    final bets = data['bets'] as Map<String, dynamic>? ?? {};
    final winnings = data['winnings'] as Map<String, dynamic>? ?? {};
    final commissions = data['commissions'] as Map<String, dynamic>? ?? {};
    final topMovements = data['top_movements'] as List<dynamic>? ?? [];
    final velocityValue = (data['velocity'] as num?)?.toDouble() ?? 0.0;
    final totalPlayerBalance = (data['total_player_balance'] as num?)?.toDouble() ?? 0.0;
    final totalTokenBalance = (data['total_token_balance'] as num?)?.toDouble() ?? 0.0;
    final netFlow = (data['net_flow'] as num?)?.toDouble() ?? 0.0;

    // KPI gaming dérivés (standards iGaming)
    final betsTotal = (bets['total'] as num?)?.toDouble() ?? 0;
    final winningsTotal = (winnings['total'] as num?)?.toDouble() ?? 0;
    final commissionsTotal = (commissions['total'] as num?)?.toDouble() ?? 0;
    final depositsTotal = (deposits['total'] as num?)?.toDouble() ?? 0;
    final withdrawalsTotal = (withdrawals['total'] as num?)?.toDouble() ?? 0;
    final ggr = betsTotal - winningsTotal; // Gross Gaming Revenue
    final ngr = ggr - commissionsTotal; // Net Gaming Revenue
    final payoutRatio = betsTotal > 0 ? (winningsTotal / betsTotal * 100) : 0.0;
    final houseEdge = betsTotal > 0 ? (ggr / betsTotal * 100) : 0.0;

    // Timeseries inflow/outflow
    final flowTimeseries = data['flow_timeseries'] as List<dynamic>? ?? [];
    final inflowData = <double>[];
    final outflowData = <double>[];
    final timeLabels = <String>[];
    for (final entry in flowTimeseries) {
      if (entry is Map<String, dynamic>) {
        inflowData.add((entry['inflow'] as num?)?.toDouble() ?? 0);
        outflowData.add((entry['outflow'] as num?)?.toDouble() ?? 0);
        timeLabels.add(AnalyticsFormat.shortDate(entry['timestamp']?.toString() ?? ''));
      }
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminMonetaryFlowProvider.notifier).load(),
      color: NeonColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KPI Flux principaux
            _tip(
              'Total des dépôts, retraits, mises, gains et commissions sur la période sélectionnée.',
              AnalyticsSectionTitle('Volume de Flux', icon: Icons.account_balance_wallet)
            ),
            const SizedBox(height: 8),
            _buildFlowKpiCards(deposits, withdrawals, bets, winnings, commissions),
            const SizedBox(height: 16),

            // 2. KPI Gaming dérivés (GGR, NGR, House Edge, Payout)
            _tip(
              'GGR = Mises − Gains (revenu brut). NGR = GGR − Commissions (revenu net). '
              'Marge = GGR/Mises. Redistribution = Gains/Mises.',
              AnalyticsSectionTitle('Indicateurs de Rentabilité', icon: Icons.analytics)
            ),
            const SizedBox(height: 8),
            _buildDerivedKpiCards(ggr, ngr, houseEdge, payoutRatio, netFlow),
            const SizedBox(height: 20),

            // 3. Graphique timeseries inflow/outflow
            if (inflowData.length >= 2) ...[
              _tip(
                'Courbes d\'évolution des entrées (dépôts + gains + remboursements) '
                'et sorties (retraits + mises + commissions) dans le temps.',
                AnalyticsSectionTitle('Évolution Flux', icon: Icons.trending_up)
              ),
              const SizedBox(height: 8),
              _buildTimeseriesChart(inflowData, outflowData, timeLabels),
              const SizedBox(height: 20),
            ],

            // 4. Graphique comparaison par type
            _tip(
              'Comparaison visuelle des volumes par type de transaction.',
              AnalyticsSectionTitle('Comparaison par Type', icon: Icons.bar_chart)
            ),
            const SizedBox(height: 8),
            _buildComparisonChart(depositsTotal, withdrawalsTotal, betsTotal, winningsTotal, commissionsTotal),
            const SizedBox(height: 20),

            // 5. Diagramme de flux (Sankey simplifié)
            _tip(
              'Chemin de l\'argent : Dépôts → Portefeuille → Mises/Gains → Retraits/Commissions. '
              'La largeur est proportionnelle au volume.',
              AnalyticsSectionTitle('Chemin du Flux', icon: Icons.alt_route)
            ),
            const SizedBox(height: 8),
            _buildSankeyDiagram(depositsTotal, withdrawalsTotal, betsTotal, winningsTotal, commissionsTotal),
            const SizedBox(height: 20),

            // 6. Solde plateforme
            _tip(
              'Solde total FCFA et wiga de tous les joueurs. Flux net = Dépôts − Retraits.',
              AnalyticsSectionTitle('Solde Plateforme', icon: Icons.account_balance)
            ),
            const SizedBox(height: 8),
            _buildPlatformBalance(totalPlayerBalance, totalTokenBalance, netFlow),
            const SizedBox(height: 20),

            // 7. Vélocité
            if (velocityValue > 0) ...[
              _tip(
                'Vélocité = Volume total des transactions / Solde joueurs. '
                'Indique combien de fois l\'argent circule dans le système.',
                AnalyticsSectionTitle('Vélocité de Circulation', icon: Icons.speed)
              ),
              const SizedBox(height: 8),
              _buildVelocityCards(velocityValue, totalPlayerBalance, deposits, withdrawals),
              const SizedBox(height: 20),
            ],

            // 8. Top mouvements
            if (topMovements.isNotEmpty) ...[
              _tip(
                'Les 10 transactions les plus importantes en montant sur la période.',
                AnalyticsSectionTitle('Top Mouvements', icon: Icons.format_list_numbered)
              ),
              const SizedBox(height: 8),
              _buildTopMovementsTable(topMovements),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ========================================
  // 1. KPI FLUX PRINCIPAUX
  // ========================================

  Widget _buildFlowKpiCards(Map<String, dynamic> deposits, Map<String, dynamic> withdrawals, Map<String, dynamic> bets, Map<String, dynamic> winnings, Map<String, dynamic> commissions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossCount = isWide ? 5 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 1.3 : 1.1,
          children: [
            _tip('Montant total déposé par les joueurs.', AdminMetricCard(
              title: 'Dépôts', value: AnalyticsFormat.amountPrecise(deposits['total'] is int ? deposits['total'] / 100 : 0), icon: Icons.arrow_downward, color: NeonColors.success,
              subtitle: '${deposits['count'] ?? 0} tx',
            )),
            _tip('Montant total retiré par les joueurs.', AdminMetricCard(
              title: 'Retraits', value: AnalyticsFormat.amountPrecise(withdrawals['total'] is int ? withdrawals['total'] / 100 : 0), icon: Icons.arrow_upward, color: NeonColors.error,
              subtitle: '${withdrawals['count'] ?? 0} tx',
            )),
            _tip('Mises totales engagées dans les jeux.', AdminMetricCard(
              title: 'Mises', value: AnalyticsFormat.amountPrecise(bets['total']), icon: Icons.casino, color: NeonColors.secondary,
              subtitle: '${bets['count'] ?? 0} parties',
            )),
            _tip('Gains totaux reversés aux joueurs.', AdminMetricCard(
              title: 'Gains', value: AnalyticsFormat.amountPrecise(winnings['total']), icon: Icons.emoji_events, color: NeonColors.accent,
              subtitle: '${winnings['count'] ?? 0} tx',
            )),
            _tip('Commissions prélevées par la plateforme.', AdminMetricCard(
              title: 'Commissions', value: AnalyticsFormat.amountPrecise(commissions['total']), icon: Icons.percent, color: NeonColors.primary,
              subtitle: '${commissions['count'] ?? 0} tx',
            )),
          ],
        );
      },
    );
  }

  // ========================================
  // 2. KPI GAMING DÉRIVÉS (GGR, NGR, etc.)
  // ========================================

  Widget _buildDerivedKpiCards(double ggr, double ngr, double houseEdge, double payoutRatio, double netFlow) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossCount = isWide ? 5 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 1.3 : 1.1,
          children: [
            _tip('Revenu brut des jeux (GGR) : Mises − Gains.', AdminMetricCard(
              title: 'GGR', value: AnalyticsFormat.amountPrecise(ggr), icon: Icons.attach_money, color: NeonColors.success,
            )),
            _tip('Revenu net des jeux (NGR) : GGR − Commissions.', AdminMetricCard(
              title: 'NGR', value: AnalyticsFormat.amountPrecise(ngr), icon: Icons.money_off, color: ngr >= 0 ? NeonColors.success : NeonColors.error,
            )),
            _tip('Marge maison : GGR / Mises × 100.', AdminMetricCard(
              title: 'Marge', value: '${houseEdge.toStringAsFixed(1)}%', icon: Icons.trending_up, color: NeonColors.primary,
            )),
            _tip('Taux de redistribution : Gains / Mises × 100.', AdminMetricCard(
              title: 'Redistribution', value: '${payoutRatio.toStringAsFixed(1)}%', icon: Icons.replay, color: NeonColors.accent,
            )),
            _tip('Position nette : Dépôts − Retraits.', AdminMetricCard(
              title: 'Flux net', value: AnalyticsFormat.amountPrecise(netFlow / 100), icon: netFlow >= 0 ? Icons.north_east : Icons.south_east,
              color: netFlow >= 0 ? NeonColors.success : NeonColors.error,
            )),
          ],
        );
      },
    );
  }

  // ========================================
  // 3. GRAPHIQUE TIMESERIES INFLOW/OUTFLOW
  // ========================================

  Widget _buildTimeseriesChart(List<double> inflows, List<double> outflows, List<String> labels) {
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
          // Légende
          Row(
            children: [
              AnalyticsLegendDot(NeonColors.success, 'Entrées'),
              const SizedBox(width: 16),
              AnalyticsLegendDot(NeonColors.error, 'Sorties'),
              const Spacer(),
              if (labels.isNotEmpty) Text(
                '${labels.first} → ${labels.last}',
                style: const TextStyle(color: NeonColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(child: AdminLineChart(data: inflows, lineColor: NeonColors.success, height: 160, showDots: inflows.length <= 30)),
                const SizedBox(width: 8),
                Expanded(child: AdminLineChart(data: outflows, lineColor: NeonColors.error, height: 160, showDots: outflows.length <= 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 4. GRAPHIQUE COMPARAISON PAR TYPE
  // ========================================

  Widget _buildComparisonChart(double deposits, double withdrawals, double bets, double winnings, double commissions) {
    final maxVal = [deposits, withdrawals, bets, winnings, commissions].reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) {
      return const SizedBox(height: 60, child: Center(child: Text('Aucune donnée', style: TextStyle(color: NeonColors.textMuted))));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        children: [
          _barRow('Dépôts', deposits, maxVal, NeonColors.success, Icons.arrow_downward),
          const SizedBox(height: 6),
          _barRow('Retraits', withdrawals, maxVal, NeonColors.error, Icons.arrow_upward),
          const SizedBox(height: 6),
          _barRow('Mises', bets, maxVal, NeonColors.secondary, Icons.casino),
          const SizedBox(height: 6),
          _barRow('Gains', winnings, maxVal, NeonColors.accent, Icons.emoji_events),
          const SizedBox(height: 6),
          _barRow('Commissions', commissions, maxVal, NeonColors.primary, Icons.percent),
        ],
      ),
    );
  }

  Widget _barRow(String label, double value, double maxVal, Color color, IconData icon) {
    final ratio = maxVal > 0 ? value / maxVal : 0.0;
    return Tooltip(
      message: '$label : ${AnalyticsFormat.amountPrecise(value)}',
      child: Row(
        children: [
          SizedBox(width: 20, child: Icon(icon, color: color, size: 14)),
          const SizedBox(width: 6),
          SizedBox(width: 85, child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio, minHeight: 14,
                backgroundColor: NeonColors.background,
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text(AnalyticsFormat.amountPrecise(value), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 10), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // ========================================
  // 5. DIAGRAMME DE FLUX (Sankey simplifié)
  // ========================================

  Widget _buildSankeyDiagram(double deposits, double withdrawals, double bets, double winnings, double commissions) {
    final maxFlow = [deposits, bets, winnings, withdrawals].where((v) => v > 0).fold<double>(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        children: [
          _flowRow('Dépôts', deposits, maxFlow, NeonColors.success, Icons.arrow_downward),
          _flowArrow(),
          _flowRow('Portefeuille', deposits - withdrawals, maxFlow, NeonColors.accent, Icons.account_balance_wallet),
          _flowArrow(),
          Row(children: [
            Expanded(child: _flowRow('Mises', bets, maxFlow, NeonColors.secondary, Icons.casino)),
            const SizedBox(width: 8),
            Expanded(child: _flowRow('Gains', winnings, maxFlow, NeonColors.info, Icons.emoji_events)),
          ]),
          _flowArrow(),
          Row(children: [
            Expanded(child: _flowRow('Retraits', withdrawals, maxFlow, NeonColors.error, Icons.arrow_upward)),
            const SizedBox(width: 8),
            Expanded(child: _flowRow('Commission', commissions, maxFlow, NeonColors.primary, Icons.percent)),
          ]),
        ],
      ),
    );
  }

  Widget _flowRow(String label, double amount, double maxFlow, Color color, IconData icon) {
    final ratio = maxFlow > 0 ? (amount.abs() / maxFlow).clamp(0.0, 1.0) : 0.0;
    return Tooltip(
      message: '$label : ${AnalyticsFormat.amountPrecise(amount)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
            Expanded(flex: 3, child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: ratio, backgroundColor: NeonColors.background, valueColor: AlwaysStoppedAnimation(color), minHeight: 12),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: Text(AnalyticsFormat.amountPrecise(amount), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 10), textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }

  Widget _flowArrow() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 2),
    child: Center(child: Icon(Icons.arrow_downward, color: NeonColors.textMuted, size: 14)),
  );

  // ========================================
  // 6. SOLDE PLATEFORME
  // ========================================

  Widget _buildPlatformBalance(double fcfaBalance, double tokenBalance, double netFlow) {
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
          _tip('Solde total (wiga) de tous les joueurs.\nValeur exacte : ${(fcfaBalance/100).toStringAsFixed(0)} wiga', _balanceItem('Solde Wiga', fcfaBalance/100, NeonColors.success)),
          Container(width: 1, height: 40, color: NeonColors.border),
          _tip('Solde en wiga (tokens) de tous les joueurs.\nValeur exacte : ${tokenBalance.toStringAsFixed(0)} wiga', _balanceItem('Solde Wiga', tokenBalance, NeonColors.accent)),
          Container(width: 1, height: 40, color: NeonColors.border),
          _tip('Position nette : Dépôts − Retraits.\nValeur exacte : ${(netFlow/100).toStringAsFixed(0)} wiga', _balanceItem('Flux net', netFlow/100, netFlow >= 0 ? NeonColors.success : NeonColors.error)),
        ],
      ),
    );
  }

  Widget _balanceItem(String label, dynamic value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(AnalyticsFormat.amountPrecise(value), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }

  // ========================================
  // 7. VÉLOCITÉ DE CIRCULATION
  // ========================================

  Widget _buildVelocityCards(double velocity, double avgBalance, Map<String, dynamic> deposits, Map<String, dynamic> withdrawals) {
    final totalTxCount = ((deposits['count'] as num?)?.toInt() ?? 0) + ((withdrawals['count'] as num?)?.toInt() ?? 0);
    return Row(children: [
      Expanded(child: _tip('Ratio volume/solde. Plus c\'est élevé, plus l\'argent circule.', _velocityCard('Vélocité', '${velocity.toStringAsFixed(1)}x', NeonColors.primary))),
      const SizedBox(width: 8),
      Expanded(child: _tip('Solde moyen détenu par les joueurs.', _velocityCard('Solde moyen', AnalyticsFormat.amountPrecise(avgBalance), NeonColors.accent))),
      const SizedBox(width: 8),
      Expanded(child: _tip('Nombre total de transactions (dépôts + retraits).', _velocityCard('Transactions', '$totalTxCount', NeonColors.secondary))),
    ]);
  }

  Widget _velocityCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: NeonColors.textMuted, fontSize: 9), textAlign: TextAlign.center),
      ]),
    );
  }

  // ========================================
  // 8. TOP MOUVEMENTS
  // ========================================

  Widget _buildTopMovementsTable(List<dynamic> movements) {
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
            child: Text('Top 10 Mouvements', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(NeonColors.background),
              dataRowColor: WidgetStateProperty.all(NeonColors.surface),
              columns: const [
                DataColumn(label: Text('Joueur', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Type', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Montant', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                DataColumn(label: Text('Date', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
              rows: movements.take(10).map((m) {
                final type = m['type'] as String? ?? '';
                final isPositive = type == 'deposit' || type == 'winnings' || type == 'refund';
                return DataRow(cells: [
                  DataCell(Text(m['username'] as String? ?? '#${m['user_id']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPositive ? NeonColors.success : NeonColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(type, style: TextStyle(color: isPositive ? NeonColors.success : NeonColors.error, fontSize: 10, fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Text(AnalyticsFormat.amountPrecise(m['amount']), style: TextStyle(color: isPositive ? NeonColors.success : NeonColors.error, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  DataCell(Text(AnalyticsFormat.date(m['inserted_at'] ?? m['date']), style: const TextStyle(color: NeonColors.textMuted, fontSize: 10))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // HELPERS
  // ========================================

  Widget _tip(String message, Widget child) => Tooltip(message: message, waitDuration: const Duration(milliseconds: 300), child: child);
}

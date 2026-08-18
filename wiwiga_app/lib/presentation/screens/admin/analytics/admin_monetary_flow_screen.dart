// ============================================================
// Fichier: admin_monetary_flow_screen.dart
// Description: Écran flux monétaire - Sankey, flux net, mouvements
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../../providers/admin_analytics_provider.dart';
import '../../../widgets/admin/metric_card.dart';

/// Écran Flux Monétaire (depos -> wallet -> mises -> gains -> retraits + commission)
class AdminMonetaryFlowScreen extends ConsumerStatefulWidget {
  const AdminMonetaryFlowScreen({super.key});

  @override
  ConsumerState<AdminMonetaryFlowScreen> createState() => _AdminMonetaryFlowScreenState();
}

class _AdminMonetaryFlowScreenState extends ConsumerState<AdminMonetaryFlowScreen> {
  static const _periods = ['24h', '7d', '30d', '90d'];
  static const _periodLabels = ['24h', '7j', '30j', '90j'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminMonetaryFlowProvider.notifier).load();
    });
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
                  final notifier = ref.read(adminMonetaryFlowProvider.notifier);
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

  Widget _buildContent(AdminMonetaryFlowState state) {
    final data = state.data ?? {};
    final flows = data['flows'] as Map<String, dynamic>? ?? {};
    final platformBalance = data['platform_balance'] as Map<String, dynamic>? ?? {};
    final topMovements = data['top_movements'] as List<dynamic>? ?? [];
    final velocity = data['velocity'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: () => ref.read(adminMonetaryFlowProvider.notifier).load(),
      color: NeonColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards flux
            _buildFlowKpiCards(flows),
            const SizedBox(height: 20),

            // Diagramme Sankey simplifié (flux visuel)
            _buildSectionTitle('Diagramme de Flux'),
            const SizedBox(height: 8),
            _buildSankeyDiagram(flows),
            const SizedBox(height: 20),

            // Solde plateforme
            _buildSectionTitle('Solde Plateforme'),
            const SizedBox(height: 8),
            _buildPlatformBalance(platformBalance),
            const SizedBox(height: 20),

            // Indicateurs velocity
            if (velocity.isNotEmpty) ...[
              _buildSectionTitle('Vitesse de Circulation'),
              const SizedBox(height: 8),
              _buildVelocityCards(velocity),
              const SizedBox(height: 20),
            ],

            // Top mouvements
            if (topMovements.isNotEmpty) ...[
              _buildSectionTitle('Top Mouvements'),
              const SizedBox(height: 8),
              _buildTopMovementsTable(topMovements),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlowKpiCards(Map<String, dynamic> flows) {
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
              title: 'Depos',
              value: _formatAmount(flows['total_deposits']),
              icon: Icons.arrow_downward,
              color: NeonColors.success,
            ),
            AdminMetricCard(
              title: 'Retraits',
              value: _formatAmount(flows['total_withdrawals']),
              icon: Icons.arrow_upward,
              color: NeonColors.error,
            ),
            AdminMetricCard(
              title: 'Mises',
              value: _formatAmount(flows['total_bets']),
              icon: Icons.casino,
              color: NeonColors.secondary,
            ),
            AdminMetricCard(
              title: 'Gains',
              value: _formatAmount(flows['total_winnings']),
              icon: Icons.emoji_events,
              color: NeonColors.accent,
            ),
            AdminMetricCard(
              title: 'Commissions',
              value: _formatAmount(flows['total_commissions']),
              icon: Icons.percent,
              color: NeonColors.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSankeyDiagram(Map<String, dynamic> flows) {
    final deposits = (flows['total_deposits'] as num?)?.toDouble() ?? 0;
    final bets = (flows['total_bets'] as num?)?.toDouble() ?? 0;
    final winnings = (flows['total_winnings'] as num?)?.toDouble() ?? 0;
    final withdrawals = (flows['total_withdrawals'] as num?)?.toDouble() ?? 0;
    final commissions = (flows['total_commissions'] as num?)?.toDouble() ?? 0;
    final maxFlow = [deposits, bets, winnings, withdrawals].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        children: [
          _buildFlowRow('Depos', deposits, maxFlow, NeonColors.success, Icons.arrow_downward),
          _buildFlowArrow(),
          _buildFlowRow('Wallet', deposits - withdrawals, maxFlow, NeonColors.accent, Icons.account_balance_wallet),
          _buildFlowArrow(),
          Row(
            children: [
              Expanded(child: _buildFlowRow('Mises', bets, maxFlow, NeonColors.secondary, Icons.casino)),
              const SizedBox(width: 8),
              Expanded(child: _buildFlowRow('Gains', winnings, maxFlow, NeonColors.info, Icons.emoji_events)),
            ],
          ),
          _buildFlowArrow(),
          Row(
            children: [
              Expanded(child: _buildFlowRow('Retraits', withdrawals, maxFlow, NeonColors.error, Icons.arrow_upward)),
              const SizedBox(width: 8),
              Expanded(child: _buildFlowRow('Commission', commissions, maxFlow, NeonColors.primary, Icons.percent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowRow(String label, double amount, double maxFlow, Color color, IconData icon) {
    final ratio = maxFlow > 0 ? amount / maxFlow : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: NeonColors.background,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text(_formatAmount(amount), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 10), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildFlowArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Center(child: Icon(Icons.arrow_downward, color: NeonColors.textMuted, size: 14)),
    );
  }

  Widget _buildPlatformBalance(Map<String, dynamic> balance) {
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
          _buildBalanceItem('Solde FCFA', balance['fcfa_balance'], NeonColors.success),
          Container(width: 1, height: 40, color: NeonColors.border),
          _buildBalanceItem('Solde Tokens', balance['token_balance'], NeonColors.accent),
          Container(width: 1, height: 40, color: NeonColors.border),
          _buildBalanceItem('Net Flow', balance['net_flow'], ((balance['net_flow'] as num?)?.toDouble() ?? 0) >= 0 ? NeonColors.success : NeonColors.error),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, dynamic value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 4),
        Text(_formatAmount(value), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildVelocityCards(Map<String, dynamic> velocity) {
    return Row(
      children: [
        Expanded(child: _buildVelocityCard('Vitesse circulation', '${(velocity['turnover_rate'] as num?)?.toDouble().toStringAsFixed(1) ?? '0'}x', NeonColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: _buildVelocityCard('Solde moyen', _formatAmount(velocity['avg_balance']), NeonColors.accent)),
        const SizedBox(width: 8),
        Expanded(child: _buildVelocityCard('Tx/jour', '${velocity['daily_transactions'] ?? 0}', NeonColors.secondary)),
      ],
    );
  }

  Widget _buildVelocityCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: NeonColors.textMuted, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }

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
            child: Text('Top Mouvements de Jetons', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Table(
            border: TableBorder.all(color: NeonColors.border.withValues(alpha: 0.5)),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(1)},
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFF1E293B)),
                children: [
                  Padding(padding: EdgeInsets.all(8), child: Text('Joueur', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Type', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Montant', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Date', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
              ),
              ...movements.take(10).map((m) {
                final type = m['type'] as String? ?? '';
                final isPositive = type == 'deposit' || type == 'winnings' || type == 'refund';
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(m['username'] as String? ?? '#${m['user_id']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(type, style: TextStyle(color: isPositive ? NeonColors.success : NeonColors.error, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(_formatAmount(m['amount']), style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(_formatDate(m['date']), style: const TextStyle(color: NeonColors.textMuted, fontSize: 10))),
                  ],
                );
              }),
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
          Text(error, style: const TextStyle(color: NeonColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(adminMonetaryFlowProvider.notifier).load(),
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
    if (amount.abs() >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    if (amount.abs() >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K FCFA';
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}

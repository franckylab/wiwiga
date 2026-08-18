// ============================================================
// Fichier: admin_player_wealth_screen.dart
// Description: Écran distribution richesse joueurs - P&L, segments
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../../providers/admin_analytics_provider.dart';
import '../../../widgets/admin/metric_card.dart';
import '../../../widgets/admin/chart_widget.dart';

/// Écran Player Wealth (distribution gains/pertes, segments, P&L)
class AdminPlayerWealthScreen extends ConsumerStatefulWidget {
  const AdminPlayerWealthScreen({super.key});

  @override
  ConsumerState<AdminPlayerWealthScreen> createState() => _AdminPlayerWealthScreenState();
}

class _AdminPlayerWealthScreenState extends ConsumerState<AdminPlayerWealthScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminWealthProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminWealthProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Player Wealth'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
      ),
      body: state.isLoading && state.data == null
          ? const Center(child: CircularProgressIndicator(color: NeonColors.primary))
          : state.error != null && state.data == null
              ? _buildError(state.error!)
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminWealthState state) {
    final data = state.data ?? {};
    final quartiles = data['quartiles'] as List<dynamic>? ?? [];
    final histogram = data['histogram'] as List<dynamic>? ?? [];
    final topWinners = data['top_winners'] as List<dynamic>? ?? [];
    final topLosers = data['top_losers'] as List<dynamic>? ?? [];
    final segments = data['segments'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: () => ref.read(adminWealthProvider.notifier).load(),
      color: NeonColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segment cards
            _buildSegmentCards(segments),
            const SizedBox(height: 20),

            // Distribution quartiles
            if (quartiles.isNotEmpty) ...[
              _buildSectionTitle('Distribution par Quartile'),
              const SizedBox(height: 8),
              _buildQuartileCards(quartiles),
              const SizedBox(height: 20),
            ],

            // Histogramme P&L
            if (histogram.isNotEmpty) ...[
              _buildSectionTitle('Histogramme P&L'),
              const SizedBox(height: 8),
              AdminBarChart(
                data: histogram.map((h) => (h['count'] as num?)?.toDouble() ?? 0.0).toList(),
                barColor: NeonColors.accent,
                label: 'Nombre de joueurs par tranche',
                height: 180,
                labels: histogram.map((h) => h['label'] as String? ?? '').toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Top gagnants et perdants
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topWinners.isNotEmpty) Expanded(child: _buildTopTable('Top Gagnants', topWinners, NeonColors.success)),
                if (topWinners.isNotEmpty && topLosers.isNotEmpty) const SizedBox(width: 12),
                if (topLosers.isNotEmpty) Expanded(child: _buildTopTable('Top Perdants', topLosers, NeonColors.error)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCards(Map<String, dynamic> segments) {
    final positive = segments['positive'] as Map<String, dynamic>? ?? {};
    final negative = segments['negative'] as Map<String, dynamic>? ?? {};
    final neutral = segments['neutral'] as Map<String, dynamic>? ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossCount = isWide ? 3 : 3;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.5 : 1.2,
          children: [
            AdminMetricCard(
              title: 'Joueurs Positifs',
              value: '${positive['count'] ?? 0}',
              icon: Icons.trending_up,
              color: NeonColors.success,
              subtitle: '${((positive['percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% du total',
            ),
            AdminMetricCard(
              title: 'Joueurs Négatifs',
              value: '${negative['count'] ?? 0}',
              icon: Icons.trending_down,
              color: NeonColors.error,
              subtitle: '${((negative['percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% du total',
            ),
            AdminMetricCard(
              title: 'Neutres / Nuls',
              value: '${neutral['count'] ?? 0}',
              icon: Icons.remove,
              color: NeonColors.textMuted,
              subtitle: '${((neutral['percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% du total',
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuartileCards(List<dynamic> quartiles) {
    final colors = [NeonColors.success, NeonColors.primary, NeonColors.secondary, NeonColors.error];
    return Column(
      children: quartiles.asMap().entries.map((entry) {
        final q = entry.value;
        final color = colors[entry.key % colors.length];
        final pnl = (q['net_pnl'] as num?)?.toDouble() ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeonColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Q${entry.key + 1}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${q['player_count'] ?? 0} joueurs', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Mises: ${_formatAmount(q['total_wagered'])} | Gains: ${_formatAmount(q['total_won'])}', style: const TextStyle(color: NeonColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              Text(
                _formatAmount(pnl),
                style: TextStyle(color: pnl >= 0 ? NeonColors.success : NeonColors.error, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopTable(String title, List<dynamic> players, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          ...players.take(10).map((p) {
            final pnl = (p['net_pnl'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Text('#${players.indexOf(p) + 1}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p['username'] as String? ?? 'Joueur', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11))),
                  Text(_formatAmount(pnl), style: TextStyle(color: pnl >= 0 ? NeonColors.success : NeonColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
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
            onPressed: () => ref.read(adminWealthProvider.notifier).load(),
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
}

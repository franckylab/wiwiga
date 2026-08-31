// ============================================================
// Fichier: admin_player_analytics_screen.dart
// Description: Écran analytics joueurs - DAU, WAU, MAU, retention
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../../providers/admin_analytics_provider.dart';
import '../../../widgets/admin/metric_card.dart';
import '../../../widgets/admin/chart_widget.dart';
import '../../../widgets/admin/empty_state.dart';
import '../../../widgets/admin/analytics_helpers.dart';
import '../../../widgets/neon/neon_widgets.dart';

/// Écran Player Analytics (DAU, WAU, MAU, Stickiness, Reg2Dep, Retention)
class AdminPlayerAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminPlayerAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminPlayerAnalyticsScreen> createState() => _AdminPlayerAnalyticsScreenState();
}

class _AdminPlayerAnalyticsScreenState extends ConsumerState<AdminPlayerAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminPlayerAnalyticsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPlayerAnalyticsProvider);
    final cohortsState = ref.watch(adminRetentionCohortsProvider);
    final funnelState = ref.watch(adminConversionFunnelProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Analytique Joueurs'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          AnalyticsPeriodSelector(
            value: state.selectedPeriod,
            onChanged: (value) {
              if (value != null) {
                final notifier = ref.read(adminPlayerAnalyticsProvider.notifier);
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
              ? AdminErrorState(error: state.error!, onRetry: () => ref.read(adminPlayerAnalyticsProvider.notifier).load())
              : _buildContent(state, cohortsState, funnelState),
    );
  }

  Widget _buildContent(
    AdminPlayerAnalyticsState state,
    AsyncValue<Map<String, dynamic>> cohortsState,
    AsyncValue<Map<String, dynamic>> funnelState,
  ) {
    final data = state.data ?? {};
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final deltas = data['deltas'] as Map<String, dynamic>? ?? {};
    final dauTimeseries = data['dau_timeseries'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(adminPlayerAnalyticsProvider.notifier).load();
        ref.invalidate(adminRetentionCohortsProvider);
        ref.invalidate(adminConversionFunnelProvider);
      },
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

            // DAU Timeseries
            if (dauTimeseries.isNotEmpty) ...[
              const AnalyticsSectionTitle('Utilisateurs Actifs (DAU)'),
              const SizedBox(height: 8),
              AdminLineChart(
                data: dauTimeseries.map((t) => (t['count'] as num?)?.toDouble() ?? 0.0).toList(),
                lineColor: NeonColors.accent,
                label: 'DAU',
                height: 180,
              ),
              const SizedBox(height: 20),
            ],

            // Retention Cohorts
            const AnalyticsSectionTitle('Rétention Cohortes'),
            const SizedBox(height: 8),
            cohortsState.when(
              data: (d) => _buildRetentionSection(d),
              loading: () => const SizedBox(height: 100, child: NeonLoadingSpinner.center()),
              error: (e, st) {
                ErrorHandler.logError(e, st, context: 'AdminPlayerAnalytics.retention');
                return Text(ErrorHandler.userMessage(e), style: const TextStyle(color: NeonColors.error));
              },
            ),
            const SizedBox(height: 20),

            // Entonnoir de conversion
            const AnalyticsSectionTitle('Entonnoir de Conversion'),
            const SizedBox(height: 8),
            funnelState.when(
              data: (d) => _buildFunnelSection(d),
              loading: () => const SizedBox(height: 100, child: NeonLoadingSpinner.center()),
              error: (e, st) {
                ErrorHandler.logError(e, st, context: 'AdminPlayerAnalytics.funnel');
                return Text(ErrorHandler.userMessage(e), style: const TextStyle(color: NeonColors.error));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(Map<String, dynamic> summary, Map<String, dynamic> deltas) {
    return AnalyticsKpiGrid(
      children: [
        AdminMetricCard(
          title: 'DAU',
          value: AnalyticsFormat.number(summary['dau']),
          icon: Icons.today,
          color: NeonColors.accent,
          deltaPercent: AnalyticsFormat.toDouble(deltas['dau_delta']),
          subtitle: 'Utilisateurs actifs quotidiens',
        ),
        AdminMetricCard(
          title: 'WAU',
          value: AnalyticsFormat.number(summary['wau']),
          icon: Icons.date_range,
          color: NeonColors.primary,
          deltaPercent: AnalyticsFormat.toDouble(deltas['wau_delta']),
          subtitle: 'Utilisateurs actifs hebdomadaires',
        ),
        AdminMetricCard(
          title: 'MAU',
          value: AnalyticsFormat.number(summary['mau']),
          icon: Icons.calendar_month,
          color: NeonColors.info,
          deltaPercent: AnalyticsFormat.toDouble(deltas['mau_delta']),
          subtitle: 'Utilisateurs actifs mensuels',
        ),
        AdminMetricCard(
          title: 'Fidélité',
          value: AnalyticsFormat.percent(summary['stickiness']),
          icon: Icons.sticky_note_2,
          color: NeonColors.secondary,
          subtitle: 'DAU / MAU',
        ),
        AdminMetricCard(
          title: 'Reg2Dep',
          value: AnalyticsFormat.percent(summary['reg2dep_rate']),
          icon: Icons.how_to_reg,
          color: NeonColors.success,
          subtitle: 'Inscrits → Dépôt',
          deltaPercent: AnalyticsFormat.toDouble(deltas['reg2dep_delta']),
        ),
      ],
    );
  }

  Widget _buildRetentionSection(Map<String, dynamic> data) {
    final averages = data['averages'] as Map<String, dynamic>? ?? {};
    final cohorts = data['cohorts'] as List<dynamic>? ?? [];

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
          // D1, D7, D30 averages
          Row(
            children: [
              _buildRetentionBadge('D1', averages['avg_d1'], NeonColors.primary),
              const SizedBox(width: 12),
              _buildRetentionBadge('D7', averages['avg_d7'], NeonColors.secondary),
              const SizedBox(width: 12),
              _buildRetentionBadge('D30', averages['avg_d30'], NeonColors.accent),
            ],
          ),
          if (cohorts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Cohortes récentes', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cohorts.take(8).length,
                itemBuilder: (context, i) {
                  final cohort = cohorts[i];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NeonColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cohort['week'] as String? ?? '', style: const TextStyle(color: NeonColors.textMuted, fontSize: 9)),
                        const SizedBox(height: 4),
                        Text('${cohort['size'] ?? 0}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('D1: ${AnalyticsFormat.percent(cohort['d1_rate'], decimals: 0)}', style: const TextStyle(color: NeonColors.primary, fontSize: 9)),
                        Text('D7: ${AnalyticsFormat.percent(cohort['d7_rate'], decimals: 0)}', style: const TextStyle(color: NeonColors.secondary, fontSize: 9)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunnelSection(Map<String, dynamic> data) {
    final steps = data['steps'] as List<dynamic>? ?? [];
    if (steps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Aucune donnée d\'entonnoir', style: TextStyle(color: NeonColors.textMuted)),
      );
    }

    final maxCount = (steps.first['count'] as num?)?.toDouble() ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final step = entry.value;
          final count = (step['count'] as num?)?.toDouble() ?? 0;
          final ratio = count / maxCount;
          final colors = [NeonColors.primary, NeonColors.accent, NeonColors.secondary, NeonColors.success];
          final color = colors[entry.key % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(step['label'] as String? ?? '', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: NeonColors.background,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${AnalyticsFormat.number(count)} (${AnalyticsFormat.percent(step['rate'], decimals: 0)})',
                    style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRetentionBadge(String label, dynamic value, Color color) {
    final pct = AnalyticsFormat.percent(value, decimals: 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          Text('$pct', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}

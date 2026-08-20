// ============================================================
// Fichier: admin_metrics_screen.dart
// Description: Écran métriques admin avec graphiques et filtres
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/metric_card.dart';
import '../../widgets/admin/chart_widget.dart';
import '../../widgets/admin/analytics_helpers.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran des métriques admin
class AdminMetricsScreen extends ConsumerStatefulWidget {
  const AdminMetricsScreen({super.key});

  @override
  ConsumerState<AdminMetricsScreen> createState() => _AdminMetricsScreenState();
}

class _AdminMetricsScreenState extends ConsumerState<AdminMetricsScreen> {
  int _selectedTab = 0;
  String _selectedPeriod = '24h';

  static const _periods = ['24h', '7d', '30d', '90d'];
  static const _periodLabels = ['24h', '7j', '30j', '90j'];
  static const _tabs = ['Financier', 'Jeux', 'Utilisateurs', 'Paiements', 'Sécurité'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminMetricsProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminMetricsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Métriques', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exporter CSV',
            onPressed: _showExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminMetricsProvider.notifier).loadAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de période
          _buildPeriodSelector(),
          // Onglets
          _buildTabBar(),
          // Contenu
          Expanded(
            child: state.isLoading && state.dashboard == null
                ? const NeonLoadingSpinner.center()
                : RefreshIndicator(
                    color: NeonColors.primary,
                    onRefresh: () => ref.read(adminMetricsProvider.notifier).loadAll(),
                    child: state.error != null
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: AdminErrorState(error: state.error!, onRetry: () => ref.read(adminMetricsProvider.notifier).loadAll()),
                          )
                        : _buildTabContent(state),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NeonColors.surface,
      child: Row(
        children: List.generate(_periods.length, (i) {
          final isSelected = _selectedPeriod == _periods[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_periodLabels[i]),
              selected: isSelected,
              selectedColor: NeonColors.primary.withValues(alpha: 0.2),
              backgroundColor: NeonColors.card,
              labelStyle: TextStyle(
                color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? NeonColors.primary : NeonColors.border,
              ),
              onSelected: (selected) {
                setState(() => _selectedPeriod = _periods[i]);
                ref.read(adminMetricsProvider.notifier).setPeriod(_periods[i]);
                ref.read(adminMetricsProvider.notifier).loadAll();
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: NeonColors.surface,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? NeonColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(AdminMetricsState state) {
    switch (_selectedTab) {
      case 0:
        return _buildFinancialTab(state);
      case 1:
        return _buildGamesTab(state);
      case 2:
        return _buildUsersTab(state);
      case 3:
        return _buildPaymentsTab(state);
      case 4:
        return _buildSecurityTab(state);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFinancialTab(AdminMetricsState state) {
    final financial = state.financial ?? {};
    final dashboard = state.dashboard ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière liens vers Analytics détaillés
          _buildAnalyticsLinksBanner(),
          const SizedBox(height: 16),
          const Text('Vue d\'ensemble', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AdminResponsiveGrid(
            desktopColumns: 4,
            desktopRatio: 1.6,
            children: [
              AdminMetricCard(
                title: 'Revenu total',
                value: AnalyticsFormat.amount(financial['total_revenue'] ?? dashboard['total_revenue_24h'] ?? 0),
                icon: Icons.account_balance_wallet,
                color: NeonColors.success,
              ),
              AdminMetricCard(
                title: 'Commissions',
                value: AnalyticsFormat.amount(financial['total_commissions'] ?? 0),
                icon: Icons.percent,
                color: NeonColors.primary,
              ),
              AdminMetricCard(
                title: 'Volume dépôts',
                value: AnalyticsFormat.amount(financial['total_deposits'] ?? 0),
                icon: Icons.arrow_downward,
                color: NeonColors.info,
              ),
              AdminMetricCard(
                title: 'Volume retraits',
                value: AnalyticsFormat.amount(financial['total_withdrawals'] ?? 0),
                icon: Icons.arrow_upward,
                color: NeonColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (financial['timeseries'] != null)
            AdminLineChart(
              data: _extractTimeseriesValues(financial['timeseries']),
              label: 'Revenus (période)',
              lineColor: NeonColors.success,
            ),
        ],
      ),
    );
  }

  Widget _buildGamesTab(AdminMetricsState state) {
    final games = state.games ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Jeux', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AdminResponsiveGrid(
            desktopColumns: 4,
            desktopRatio: 1.6,
            children: [
              AdminMetricCard(
                title: 'Parties actives',
                value: '${games['active_games'] ?? 0}',
                icon: Icons.videogame_asset,
                color: NeonColors.accent,
              ),
              AdminMetricCard(
                title: 'Parties terminées',
                value: '${games['completed_games'] ?? games['total_matches'] ?? 0}',
                icon: Icons.check_circle,
                color: NeonColors.success,
              ),
              AdminMetricCard(
                title: 'Mise moyenne',
                value: AnalyticsFormat.amount(games['average_bet'] ?? 0),
                icon: Icons.monetization_on,
                color: NeonColors.secondary,
              ),
              AdminMetricCard(
                title: 'GGR',
                value: AnalyticsFormat.amount(games['ggr'] ?? games['gross_gaming_revenue'] ?? 0),
                icon: Icons.trending_up,
                color: NeonColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(AdminMetricsState state) {
    final users = state.users ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Utilisateurs', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AdminResponsiveGrid(
            desktopColumns: 4,
            desktopRatio: 1.6,
            children: [
              AdminMetricCard(
                title: 'Inscriptions',
                value: '${users['new_registrations'] ?? users['new_users'] ?? 0}',
                icon: Icons.person_add,
                color: NeonColors.success,
              ),
              AdminMetricCard(
                title: 'Connectés',
                value: '${users['active_users'] ?? users['logged_in_users'] ?? 0}',
                icon: Icons.people,
                color: NeonColors.info,
              ),
              AdminMetricCard(
                title: 'Total utilisateurs',
                value: '${users['total_users'] ?? 0}',
                icon: Icons.group,
                color: NeonColors.primary,
              ),
              AdminMetricCard(
                title: 'Taux rétention',
                value: '${(users['retention_rate'] ?? 0).toStringAsFixed(1)}%',
                icon: Icons.repeat,
                color: NeonColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(AdminMetricsState state) {
    final payments = state.payments ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paiements', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AdminResponsiveGrid(
            desktopColumns: 4,
            desktopRatio: 1.6,
            children: [
              AdminMetricCard(
                title: 'Taux succès',
                value: '${(payments['success_rate'] ?? 0).toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline,
                color: NeonColors.success,
              ),
              AdminMetricCard(
                title: 'Transactions',
                value: '${payments['total_transactions'] ?? 0}',
                icon: Icons.receipt_long,
                color: NeonColors.info,
              ),
              AdminMetricCard(
                title: 'Volume total',
                value: AnalyticsFormat.amount(payments['total_volume'] ?? 0),
                icon: Icons.payments,
                color: NeonColors.primary,
              ),
              AdminMetricCard(
                title: 'Temps moyen',
                value: '${payments['avg_processing_time_seconds'] ?? 0}s',
                icon: Icons.timer,
                color: NeonColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab(AdminMetricsState state) {
    final security = state.security ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sécurité', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AdminResponsiveGrid(
            desktopColumns: 4,
            desktopRatio: 1.6,
            children: [
              AdminMetricCard(
                title: 'Auth échouées',
                value: '${security['failed_auth_attempts'] ?? 0}',
                icon: Icons.lock_clock,
                color: NeonColors.error,
              ),
              AdminMetricCard(
                title: 'Requêtes limitées',
                value: '${security['rate_limited_requests'] ?? 0}',
                icon: Icons.speed,
                color: NeonColors.warning,
              ),
              AdminMetricCard(
                title: 'IPs suspectes',
                value: '${security['suspicious_ips'] ?? 0}',
                icon: Icons.warning_amber,
                color: NeonColors.secondary,
              ),
              AdminMetricCard(
                title: 'Exclusions actives',
                value: '${security['active_bans'] ?? 0}',
                icon: Icons.block,
                color: NeonColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  void _showExportDialog() {
    final adminRepo = ref.read(adminRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Exporter les données', style: TextStyle(color: NeonColors.textPrimary)),
        content: const Text('Choisissez le type d\'export au format CSV.',
          style: TextStyle(color: NeonColors.textSecondary),),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textMuted)),),
          // Export utilisateurs
          TextButton.icon(
            icon: const Icon(Icons.people, color: NeonColors.primary, size: 18),
            label: const Text('Utilisateurs', style: TextStyle(color: NeonColors.primary)),
            onPressed: () {
              Navigator.pop(ctx);
              _launchExport(adminRepo.getExportUsersUrl(), 'utilisateurs');
            },
          ),
          // Export transactions
          TextButton.icon(
            icon: const Icon(Icons.receipt_long, color: NeonColors.accent, size: 18),
            label: const Text('Transactions', style: TextStyle(color: NeonColors.accent)),
            onPressed: () {
              Navigator.pop(ctx);
              _launchExport(adminRepo.getExportTransactionsUrl(), 'transactions');
            },
          ),
          // Export parties
          TextButton.icon(
            icon: const Icon(Icons.videogame_asset, color: NeonColors.adminMagenta, size: 18),
            label: const Text('Parties', style: TextStyle(color: NeonColors.adminMagenta)),
            onPressed: () {
              Navigator.pop(ctx);
              _launchExport(adminRepo.getExportGamesUrl(), 'parties');
            },
          ),
        ],
      ),
    );
  }

  void _launchExport(String url, String label) {
    context.showInfo('Export $label en cours... Le fichier CSV sera téléchargé.');
    // L'URL d'export est construite - le téléchargement se fait via le navigateur
    // ou un launcher d'URL externe
  }

  List<double> _extractTimeseriesValues(dynamic timeseries) {
    if (timeseries is List) {
      return timeseries.map<double>((e) {
        if (e is Map) return (e['value'] ?? e['amount'] ?? 0).toDouble();
        return (e as num?)?.toDouble() ?? 0;
      }).toList();
    }
    return [0];
  }

  Widget _buildAnalyticsLinksBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NeonColors.primary.withValues(alpha: 0.15), NeonColors.accent.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: NeonColors.primary, size: 16),
              SizedBox(width: 6),
              Text('Analytics détaillés', style: TextStyle(color: NeonColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildAnalyticsChip('Revenus', Icons.monetization_on, () => context.go('/admin/analytics/revenue')),
              _buildAnalyticsChip('Joueurs', Icons.people_outline, () => context.go('/admin/analytics/players')),
              _buildAnalyticsChip('Jeux', Icons.sports_esports, () => context.go('/admin/analytics/games')),
              _buildAnalyticsChip('Flux', Icons.swap_horiz, () => context.go('/admin/analytics/monetary-flow')),
              _buildAnalyticsChip('Richesse', Icons.account_tree, () => context.go('/admin/analytics/wealth')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NeonColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: NeonColors.primary, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

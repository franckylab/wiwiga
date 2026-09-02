// ============================================================
// Fichier: admin_dashboard_screen.dart
// Description: Dashboard d'administration WIWIGA - Enrichi
//              Métriques, monitoring, actions rapides
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/error_handler.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../presentation/widgets/auth/avatar_picker.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/admin/metric_card.dart';
import '../../widgets/admin/chart_widget.dart';
import '../../widgets/admin/alert_badge.dart';
import '../../widgets/admin/analytics_helpers.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/admin/empty_state.dart';

/// Dashboard d'administration principal
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Charger les métriques dashboard
    Future.microtask(() {
      ref.read(adminMetricsProvider.notifier).loadDashboard();
      ref.read(adminAlertsProvider.notifier).loadUnreadCount();
    });
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final stats = await adminRepo.getStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminDashboard._loadStats');
      setState(() {
        _error = ErrorHandler.userMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: NeonColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: NeonColors.error, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Accès non autorisé',
                style: TextStyle(color: NeonColors.textPrimary, fontSize: 20),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text(
          'Administration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: NeonColors.primary),
            onPressed: _loadStats,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _roleColor(user.role).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _roleColor(user.role), width: 1),
              ),
              child: Text(
                user.role.displayName,
                style: TextStyle(
                  color: _roleColor(user.role),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: NeonColors.primary,
        child: _isLoading
            ? const NeonLoadingSpinner.center()
            : _error != null
                ? AdminErrorState(error: _error!, onRetry: _loadStats)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildAdminProfile(user),
                      const SizedBox(height: 20),
                      _buildPlatformHealthAndAlerts(),
                      const SizedBox(height: 16),
                      CollapsibleSection(
                        title: 'Métriques en direct',
                        icon: Icons.insights,
                        children: [_buildLiveMetricsSection()],
                      ),
                      CollapsibleSection(
                        title: 'Utilisateurs',
                        icon: Icons.people,
                        children: [_buildStatsGrid()],
                      ),
                      CollapsibleSection(
                        title: 'Activité & Sécurité',
                        icon: Icons.security,
                        children: [_buildActivityMetrics()],
                      ),
                      CollapsibleSection(
                        title: 'Actions rapides',
                        icon: Icons.bolt,
                        children: [_buildQuickActions()],
                      ),
                      if (_stats != null)
                        CollapsibleSection(
                          title: 'Répartition par rôle',
                          icon: Icons.pie_chart,
                          children: [_buildRoleDistribution()],
                        ),
                      CollapsibleSection(
                        title: 'Aperçu financier',
                        icon: Icons.account_balance,
                        children: [_buildFinancialOverview()],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAdminProfile(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _roleColor(user.role).withValues(alpha: 0.15),
            NeonColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _roleColor(user.role).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AvatarDisplay(avatarType: user.avatarType, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username.isNotEmpty
                      ? user.username
                      : user.phone ?? 'Admin',
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? user.phone ?? '',
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: NeonColors.primary, size: 24),
        ],
      ),
    );
  }

  Widget _buildPlatformHealthAndAlerts() {
    final alertsState = ref.watch(adminAlertsProvider);
    final unreadAlerts = alertsState.unreadNotifications;

    // Calculer un score de santé simplifié
    final totalUsers = (_stats?['total_users'] as int?) ?? 0;
    final activeUsers = (_stats?['active_users'] as int?) ?? 0;
    final healthScore =
        totalUsers > 0 ? ((activeUsers / totalUsers) * 100).round() : 0;
    final healthColor = healthScore >= 80
        ? NeonColors.success
        : healthScore >= 50
            ? NeonColors.warning
            : NeonColors.error;

    return Row(
      children: [
        // Score santé plateforme
        Expanded(
          child: GestureDetector(
            onTap: () => context.go('/admin/monitoring'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: healthColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: healthColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, color: healthColor, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Santé Plateforme',
                        style: TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$healthScore%',
                    style: TextStyle(
                      color: healthColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: healthScore / 100,
                      backgroundColor: healthColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(healthColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Résumé alertes
        Expanded(
          child: GestureDetector(
            onTap: () => context.go('/admin/alerts'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    (unreadAlerts > 0 ? NeonColors.warning : NeonColors.success)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (unreadAlerts > 0
                          ? NeonColors.warning
                          : NeonColors.success)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        unreadAlerts > 0
                            ? Icons.warning_amber
                            : Icons.check_circle,
                        color: unreadAlerts > 0
                            ? NeonColors.warning
                            : NeonColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Alertes',
                        style: TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$unreadAlerts',
                    style: TextStyle(
                      color: unreadAlerts > 0
                          ? NeonColors.warning
                          : NeonColors.success,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unreadAlerts > 0 ? 'non traitées' : 'tout va bien',
                    style: const TextStyle(
                      color: NeonColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMetricsSection() {
    final metricsState = ref.watch(adminMetricsProvider);
    final alertsState = ref.watch(adminAlertsProvider);
    final dashboard = metricsState.dashboard ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AdminAlertBadge(
              count: alertsState.unreadNotifications,
              child: GestureDetector(
                onTap: () => context.go('/admin/alerts'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeonColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: NeonColors.error,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Alertes',
                        style: TextStyle(color: NeonColors.error, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdminResponsiveGrid(
          desktopColumns: 4,
          desktopRatio: 1.8,
          children: [
            AdminMetricCard(
              title: 'Revenus 24h',
              value:
                  AnalyticsFormat.amount(dashboard['total_revenue_24h'] ?? 0),
              icon: Icons.account_balance_wallet,
              color: NeonColors.success,
              deltaPercent: (dashboard['revenue_delta'] as num?)?.toDouble(),
            ),
            AdminMetricCard(
              title: 'Parties actives',
              value: '${dashboard['active_games'] ?? 0}',
              icon: Icons.videogame_asset,
              color: NeonColors.accent,
            ),
            AdminMetricCard(
              title: 'Utilisateurs connectés',
              value:
                  '${dashboard['active_users'] ?? dashboard['logged_in_users'] ?? 0}',
              icon: Icons.people,
              color: NeonColors.info,
            ),
            AdminMetricCard(
              title: 'Alertes actives',
              value:
                  '${dashboard['active_alerts'] ?? alertsState.unreadNotifications}',
              icon: Icons.warning_amber,
              color: NeonColors.warning,
            ),
          ],
        ),
        // Mini sparkline si données disponibles
        if (dashboard['timeseries'] != null &&
            (dashboard['timeseries'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          AdminSparkline(
            data: (dashboard['timeseries'] as List)
                .map((e) => (e is num ? e.toDouble() : 0.0))
                .toList(),
            color: NeonColors.primary,
            height: 40,
            width: double.infinity,
          ),
        ],
      ],
    );
  }

  Widget _buildStatsGrid() {
    final totalUsers = _stats?['total_users'] ?? 0;
    final activeUsers = _stats?['active_users'] ?? 0;
    final active24h = _stats?['active_24h'] ?? 0;
    final newUsers7d = _stats?['new_users_7d'] ?? 0;
    final activeSessions = _stats?['active_sessions'] ?? 0;
    final activeDevices = _stats?['active_devices'] ?? 0;
    final kycVerified = _stats?['kyc_verified'] ?? 0;
    final kycPending = _stats?['kyc_pending'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              icon: Icons.people,
              label: 'Total',
              value: totalUsers.toString(),
              color: NeonColors.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.check_circle,
              label: 'Actifs',
              value: activeUsers.toString(),
              color: NeonColors.adminCyan,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.today,
              label: '24h',
              value: active24h.toString(),
              color: NeonColors.paymentOrange,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.trending_up,
              label: '7j',
              value: newUsers7d.toString(),
              color: NeonColors.adminMagenta,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              icon: Icons.devices,
              label: 'Sessions',
              value: activeSessions.toString(),
              color: NeonColors.adminBlue,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.smartphone,
              label: 'Appareils',
              value: activeDevices.toString(),
              color: NeonColors.adminPurple,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.verified_user,
              label: 'KYC OK',
              value: kycVerified.toString(),
              color: NeonColors.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.hourglass_empty,
              label: 'KYC En attente',
              value: kycPending.toString(),
              color: NeonColors.adminAmber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityMetrics() {
    final audit24h = _stats?['audit_events_24h'] ?? 0;
    final selfExcluded = _stats?['self_excluded'] ?? 0;
    final inactiveUsers = _stats?['inactive_users'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricRow(
          'Événements audit (24h)',
          audit24h.toString(),
          NeonColors.adminPurple,
        ),
        _metricRow('Auto-exclus', selfExcluded.toString(), NeonColors.error),
        _metricRow(
          'Utilisateurs inactifs',
          inactiveUsers.toString(),
          NeonColors.adminAmber,
        ),
      ],
    );
  }

  Widget _buildFinancialOverview() {
    final totalBalance = _stats?['total_balance'] ?? '0';
    final totalTokenBalance = _stats?['total_token_balance'] ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricRow(
          'Solde total (wiga)',
          _formatMoney(totalBalance),
          NeonColors.primary,
        ),
        _metricRow(
          'Wiga en circulation',
          AnalyticsFormat.number(totalTokenBalance),
          NeonColors.adminCyan,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return AdminResponsiveGrid(
      desktopColumns: 4,
      desktopRatio: 1.5,
      children: [
        _QuickActionCard(
          icon: Icons.people,
          label: 'Utilisateurs',
          color: NeonColors.primary,
          onTap: () => context.go('/admin/users'),
        ),
        _QuickActionCard(
          icon: Icons.monitor_heart,
          label: 'Supervision',
          color: NeonColors.adminBlue,
          onTap: () => context.go('/admin/monitoring'),
        ),
        _QuickActionCard(
          icon: Icons.settings,
          label: 'Configuration',
          color: NeonColors.adminMagenta,
          onTap: () => context.go('/admin/config'),
        ),
        _QuickActionCard(
          icon: Icons.history,
          label: 'Logs d\'audit',
          color: NeonColors.adminPurple,
          onTap: () => context.go('/admin/audit'),
        ),
        _QuickActionCard(
          icon: Icons.monetization_on,
          label: 'Analytique\nRevenus',
          color: NeonColors.primary,
          onTap: () => context.go('/admin/analytics/revenue'),
        ),
        _QuickActionCard(
          icon: Icons.people_outline,
          label: 'Analytique\nJoueurs',
          color: NeonColors.accent,
          onTap: () => context.go('/admin/analytics/players'),
        ),
        _QuickActionCard(
          icon: Icons.swap_horiz,
          label: 'Flux\nMonétaire',
          color: NeonColors.warning,
          onTap: () => context.go('/admin/analytics/monetary-flow'),
        ),
        _QuickActionCard(
          icon: Icons.card_giftcard,
          label: 'Bonus et\nPromos',
          color: NeonColors.info,
          onTap: () => context.go('/admin/bonuses'),
        ),
      ],
    );
  }

  Widget _buildRoleDistribution() {
    final usersByRole = _stats?['users_by_role'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...UserRole.values.map((role) {
          final count = usersByRole[role.value] ?? 0;
          final total = (_stats?['total_users'] ?? 1) as int;
          final ratio = total > 0 ? count / total : 0.0;
          final color = Color(int.parse(role.color.replaceFirst('#', '0xFF')));

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    role.displayName,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(dynamic value) {
    final amount = int.tryParse(value.toString()) ?? 0;
    return '${(amount / 100).toStringAsFixed(0)} wiga';
  }

  Color _roleColor(UserRole role) {
    return Color(int.parse(role.color.replaceFirst('#', '0xFF')));
  }
}

// --- Widgets helpers ---

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

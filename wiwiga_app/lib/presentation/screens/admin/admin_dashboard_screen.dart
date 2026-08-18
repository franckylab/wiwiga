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
import '../../../data/models/user_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../presentation/widgets/auth/avatar_picker.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/admin/metric_card.dart';
import '../../widgets/admin/chart_widget.dart';
import '../../widgets/admin/alert_badge.dart';
import '../../../../core/theme/neon_theme.dart';

/// Dashboard d'administration principal
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
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
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement: $e';
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
        backgroundColor: const Color(0xFF0A0A1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text('Accès non autorisé', style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Retour à l\'accueil')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Administration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF88)),
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
                style: TextStyle(color: _roleColor(user.role), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: const Color(0xFF00FF88),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.white54)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadStats, child: const Text('Réessayer')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildAdminProfile(user),
                      const SizedBox(height: 20),
                      // Santé plateforme + Alertes résumé
                      _buildPlatformHealthAndAlerts(),
                      const SizedBox(height: 20),
                      // Section métriques temps réel avec KPI cards
                      _buildLiveMetricsSection(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildActivityMetrics(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      if (_stats != null) _buildRoleDistribution(),
                      const SizedBox(height: 20),
                      _buildFinancialOverview(),
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
            const Color(0xFF00FF88).withValues(alpha: 0.05),
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
                  user.username.isNotEmpty ? user.username : user.phone ?? 'Admin',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? user.phone ?? '',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: Color(0xFF00FF88), size: 24),
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
    final healthScore = totalUsers > 0 ? ((activeUsers / totalUsers) * 100).round() : 0;
    final healthColor = healthScore >= 80 ? NeonColors.success : healthScore >= 50 ? NeonColors.warning : NeonColors.error;

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
                      const Text('Santé Plateforme', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$healthScore%', style: TextStyle(color: healthColor, fontSize: 24, fontWeight: FontWeight.bold)),
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
                color: (unreadAlerts > 0 ? NeonColors.warning : NeonColors.success).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (unreadAlerts > 0 ? NeonColors.warning : NeonColors.success).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(unreadAlerts > 0 ? Icons.warning_amber : Icons.check_circle, color: unreadAlerts > 0 ? NeonColors.warning : NeonColors.success, size: 18),
                      const SizedBox(width: 6),
                      const Text('Alertes', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$unreadAlerts', style: TextStyle(color: unreadAlerts > 0 ? NeonColors.warning : NeonColors.success, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(unreadAlerts > 0 ? 'non traitées' : 'tout va bien', style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Métriques en direct',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            AdminAlertBadge(
              count: alertsState.unreadNotifications,
              child: GestureDetector(
                onTap: () => context.go('/admin/alerts'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active, color: Color(0xFFEF4444), size: 14),
                      SizedBox(width: 4),
                      Text('Alertes', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            AdminMetricCard(
              title: 'Revenus 24h',
              value: _formatCurrency(dashboard['total_revenue_24h'] ?? 0),
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF10B981),
              deltaPercent: (dashboard['revenue_delta'] as num?)?.toDouble(),
            ),
            AdminMetricCard(
              title: 'Parties actives',
              value: '${dashboard['active_games'] ?? 0}',
              icon: Icons.videogame_asset,
              color: const Color(0xFF00D9FF),
            ),
            AdminMetricCard(
              title: 'Users connectés',
              value: '${dashboard['active_users'] ?? dashboard['logged_in_users'] ?? 0}',
              icon: Icons.people,
              color: const Color(0xFF3B82F6),
            ),
            AdminMetricCard(
              title: 'Alertes actives',
              value: '${dashboard['active_alerts'] ?? alertsState.unreadNotifications}',
              icon: Icons.warning_amber,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        // Mini sparkline si données disponibles
        if (dashboard['timeseries'] != null && (dashboard['timeseries'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          AdminSparkline(
            data: (dashboard['timeseries'] as List).map((e) => (e is num ? e.toDouble() : 0.0)).toList(),
            color: const Color(0xFF00FF88),
            height: 40,
            width: double.infinity,
          ),
        ],
      ],
    );
  }

  String _formatCurrency(dynamic value) {
    final num amount = (value is num) ? value : double.tryParse(value.toString()) ?? 0;
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K FCFA';
    return '${amount.toStringAsFixed(0)} FCFA';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Utilisateurs',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(icon: Icons.people, label: 'Total', value: totalUsers.toString(), color: const Color(0xFF00FF88)),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.check_circle, label: 'Actifs', value: activeUsers.toString(), color: const Color(0xFF00FFFF)),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.today, label: '24h', value: active24h.toString(), color: const Color(0xFFFF6600)),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.trending_up, label: '7j', value: newUsers7d.toString(), color: const Color(0xFFFF00FF)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(icon: Icons.devices, label: 'Sessions', value: activeSessions.toString(), color: const Color(0xFF4488FF)),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.smartphone, label: 'Appareils', value: activeDevices.toString(), color: const Color(0xFFAA00FF)),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.verified_user, label: 'KYC OK', value: kycVerified.toString(), color: const Color(0xFF00FF88)),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.hourglass_empty, label: 'KYC Wait', value: kycPending.toString(), color: const Color(0xFFFFAA00)),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityMetrics() {
    final audit24h = _stats?['audit_events_24h'] ?? 0;
    final selfExcluded = _stats?['self_excluded'] ?? 0;
    final inactiveUsers = _stats?['inactive_users'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activité & Sécurité',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _metricRow('Événements audit (24h)', audit24h.toString(), const Color(0xFFAA00FF)),
          _metricRow('Auto-exclus', selfExcluded.toString(), const Color(0xFFFF4444)),
          _metricRow('Utilisateurs inactifs', inactiveUsers.toString(), const Color(0xFFFFAA00)),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview() {
    final totalBalance = _stats?['total_balance'] ?? '0';
    final totalTokenBalance = _stats?['total_token_balance'] ?? '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aperçu financier',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _metricRow('Solde total (FCFA)', _formatMoney(totalBalance), const Color(0xFF00FF88)),
          _metricRow('Jetons en circulation', _formatNumber(totalTokenBalance), const Color(0xFF00FFFF)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _QuickActionCard(
              icon: Icons.people, label: 'Utilisateurs', color: const Color(0xFF00FF88),
              onTap: () => context.go('/admin/users'),
            ),
            _QuickActionCard(
              icon: Icons.monitor_heart, label: 'Supervision\nSystème', color: const Color(0xFF4488FF),
              onTap: () => context.go('/admin/monitoring'),
            ),
            _QuickActionCard(
              icon: Icons.settings, label: 'Configuration', color: const Color(0xFFFF00FF),
              onTap: () => context.go('/admin/config'),
            ),
            _QuickActionCard(
              icon: Icons.history, label: 'Logs d\'audit', color: const Color(0xFFAA00FF),
              onTap: () => context.go('/admin/audit'),
            ),
            _QuickActionCard(
              icon: Icons.monetization_on, label: 'Revenue\nAnalytics', color: const Color(0xFF2DD4BF),
              onTap: () => context.go('/admin/analytics/revenue'),
            ),
            _QuickActionCard(
              icon: Icons.people_outline, label: 'Player\nAnalytics', color: const Color(0xFF00D9FF),
              onTap: () => context.go('/admin/analytics/players'),
            ),
            _QuickActionCard(
              icon: Icons.swap_horiz, label: 'Flux\nMonétaire', color: const Color(0xFFF59E0B),
              onTap: () => context.go('/admin/analytics/monetary-flow'),
            ),
            _QuickActionCard(
              icon: Icons.card_giftcard, label: 'Bonus &\nPromos', color: const Color(0xFF3B82F6),
              onTap: () => context.go('/admin/bonuses'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleDistribution() {
    final usersByRole = _stats?['users_by_role'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Répartition par rôle',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
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
                  child: Text(role.displayName, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
                Text(count.toString(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
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
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }


  String _formatMoney(dynamic value) {
    final amount = int.tryParse(value.toString()) ?? 0;
    return '${(amount / 100).toStringAsFixed(0)} FCFA';
  }

  String _formatNumber(dynamic value) {
    final num = int.tryParse(value.toString()) ?? 0;
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
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

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

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
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
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

  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

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
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

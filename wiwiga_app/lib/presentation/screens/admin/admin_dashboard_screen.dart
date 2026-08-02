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
                color: _roleColor(user.role).withOpacity(0.2),
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
            _roleColor(user.role).withOpacity(0.15),
            const Color(0xFF00FF88).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _roleColor(user.role).withOpacity(0.3)),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: Color(0xFF00FF88), size: 24),
        ],
      ),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
        color: const Color(0xFF00FF88).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.15)),
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
              icon: Icons.bar_chart, label: 'Statistiques\ndétaillées', color: const Color(0xFF00FFFF),
              onTap: () => _showStatsDialog(),
            ),
            _QuickActionCard(
              icon: Icons.admin_panel_settings, label: 'Rôles &\nPermissions', color: const Color(0xFFFF6600),
              onTap: () => _showRolesDialog(),
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
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(count.toString(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showRolesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Rôles & Permissions', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
              final color = Color(int.parse(role.color.replaceFirst('#', '0xFF')));
              return ListTile(
                leading: Icon(Icons.shield, color: color),
                title: Text(role.displayName, style: TextStyle(color: color)),
                subtitle: Text(_roleDescription(role), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer', style: TextStyle(color: Color(0xFF00FF88)))),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Statistiques complètes', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statsRow('Total utilisateurs', (_stats?['total_users'] ?? 0).toString()),
                _statsRow('Utilisateurs actifs', (_stats?['active_users'] ?? 0).toString()),
                _statsRow('Actifs 24h', (_stats?['active_24h'] ?? 0).toString()),
                _statsRow('Nouveaux (7j)', (_stats?['new_users_7d'] ?? 0).toString()),
                _statsRow('Sessions actives', (_stats?['active_sessions'] ?? 0).toString()),
                _statsRow('Appareils actifs', (_stats?['active_devices'] ?? 0).toString()),
                _statsRow('KYC vérifiés', (_stats?['kyc_verified'] ?? 0).toString()),
                _statsRow('KYC en attente', (_stats?['kyc_pending'] ?? 0).toString()),
                _statsRow('Auto-exclus', (_stats?['self_excluded'] ?? 0).toString()),
                _statsRow('Inactifs', (_stats?['inactive_users'] ?? 0).toString()),
                _statsRow('Événements audit 24h', (_stats?['audit_events_24h'] ?? 0).toString()),
                _statsRow('Solde total (FCFA)', _formatMoney(_stats?['total_balance'] ?? '0')),
                _statsRow('Jetons en circulation', _formatNumber(_stats?['total_token_balance'] ?? '0')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer', style: TextStyle(color: Color(0xFF00FF88)))),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _statsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold)),
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

  String _roleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return 'Accès total: tout gérer';
      case UserRole.admin: return 'Gérer users, config, modération';
      case UserRole.moderator: return 'Modération: ban, mute, signalements';
      case UserRole.test: return 'Accès fonctionnalités de test';
      case UserRole.user: return 'Accès standard: jouer, transactions';
    }
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

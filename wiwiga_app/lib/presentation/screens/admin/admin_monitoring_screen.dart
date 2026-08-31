// ============================================================
// Fichier: admin_monitoring_screen.dart
// Description: Écran de supervision système WIWIGA
//              Monitoring temps réel (DB, Redis, BEAM, mémoire)
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/error_handler.dart';
import '../../../data/providers/app_providers.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran de supervision système pour les administrateurs
/// Affiche l'état de santé du backend en temps réel
class AdminMonitoringScreen extends ConsumerStatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  ConsumerState<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends ConsumerState<AdminMonitoringScreen> {
  Map<String, dynamic>? _health;
  bool _isLoading = true;
  String? _error;
  bool _autoRefresh = true;
  Timer? _refreshTimer;
  int _refreshInterval = 30; // secondes (augmenté de 10→30 pour éviter Violation setTimeout 173ms)
  final List<int> _intervalOptions = [10, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    _loadHealth();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: _refreshInterval), (_) {
      if (_autoRefresh && mounted) {
        _loadHealth();
      }
    });
  }

  Future<void> _loadHealth() async {
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final health = await adminRepo.getSystemHealth();
      if (mounted) {
        setState(() {
          _health = health;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMonitoring._loadHealth');
      if (mounted) {
        setState(() {
          _error = ErrorHandler.userMessage(e);
          _isLoading = false;
        });
      }
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
              const Text('Accès non autorisé', style: TextStyle(color: NeonColors.textPrimary, fontSize: 20)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Retour')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeonColors.textPrimary),
          onPressed: () => context.go('/admin'),
        ),
        title: const Text(
          'Supervision',
          style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Sélecteur d'intervalle de refresh
          PopupMenuButton<int>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: NeonColors.textMuted, size: 16),
                const SizedBox(width: 4),
                Text('${_refreshInterval}s', style: const TextStyle(color: NeonColors.textMuted, fontSize: 12)),
              ],
            ),
            onSelected: (interval) {
              setState(() => _refreshInterval = interval);
              _startAutoRefresh();
            },
            itemBuilder: (context) => _intervalOptions.map((i) => PopupMenuItem(
              value: i,
              child: Text('${i}s', style: TextStyle(
                color: _refreshInterval == i ? NeonColors.primary : NeonColors.textPrimary,
                fontWeight: _refreshInterval == i ? FontWeight.bold : FontWeight.normal,
              ),),
            ),).toList(),
          ),
          IconButton(
            icon: Icon(_autoRefresh ? Icons.sync : Icons.sync_disabled, color: _autoRefresh ? NeonColors.primary : NeonColors.textMuted),
            onPressed: () => setState(() => _autoRefresh = !_autoRefresh),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: NeonColors.primary),
            onPressed: _loadHealth,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHealth,
        color: NeonColors.primary,
        child: _isLoading
            ? const NeonLoadingSpinner.center()
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: NeonColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: NeonColors.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadHealth, child: const Text('Réessayer')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildOverallStatus(),
                      const SizedBox(height: 16),
                      _buildDatabaseHealth(),
                      const SizedBox(height: 12),
                      _buildRedisHealth(),
                      const SizedBox(height: 12),
                      _buildMemoryHealth(),
                      const SizedBox(height: 12),
                      _buildProcessHealth(),
                      const SizedBox(height: 12),
                      _buildSystemInfo(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildOverallStatus() {
    final dbStatus = _health?['database']?['status'] ?? 'unknown';
    final redisStatus = _health?['redis']?['status'] ?? 'unknown';
    final allHealthy = dbStatus == 'healthy' && redisStatus == 'healthy';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allHealthy
              ? [NeonColors.primary.withValues(alpha: 0.15), const Color(0xFF00FFFF).withValues(alpha: 0.05)]
              : [NeonColors.error.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: allHealthy ? NeonColors.primary.withValues(alpha: 0.3) : NeonColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            allHealthy ? Icons.check_circle : Icons.warning,
            color: allHealthy ? NeonColors.primary : NeonColors.error,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allHealthy ? 'Système opérationnel' : 'Alerte système',
                  style: TextStyle(
                    color: allHealthy ? NeonColors.primary : NeonColors.error,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dernière vérification: ${_formatTimestamp(_health?['timestamp'])}',
                  style: const TextStyle(color: NeonColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseHealth() {
    final db = _health?['database'] ?? {};
    final status = db['status'] ?? 'unknown';
    final latency = (db['latency_ms'] as num?)?.toStringAsFixed(1) ?? '?';
    final isHealthy = status == 'healthy';

    return _HealthCard(
      title: 'Base de données',
      icon: Icons.storage,
      status: status,
      isHealthy: isHealthy,
      children: [
        _healthMetric('Statut', status, isHealthy ? NeonColors.primary : NeonColors.error),
        _healthMetric('Latence', '$latency ms', _latencyColor(double.tryParse(latency) ?? 999)),
      ],
    );
  }

  Widget _buildRedisHealth() {
    final redis = _health?['redis'] ?? {};
    final status = redis['status'] ?? 'unknown';
    final latency = (redis['latency_ms'] as num?)?.toStringAsFixed(1) ?? '?';
    final keys = _health?['redis_keys'] ?? 0;
    final isHealthy = status == 'healthy';

    return _HealthCard(
      title: 'Redis (Cache)',
      icon: Icons.memory,
      status: status,
      isHealthy: isHealthy,
      children: [
        _healthMetric('Statut', status, isHealthy ? NeonColors.primary : NeonColors.error),
        _healthMetric('Latence', '$latency ms', _latencyColor(double.tryParse(latency) ?? 999)),
        _healthMetric('Clés actives', keys.toString(), const Color(0xFF00FFFF)),
      ],
    );
  }

  Widget _buildMemoryHealth() {
    final memory = _health?['memory'] ?? {};
    final totalMb = (memory['total_mb'] as num?)?.toStringAsFixed(1) ?? '?';
    final processesMb = (memory['processes_mb'] as num?)?.toStringAsFixed(1) ?? '?';
    final systemMb = (memory['system_mb'] as num?)?.toStringAsFixed(1) ?? '?';
    final atomMb = (memory['atom_mb'] as num?)?.toStringAsFixed(1) ?? '?';
    final binaryMb = (memory['binary_mb'] as num?)?.toStringAsFixed(1) ?? '?';

    return _HealthCard(
      title: 'Mémoire BEAM (Erlang VM)',
      icon: Icons.sd_storage,
      status: 'active',
      isHealthy: true,
      children: [
        _healthMetric('Total', '$totalMb MB', NeonColors.primary),
        _healthMetric('Processus', '$processesMb MB', const Color(0xFF00FFFF)),
        _healthMetric('Système', '$systemMb MB', const Color(0xFF4488FF)),
        _healthMetric('Atomes', '$atomMb MB', const Color(0xFFAA00FF)),
        _healthMetric('Binaire', '$binaryMb MB', const Color(0xFFFF00FF)),
      ],
    );
  }

  Widget _buildProcessHealth() {
    final processes = _health?['processes'] ?? {};
    final count = processes['count'] ?? 0;
    final limit = processes['limit'] ?? 0;
    final usagePercent = (processes['usage_percent'] as num?)?.toStringAsFixed(2) ?? '?';
    final sessions = _health?['active_sessions'] ?? 0;

    return _HealthCard(
      title: 'Processus & Sessions',
      icon: Icons.hub,
      status: 'active',
      isHealthy: true,
      children: [
        _healthMetric('Processus BEAM', '$count / $limit', NeonColors.primary),
        _healthMetric('Utilisation', '$usagePercent%', const Color(0xFF00FFFF)),
        _healthMetric('Sessions actives', sessions.toString(), const Color(0xFFFF6600)),
      ],
    );
  }

  Widget _buildSystemInfo() {
    final erlangVersion = _health?['erlang_version'] ?? '?';
    final systemVersion = _health?['system_version'] ?? '?';
    final uptimeHours = (_health?['uptime_hours'] as num?)?.toStringAsFixed(1) ?? '?';

    return _HealthCard(
      title: 'Informations système',
      icon: Icons.info_outline,
      status: 'running',
      isHealthy: true,
      children: [
        _healthMetric('Erlang/OTP', 'v$erlangVersion', NeonColors.primary),
        _healthMetric('Système (kernel)', 'v$systemVersion', const Color(0xFF00FFFF)),
        _healthMetric('Uptime', '$uptimeHours heures', const Color(0xFFFF6600)),
      ],
    );
  }

  Widget _healthMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Color _latencyColor(double latencyMs) {
    if (latencyMs < 5) return NeonColors.primary;
    if (latencyMs < 20) return const Color(0xFFFFAA00);
    return NeonColors.error;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp.toString());
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp.toString();
    }
  }
}

/// Carte de santé d'un composant
class _HealthCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String status;
  final bool isHealthy;
  final List<Widget> children;

  const _HealthCard({
    required this.title,
    required this.icon,
    required this.status,
    required this.isHealthy,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHealthy ? NeonColors.primary.withValues(alpha: 0.2) : NeonColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isHealthy ? NeonColors.primary : NeonColors.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isHealthy ? NeonColors.primary : NeonColors.error).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: isHealthy ? NeonColors.primary : NeonColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

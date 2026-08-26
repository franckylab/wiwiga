// ============================================================
// Fichier: admin_audit_screen.dart
// Description: Logs d'audit admin - Connecté à l'API réelle
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/app_providers.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran des logs d'audit admin (données réelles API)
class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  List<Map<String, dynamic>> _logs = [];
  int _total = 0;
  int _page = 1;
  bool _isLoading = true;
  String? _error;
  String _filterAction = '';

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final result = await adminRepo.getAuditLogs(
        page: _page,
        limit: _pageSize,
        action: _filterAction.isNotEmpty ? _filterAction : null,
      );

      if (mounted) {
        setState(() {
          _logs = (result['logs'] as List)
              .map((l) => l as Map<String, dynamic>)
              .toList();
          _total = result['total'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de chargement: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null || !user.isModerator) {
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
        title: const Text('Logs d\'audit', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$_total événements', style: const TextStyle(color: NeonColors.textMuted, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'Tout', isSelected: _filterAction == '', onTap: () { _filterAction = ''; _loadLogs(); }, color: NeonColors.primary),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Auth', isSelected: _filterAction == 'password_login', onTap: () { _filterAction = 'password_login'; _loadLogs(); }, color: const Color(0xFF00FFFF)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Admin', isSelected: _filterAction == 'admin_action', onTap: () { _filterAction = 'admin_action'; _loadLogs(); }, color: const Color(0xFFFF6600)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'OTP', isSelected: _filterAction == 'otp_verified', onTap: () { _filterAction = 'otp_verified'; _loadLogs(); }, color: const Color(0xFFFF00FF)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Échecs', isSelected: _filterAction == 'password_login_failed', onTap: () { _filterAction = 'password_login_failed'; _loadLogs(); }, color: NeonColors.error),
                ],
              ),
            ),
          ),

          // Liste
          Expanded(
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
                            ElevatedButton(onPressed: _loadLogs, child: const Text('Réessayer')),
                          ],
                        ),
                      )
                    : _logs.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox, color: NeonColors.textMuted, size: 64),
                                SizedBox(height: 12),
                                Text('Aucun log d\'audit', style: TextStyle(color: NeonColors.textMuted)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            color: NeonColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _logs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _AuditLogTile(log: log);
                              },
                            ),
                          ),
          ),

          // Pagination
          if (_total > _pageSize)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: NeonColors.primary),
                    onPressed: _page > 1
                        ? () { _page--; _loadLogs(); }
                        : null,
                  ),
                  Text(
                    'Page $_page / ${(_total / _pageSize).ceil()}',
                    style: const TextStyle(color: NeonColors.textSecondary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: NeonColors.primary),
                    onPressed: _page * _pageSize < _total
                        ? () { _page++; _loadLogs(); }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tuile de log d'audit réel
class _AuditLogTile extends StatelessWidget {
  final Map<String, dynamic> log;

  const _AuditLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action'] as String? ?? 'unknown';
    final entityType = log['entity_type'] as String? ?? '';
    final userId = log['user_id'];
    final insertedAt = log['inserted_at'] as String? ?? '';
    final changes = log['changes'] as Map<String, dynamic>? ?? {};
    final ipAddress = log['ip_address'] as String?;

    final color = _actionColor(action);
    final icon = _actionIcon(action);
    final timeStr = _formatTime(insertedAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _actionLabel(action),
                        style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(entityType, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (changes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    changes.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                    style: const TextStyle(color: NeonColors.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (userId != null) ...[
                      const Icon(Icons.person_outline, color: NeonColors.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Text('User #$userId', style: const TextStyle(color: NeonColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 12),
                    ],
                    if (ipAddress != null) ...[
                      const Icon(Icons.language, color: NeonColors.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Text(ipAddress, style: const TextStyle(color: NeonColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.access_time, color: NeonColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(timeStr, style: const TextStyle(color: NeonColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.contains('login') || action.contains('otp') || action.contains('register')) return const Color(0xFF00FFFF);
    if (action.contains('admin') || action.contains('role')) return const Color(0xFFFF6600);
    if (action.contains('fail') || action.contains('error')) return NeonColors.error;
    if (action.contains('deposit') || action.contains('withdraw') || action.contains('transfer')) return NeonColors.primary;
    return const Color(0xFFAA00FF);
  }

  IconData _actionIcon(String action) {
    if (action.contains('login')) return Icons.login;
    if (action.contains('otp')) return Icons.security;
    if (action.contains('register')) return Icons.person_add;
    if (action.contains('admin')) return Icons.admin_panel_settings;
    if (action.contains('role')) return Icons.shield;
    if (action.contains('deposit')) return Icons.account_balance_wallet;
    if (action.contains('withdraw')) return Icons.money_off;
    if (action.contains('transfer')) return Icons.swap_horiz;
    if (action.contains('fail') || action.contains('error')) return Icons.error;
    return Icons.info;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'password_login': return 'Connexion (mot de passe)';
      case 'password_login_failed': return 'Échec connexion';
      case 'otp_sent': return 'OTP envoyé';
      case 'otp_verified': return 'OTP vérifié';
      case 'admin_action': return 'Action admin';
      case 'user_registered': return 'Inscription';
      case 'role_changed': return 'Rôle modifié';
      case 'user_activated': return 'Utilisateur activé/désactivé';
      case 'deposit': return 'Dépôt';
      case 'withdrawal': return 'Retrait';
      default: return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt.toLocal());
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}

/// Chip de filtre
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : NeonColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : NeonColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : NeonColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

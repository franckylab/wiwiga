// ============================================================
// Fichier: admin_alerts_screen.dart
// Description: Écran alertes admin avec filtrage par sévérité
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/admin/alert_badge.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran des alertes admin
class AdminAlertsScreen extends ConsumerStatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  ConsumerState<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends ConsumerState<AdminAlertsScreen> {
  String? _severityFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminAlertsProvider.notifier).loadNotifications();
      ref.read(adminAlertsProvider.notifier).loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAlertsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Alertes & Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminAlertsProvider.notifier).loadNotifications(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres sévérité
          _buildSeverityFilter(),
          // Contenu
          Expanded(
            child: state.isLoading
                ? const NeonLoadingSpinner.center()
                : RefreshIndicator(
                    color: NeonColors.primary,
                    onRefresh: () => ref.read(adminAlertsProvider.notifier).loadNotifications(),
                    child: state.alerts.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: const AdminEmptyState(icon: Icons.notifications_none, title: 'Aucune alerte')),
                          )
                        : _buildAlertList(state),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NeonColors.surface,
      child: Row(
        children: [
          _filterChip(null, 'Toutes'),
          const SizedBox(width: 8),
          _filterChip('critical', 'Critique'),
          const SizedBox(width: 8),
          _filterChip('warning', 'Attention'),
          const SizedBox(width: 8),
          _filterChip('info', 'Info'),
        ],
      ),
    );
  }

  Widget _filterChip(String? value, String label) {
    final isSelected = _severityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: (value == 'critical' ? NeonColors.error : value == 'warning' ? NeonColors.warning : NeonColors.primary).withValues(alpha: 0.2),
      backgroundColor: NeonColors.card,
      labelStyle: TextStyle(
        color: isSelected ? NeonColors.textPrimary : NeonColors.textSecondary,
        fontSize: 11,
      ),
      side: BorderSide(color: isSelected ? NeonColors.primary : NeonColors.border),
      onSelected: (selected) {
        setState(() => _severityFilter = selected ? value : null);
        ref.read(adminAlertsProvider.notifier).loadNotifications(type: value);
      },
    );
  }

  Widget _buildAlertList(AdminAlertsState state) {
    final filteredAlerts = _severityFilter == null
        ? state.alerts
        : state.alerts.where((a) => a['severity'] == _severityFilter).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAlerts.length,
      itemBuilder: (context, index) {
        final alert = filteredAlerts[index] as Map<String, dynamic>;
        return AdminAlertTile(
          title: alert['title'] ?? 'Alerte',
          message: alert['message'] ?? '',
          severity: alert['severity'] ?? 'info',
          timestamp: alert['inserted_at'] != null
              ? DateTime.tryParse(alert['inserted_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
          isResolved: alert['is_resolved'] == true,
          onResolve: alert['is_resolved'] == true
              ? null
              : () async {
                  final alertId = alert['id']?.toString() ?? '';
                  if (alertId.isEmpty) return;
                  try {
                    await ref.read(adminRepositoryProvider).resolveAlert(alertId);
                    if (!context.mounted) return;
                    context.showSuccess('Alerte résolue');
                    ref.read(adminAlertsProvider.notifier).loadNotifications();
                    ref.read(adminAlertsProvider.notifier).loadUnreadCount();
                  } catch (e, st) {
                    ErrorHandler.logError(e, st, context: 'AdminAlerts.resolve');
                    if (!context.mounted) return;
                    WiwigaSnack.showError(context, e);
                  }
                },
        );
      },
    );
  }
}

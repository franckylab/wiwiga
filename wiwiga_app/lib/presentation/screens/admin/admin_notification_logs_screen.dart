// ============================================================
// Fichier: admin_notification_logs_screen.dart
// Description: Admin logs, stats et replay des notifications
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/chart_widget.dart';
import '../../widgets/admin/metric_card.dart';
import '../../widgets/admin/skeleton_loader.dart';
import '../../widgets/admin/analytics_helpers.dart';

/// Écran admin des logs de notification
class AdminNotificationLogsScreen extends ConsumerStatefulWidget {
  const AdminNotificationLogsScreen({super.key});

  @override
  ConsumerState<AdminNotificationLogsScreen> createState() =>
      _AdminNotificationLogsScreenState();
}

class _AdminNotificationLogsScreenState
    extends ConsumerState<AdminNotificationLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _timeseries = [];
  bool _isLoading = true;
  String? _statusFilter;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Recherche serveur debouncée dans titre + corps.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = value.trim());
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final results = await Future.wait([
        repo.getNotificationLogs(status: _statusFilter, query: _query.isEmpty ? null : _query),
        repo.getNotificationStats(),
        repo.getNotificationTimeseries(days: 14),
      ]);
      _logs = ((results[0] as Map)['logs'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      _stats = results[1] as Map<String, dynamic>;
      _timeseries = (results[2] as List<Map<String, dynamic>>?) ?? [];
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminNotifLogs.load');
      if (mounted) WiwigaSnack.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Logs Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exporter CSV (max 5000)',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Diffuser à tous',
            onPressed: _showBroadcastDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          _buildStats(),
          _buildTrend(),
          _buildSearch(),
          _buildStatusFilter(),
          Expanded(
            child: _isLoading
                ? const AdminSkeletonList(itemCount: 6)
                : RefreshIndicator(
                    color: NeonColors.primary,
                    onRefresh: _load,
                    child: _logs.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: const AdminEmptyState(
                                icon: Icons.mark_email_read_outlined,
                                title: 'Aucun envoi',
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) => _buildLogCard(_logs[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final byStatus = (_stats['by_status'] as Map?)?.map((k, v) => MapEntry('$k', (v as num).toInt())) ?? {};
    final sent = byStatus['sent'] ?? 0;
    final failed = byStatus['failed'] ?? 0;
    final queued = (byStatus['queued'] ?? 0) + (byStatus['retrying'] ?? 0);
    final unread = (_stats['unread_total'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final cards = [
            _StatData('Envoyées', '$sent', NeonColors.success, Icons.check_circle_outline),
            _StatData('Échouées', '$failed', NeonColors.error, Icons.error_outline),
            _StatData('En attente', '$queued', NeonColors.warning, Icons.hourglass_empty),
            _StatData('Non lues', '$unread', NeonColors.accent, Icons.markunread_outlined),
          ];
          if (wide) {
            return Row(
              children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _statCard(c)))).toList(),
            );
          }
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: cards.map(_statCard).toList(),
          );
        },
      ),
    );
  }

  Widget _statCard(_StatData data) {
    return AdminMetricCard(
      title: data.label,
      value: data.value,
      icon: data.icon,
      color: data.color,
    );
  }

  /// Tendance 14 jours : envoyées (ligne) + échouées (barres).
  Widget _buildTrend() {
    if (_timeseries.isEmpty) return const SizedBox.shrink();

    final sent = _timeseries.map((d) => ((d['sent'] as num?)?.toDouble() ?? 0.0)).toList();
    final failed = _timeseries.map((d) => ((d['failed'] as num?)?.toDouble() ?? 0.0)).toList();
    final labels = _timeseries.map((d) {
      final date = (d['date'] as String?) ?? '';
      return date.length >= 10 ? date.substring(5) : date;
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Envois — 14 derniers jours',
            style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          AdminLineChart(
            data: sent,
            lineColor: NeonColors.success,
            label: 'Envoyées',
            height: 110,
            showDots: false,
            xLabels: labels,
          ),
          if (failed.any((v) => v > 0)) ...[
            const SizedBox(height: 8),
            AdminBarChart(
              data: failed,
              barColor: NeonColors.error,
              label: 'Échouées',
              height: 80,
              labels: labels,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearch() {    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: NeonColors.surface,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Rechercher (titre, corps)…',
          hintStyle: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: NeonColors.textSecondary, size: 18),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, color: NeonColors.textSecondary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
          filled: true,
          fillColor: NeonColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: NeonColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: NeonColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: NeonColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    const statuses = [null, 'sent', 'queued', 'failed', 'delivered'];
    const labels = ['Tous', 'Envoyées', 'En attente', 'Échouées', 'Livrées'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NeonColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(statuses.length, (i) {
            final selected = _statusFilter == statuses[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: selected,
                selectedColor: NeonColors.primary.withValues(alpha: 0.2),
                backgroundColor: NeonColors.card,
                labelStyle: TextStyle(
                  color: selected ? NeonColors.textPrimary : NeonColors.textSecondary,
                  fontSize: 11,
                ),
                side: BorderSide(color: selected ? NeonColors.primary : NeonColors.border),
                onSelected: (_) {
                  setState(() => _statusFilter = statuses[i]);
                  _load();
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final status = log['status'] as String? ?? 'queued';
    final statusColor = status == 'sent' || status == 'delivered'
        ? NeonColors.success
        : status == 'failed'
            ? NeonColors.error
            : NeonColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${log['title'] ?? log['event_type'] ?? 'Notification'}',
                  style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${log['body'] ?? ''}',
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'user #${log['user_id']} • ${log['event_type']} • ${AnalyticsFormat.relativeTime(log['inserted_at'], emptyLabel: '')}',
            style: const TextStyle(color: NeonColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Détail', style: TextStyle(fontSize: 12)),
                onPressed: () => _showDetailDialog((log['id'] as num).toInt()),
              ),
              TextButton.icon(
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Rejouer', style: TextStyle(fontSize: 12)),
                onPressed: () => _replay((log['id'] as num).toInt()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Export CSV des logs (filtre statut courant, max 5000 lignes).
  Future<void> _exportCsv() async {
    try {
      final result = await ref.read(adminRepositoryProvider).exportNotificationLogsCsv(
            status: _statusFilter,
          );
      final saved = await downloadTextFile(result.filename, result.csv);
      if (mounted) context.showSuccess('Export enregistré : $saved');
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminNotifLogs.export');
      if (mounted) WiwigaSnack.showError(context, e);
    }
  }

  Future<void> _replay(int id) async {    try {
      await ref.read(adminRepositoryProvider).replayNotification(id);
      if (mounted) context.showSuccess('Notification rejouée');
      _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminNotifLogs.replay');
      if (mounted) WiwigaSnack.showError(context, e);
    }
  }

  /// Diffusion à tous les utilisateurs actifs (lots async, idempotent).
  /// Catégorie + envoi planifié optionnel (heures creuses auto en marketing).
  void _showBroadcastDialog() {
    final titleController = TextEditingController(text: 'Annonce');
    final messageController = TextEditingController();
    String category = 'transactional';
    DateTime? scheduledAt;

    String scheduleLabel() {
      if (scheduledAt == null) return 'Immédiat';
      final local = scheduledAt!.toLocal();
      final date =
          '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      return 'Planifié : $date';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.card,
          title: const Text('Diffuser à tous', style: TextStyle(color: NeonColors.textPrimary, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Visible dans l\u2019inbox de chaque joueur',
                  ),
                  maxLines: 4,
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: NeonColors.surface,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: const [
                    DropdownMenuItem(value: 'transactional', child: Text('Annonce')),
                    DropdownMenuItem(value: 'marketing', child: Text('Promotion (opt-out + heures creuses)')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? 'transactional'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scheduleLabel(),
                        style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: Text(scheduledAt == null ? 'Planifier' : 'Modifier', style: const TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: scheduledAt ?? now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 30)),
                        );
                        if (date == null) return;
                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(scheduledAt ?? now),
                        );
                        if (time == null) return;
                        setDialogState(() {
                          scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      },
                    ),
                    if (scheduledAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        tooltip: 'Envoi immédiat',
                        onPressed: () => setDialogState(() => scheduledAt = null),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Envoi par lots de 500 (file async), sans doublon.',
                  style: TextStyle(color: NeonColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                if (messageController.text.trim().isEmpty) return;
                try {
                  await ref.read(adminRepositoryProvider).broadcastToAllUsers(
                        titleController.text.trim().isEmpty ? 'Annonce' : titleController.text.trim(),
                        messageController.text.trim(),
                        category: category,
                        scheduledAt: scheduledAt,
                      );
                  if (mounted) {
                    context.showSuccess(scheduledAt == null ? 'Diffusion planifiée' : 'Diffusion programmée');
                  }
                  _load();
                } catch (e, st) {
                  ErrorHandler.logError(e, st, context: 'AdminNotifLogs.broadcast');
                  if (mounted) WiwigaSnack.showError(context, e);
                }
              },
              child: const Text('Diffuser'),
            ),
          ],
        ),
      ),
    );
  }

  /// Détail : notification + timeline des tentatives par canal.
  Future<void> _showDetailDialog(int id) async {
    Map<String, dynamic>? detail;
    String? error;
    try {
      detail = await ref.read(adminRepositoryProvider).getNotificationLog(id);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminNotifLogs.detail');
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;

    final notification = detail?['notification'] as Map<String, dynamic>?;
    final deliveries = ((detail?['deliveries'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: Text(
          '${notification?['title'] ?? 'Notification #$id'}',
          style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null)
                  Text(error, style: const TextStyle(color: NeonColors.error, fontSize: 12))
                else ...[
                  Text('${notification?['body'] ?? ''}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'user #${notification?['user_id']} • ${notification?['event_type']} • ${notification?['status']}',
                    style: const TextStyle(color: NeonColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tentatives', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (deliveries.isEmpty)
                    const Text('Aucune tentative.', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                  ...deliveries.map((d) {
                    final status = d['status'] as String? ?? 'queued';
                    final color = status == 'sent' || status == 'delivered'
                        ? NeonColors.success
                        : status == 'failed'
                            ? NeonColors.error
                            : NeonColors.warning;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${d['channel']} • ${d['provider_name'] ?? '—'} • essai ${d['attempt_number'] ?? 1} • $status',
                                  style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12),
                                ),
                                if (d['provider_message_id'] != null)
                                  Text('ID provider : ${d['provider_message_id']}', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                                if (d['error_message'] != null)
                                  Text(
                                    '${d['error_message']}',
                                    style: const TextStyle(color: NeonColors.error, fontSize: 11),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatData(this.label, this.value, this.color, this.icon);
}

// ============================================================
// Fichier: admin_reports_screen.dart
// Description: Écran gestion des rapports (generation, téléchargement)
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../../../data/providers/app_providers.dart';
import '../../providers/admin_management_provider.dart';

/// Écran gestion des rapports
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminReportsManagementProvider.notifier).loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReportsManagementProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Rapports'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            onPressed: () => _showGenerateDialog(),
            tooltip: 'Générer un rapport',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: NeonColors.primary))
          : state.error != null
              ? _buildError(state.error!)
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminReportsState state) {
    final reports = state.reports;

    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assessment, color: NeonColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text('Aucun rapport généré', style: TextStyle(color: NeonColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showGenerateDialog(),
              icon: const Icon(Icons.add_chart),
              label: const Text('Générer un rapport'),
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminReportsManagementProvider.notifier).loadReports(),
      color: NeonColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index] as Map<String, dynamic>;
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final name = report['name'] as String? ?? '';
    final type = report['type'] as String? ?? '';
    final status = report['status'] as String? ?? '';
    final insertedAt = report['inserted_at'] as String?;
    final rowCount = report['row_count'] as int? ?? 0;
    final fileSize = report['file_size'] as int? ?? 0;
    final id = report['id']?.toString() ?? '';

    final typeIcons = {
      'financial': Icons.account_balance,
      'players': Icons.people,
      'games': Icons.sports_esports,
      'compliance': Icons.verified_user,
      'bonuses': Icons.card_giftcard,
    };
    final typeColors = {
      'financial': NeonColors.success,
      'players': NeonColors.primary,
      'games': NeonColors.secondary,
      'compliance': NeonColors.info,
      'bonuses': NeonColors.accent,
    };
    final icon = typeIcons[type] ?? Icons.description;
    final color = typeColors[type] ?? NeonColors.textSecondary;

    final statusColors = {
      'completed': NeonColors.success,
      'pending': NeonColors.secondary,
      'failed': NeonColors.error,
      'processing': NeonColors.info,
    };
    final statusColor = statusColors[status] ?? NeonColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Text(type, style: const TextStyle(color: NeonColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              if (status == 'completed')
                IconButton(
                  icon: const Icon(Icons.download, color: NeonColors.primary),
                  onPressed: () {
                    final repo = ref.read(adminRepositoryProvider);
                    final url = repo.getReportDownloadUrl(id);
                    // Trigger download via API service
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Téléchargement: $url'), backgroundColor: NeonColors.primary, duration: const Duration(seconds: 2)),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoItem('$rowCount lignes', Icons.table_rows, NeonColors.textSecondary),
              const SizedBox(width: 16),
              _buildInfoItem(_formatFileSize(fileSize), Icons.storage, NeonColors.textSecondary),
              const SizedBox(width: 16),
              _buildInfoItem(insertedAt != null ? _formatDate(insertedAt) : '-', Icons.schedule, NeonColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  void _showGenerateDialog() {
    String selectedType = 'financial';
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.surface,
          title: const Text('Générer un Rapport', style: TextStyle(color: NeonColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: NeonColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nom du rapport (optionnel)',
                  labelStyle: TextStyle(color: NeonColors.textSecondary),
                  prefixIcon: Icon(Icons.label, color: NeonColors.primary, size: 18),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: NeonColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: NeonColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Type de rapport', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildTypeChip('financial', 'Financier', Icons.account_balance, selectedType, (t) => setDialogState(() => selectedType = t)),
                  _buildTypeChip('players', 'Joueurs', Icons.people, selectedType, (t) => setDialogState(() => selectedType = t)),
                  _buildTypeChip('games', 'Jeux', Icons.sports_esports, selectedType, (t) => setDialogState(() => selectedType = t)),
                  _buildTypeChip('compliance', 'Conformité', Icons.verified_user, selectedType, (t) => setDialogState(() => selectedType = t)),
                  _buildTypeChip('bonuses', 'Bonus', Icons.card_giftcard, selectedType, (t) => setDialogState(() => selectedType = t)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(adminReportsManagementProvider.notifier).generateReport(
                  type: selectedType,
                  name: nameCtrl.text.isNotEmpty ? nameCtrl.text : null,
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Générer'),
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, String selected, ValueChanged<String> onSelect) {
    final isSelected = selected == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(type),
      avatar: Icon(icon, size: 14),
      selectedColor: NeonColors.primary.withValues(alpha: 0.2),
      backgroundColor: NeonColors.surface,
      labelStyle: TextStyle(color: isSelected ? NeonColors.primary : NeonColors.textSecondary, fontSize: 11),
      side: BorderSide(color: isSelected ? NeonColors.primary : NeonColors.border),
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
            onPressed: () => ref.read(adminReportsManagementProvider.notifier).loadReports(),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}

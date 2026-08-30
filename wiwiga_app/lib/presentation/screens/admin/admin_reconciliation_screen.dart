// ============================================================
// Fichier: admin_reconciliation_screen.dart
// Description: Écran réconciliation financière admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/skeleton_loader.dart';

/// Écran de réconciliation financière
class AdminReconciliationScreen extends ConsumerStatefulWidget {
  const AdminReconciliationScreen({super.key});

  @override
  ConsumerState<AdminReconciliationScreen> createState() => _AdminReconciliationScreenState();
}

class _AdminReconciliationScreenState extends ConsumerState<AdminReconciliationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _daily;
  Map<String, dynamic>? _discrepancies;
  Map<String, dynamic>? _balance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final results = await Future.wait([
        repo.getDailyReconciliation(),
        repo.getDiscrepancies(),
        repo.getPlatformBalance(),
      ]);
      setState(() {
        _daily = results[0];
        _discrepancies = results[1];
        _balance = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = 'Erreur: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Réconciliation', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NeonColors.primary,
          labelColor: NeonColors.primary,
          unselectedLabelColor: NeonColors.textSecondary,
          tabs: const [
            Tab(text: 'Journalier', icon: Icon(Icons.today, size: 16)),
            Tab(text: 'Écarts', icon: Icon(Icons.compare_arrows, size: 16)),
            Tab(text: 'Solde', icon: Icon(Icons.account_balance, size: 16)),
          ],
        ),
      ),
      body: _isLoading
          ? const AdminSkeletonTable(rowCount: 5, columnCount: 4)
          : _error != null
              ? AdminErrorState(error: _error!, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _DailyTab(data: _daily),
                    _DiscrepanciesTab(data: _discrepancies),
                    _BalanceTab(data: _balance),
                  ],
                ),
    );
  }
}

class _DailyTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _DailyTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Résumé du ${data!['date']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _metricCard('Dépôts', data!['deposits'], NeonColors.success, Icons.arrow_downward),
        _metricCard('Retraits', data!['withdrawals'], NeonColors.warning, Icons.arrow_upward),
        _metricCard('Mises', data!['bets'], NeonColors.info, Icons.casino),
        _metricCard('Gains', data!['winnings'], NeonColors.adminPurple, Icons.emoji_events),
        _metricCard('Commissions', data!['commissions'], NeonColors.primary, Icons.percent),
        const SizedBox(height: 16),
        _summaryRow('GGR', data!['ggr'], NeonColors.primary),
        _summaryRow('Revenu net', data!['net_revenue'], NeonColors.success),
        _summaryRow('Flux net', data!['net_flow'], (data!['net_flow'] as num) >= 0 ? NeonColors.success : NeonColors.error),
      ],
    );
  }

  Widget _metricCard(String label, dynamic metricData, Color color, IconData icon) {
    final amount = (metricData as Map<String, dynamic>?)?['amount'] ?? 0;
    final count = metricData?['count'] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: NeonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 20)),
        title: Text(label, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text('$count transactions', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
        trailing: Text('${(amount as num) / 100} wiga', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _summaryRow(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600)),
          Text('${(value as num) / 100} wiga', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DiscrepanciesTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _DiscrepanciesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    final discrepancies = (data!['discrepancies'] as List?) ?? [];
    final hasIssues = data!['has_issues'] as bool? ?? false;

    if (!hasIssues) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: NeonColors.success, size: 64),
            SizedBox(height: 16),
            Text('Aucun écart détecté', style: TextStyle(color: NeonColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Les transactions sont cohérentes', style: TextStyle(color: NeonColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: discrepancies.length,
      itemBuilder: (context, index) {
        final disc = discrepancies[index] as Map<String, dynamic>;
        final isCritical = disc['severity'] == 'critical';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: NeonColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isCritical ? NeonColors.error : NeonColors.warning, width: 1),
          ),
          child: ListTile(
            leading: Icon(isCritical ? Icons.error : Icons.warning, color: isCritical ? NeonColors.error : NeonColors.warning),
            title: Text(disc['type'] as String? ?? 'Écart', style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(disc['description'] as String? ?? '', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
            trailing: Text('${((disc['difference'] as num?)?.toInt() ?? 0) / 100} wiga',
              style: TextStyle(color: isCritical ? NeonColors.error : NeonColors.warning, fontWeight: FontWeight.bold),),
          ),
        );
      },
    );
  }
}

class _BalanceTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _BalanceTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _balanceItem('Solde joueurs (wiga)', data!['total_player_balance'], NeonColors.primary),
        _balanceItem('Solde wiga', data!['total_token_balance'], NeonColors.adminPurple),
        _balanceItem('Total dépôts', data!['total_deposits'], NeonColors.success),
        _balanceItem('Total retraits', data!['total_withdrawals'], NeonColors.warning),
        _balanceItem('Flux net', data!['net_flow'], (data!['net_flow'] as num) >= 0 ? NeonColors.success : NeonColors.error),
        const Divider(color: NeonColors.border, height: 32),
        _balanceItem('Engagement total', data!['total_engagement'], NeonColors.error),
        _balanceItem('Réserve', data!['reserve'], NeonColors.primary),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ((data!['reserve_ratio'] as num?)?.toDouble() ?? 0) >= 100
                ? NeonColors.success.withValues(alpha: 0.1)
                : NeonColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ratio de réserve', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
              Text(
                '${data!['reserve_ratio']}%',
                style: TextStyle(
                  color: ((data!['reserve_ratio'] as num?)?.toDouble() ?? 0) >= 100 ? NeonColors.success : NeonColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceItem(String label, dynamic value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: NeonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: NeonColors.textPrimary)),
        trailing: Text('${((value as num?)?.toInt() ?? 0) / 100} wiga',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),),
      ),
    );
  }
}

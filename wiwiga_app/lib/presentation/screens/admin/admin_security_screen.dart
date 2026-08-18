// ============================================================
// Fichier: admin_security_screen.dart
// Description: Écran gestion sécurité admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/admin/metric_card.dart';

/// Écran de gestion de la sécurité admin
class AdminSecurityScreen extends ConsumerStatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  ConsumerState<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends ConsumerState<AdminSecurityScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Sécurité', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['Vue d\'ensemble', 'IP Whitelist', 'Auth échouées', 'Bans'];
    return Container(
      color: NeonColors.surface,
      child: Row(
        children: List.generate(tabs.length, (i) {
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
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                    fontSize: 11,
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

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildOverview();
      case 1:
        return _buildIpWhitelist();
      case 2:
        return _buildFailedAuths();
      case 3:
        return _buildBans();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverview() {
    final securityAsync = ref.watch(adminSecurityOverviewProvider);

    return securityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: NeonColors.primary)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: NeonColors.error))),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score de sécurité
            _buildSecurityScore(data['security_score'] ?? 75, data['threat_level'] ?? 'medium'),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                AdminMetricCard(
                  title: 'Auth échouées (1h)',
                  value: '${data['failed_auths_1h'] ?? 0}',
                  icon: Icons.lock_clock,
                  color: NeonColors.error,
                ),
                AdminMetricCard(
                  title: 'Auth échouées (24h)',
                  value: '${data['failed_auths_24h'] ?? 0}',
                  icon: Icons.lock_outline,
                  color: NeonColors.warning,
                ),
                AdminMetricCard(
                  title: 'Rate limités',
                  value: '${data['rate_limited_24h'] ?? 0}',
                  icon: Icons.speed,
                  color: NeonColors.secondary,
                ),
                AdminMetricCard(
                  title: 'Bans actifs',
                  value: '${data['active_bans'] ?? 0}',
                  icon: Icons.block,
                  color: NeonColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityScore(int score, String threatLevel) {
    final color = score >= 80 ? NeonColors.success : score >= 50 ? NeonColors.warning : NeonColors.error;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: NeonColors.border,
                    color: color,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Score de sécurité', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Niveau de menace: ${threatLevel == 'low' ? 'Faible' : threatLevel == 'medium' ? 'Moyen' : 'Élevé'}',
                style: TextStyle(color: color, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIpWhitelist() {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(adminRepositoryProvider).getIpWhitelist(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NeonColors.primary));
        }
        final ips = snapshot.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddIpDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une IP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeonColors.primary.withValues(alpha: 0.2),
                  foregroundColor: NeonColors.primary,
                ),
              ),
            ),
            Expanded(
              child: ips.isEmpty
                  ? const Center(child: Text('Aucune IP dans la whitelist', style: TextStyle(color: NeonColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ips.length,
                      itemBuilder: (context, index) {
                        final entry = ips[index] as Map<String, dynamic>;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.language, color: NeonColors.accent),
                          title: Text(entry['ip_address'] ?? '', style: const TextStyle(color: NeonColors.textPrimary, fontFamily: 'monospace')),
                          subtitle: Text(entry['description'] ?? '', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: NeonColors.error, size: 18),
                            onPressed: () async {
                              await ref.read(adminRepositoryProvider).removeIpFromWhitelist(entry['ip_address'] ?? '');
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFailedAuths() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepositoryProvider).getFailedAuths(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NeonColors.primary));
        }
        final data = snapshot.data ?? {};
        final logs = data['logs'] as List? ?? [];

        return logs.isEmpty
            ? const Center(child: Text('Aucune auth échouée récente', style: TextStyle(color: NeonColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index] as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning, color: NeonColors.warning, size: 20),
                    title: Text(log['action'] ?? 'login_failed', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13)),
                    subtitle: Text(
                      'User: ${log['user_id'] ?? 'N/A'} - ${log['inserted_at'] ?? ''}',
                      style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11),
                    ),
                  );
                },
              );
      },
    );
  }

  Widget _buildBans() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepositoryProvider).getSecurityOverview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NeonColors.primary));
        }
        return const Center(
          child: Text('Liste des bans actifs', style: TextStyle(color: NeonColors.textSecondary)),
        );
      },
    );
  }

  void _showAddIpDialog() {
    final ipController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Ajouter une IP', style: TextStyle(color: NeonColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Adresse IP',
                hintText: '192.168.1.1',
              ),
              style: const TextStyle(color: NeonColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Bureau admin...',
              ),
              style: const TextStyle(color: NeonColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (ipController.text.isNotEmpty) {
                await ref.read(adminRepositoryProvider).addIpToWhitelist(
                  ipController.text,
                  description: descController.text,
                );
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

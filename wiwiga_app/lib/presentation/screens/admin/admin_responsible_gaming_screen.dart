// ============================================================
// Fichier: admin_responsible_gaming_screen.dart
// Description: Écran jeu responsable admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/admin_management_provider.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../widgets/admin/metric_card.dart';

/// Écran de gestion du jeu responsable
class AdminResponsibleGamingScreen extends ConsumerStatefulWidget {
  const AdminResponsibleGamingScreen({super.key});

  @override
  ConsumerState<AdminResponsibleGamingScreen> createState() => _AdminResponsibleGamingScreenState();
}

class _AdminResponsibleGamingScreenState extends ConsumerState<AdminResponsibleGamingScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Jeu Responsable', style: TextStyle(fontWeight: FontWeight.bold)),
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
    const tabs = ['Vue d\'ensemble', 'Auto-exclusions', 'Limites', 'Risques'];
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
        return _buildSelfExclusions();
      case 2:
        return _buildLimits();
      case 3:
        return _buildRiskIndicators();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverview() {
    final overviewAsync = ref.watch(adminResponsibleGamingProvider);

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: NeonColors.primary)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: NeonColors.error))),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                AdminMetricCard(
                  title: 'Auto-exclus',
                  value: '${data['self_excluded_count'] ?? 0}',
                  icon: Icons.person_off,
                  color: NeonColors.warning,
                ),
                AdminMetricCard(
                  title: 'Limites actives',
                  value: '${data['active_limits'] ?? 0}',
                  icon: Icons.tune,
                  color: NeonColors.primary,
                ),
                AdminMetricCard(
                  title: 'Users à risque',
                  value: '${data['users_at_risk'] ?? 0}',
                  icon: Icons.warning_amber_rounded,
                  color: NeonColors.error,
                ),
                AdminMetricCard(
                  title: 'Dépassements limites',
                  value: '${data['limit_breaches'] ?? 0}',
                  icon: Icons.report_problem,
                  color: NeonColors.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfExclusions() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepositoryProvider).getSelfExclusions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NeonColors.primary));
        }
        final data = snapshot.data ?? {};
        final exclusions = data['self_exclusions'] as List? ?? [];

        return exclusions.isEmpty
            ? const Center(child: Text('Aucune auto-exclusion active', style: TextStyle(color: NeonColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exclusions.length,
                itemBuilder: (context, index) {
                  final exclusion = exclusions[index] as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NeonColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NeonColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_off, color: NeonColors.warning, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User #${exclusion['user_id'] ?? 'N/A'}',
                                style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Raison: ${exclusion['reason'] ?? 'Non spécifiée'}',
                                style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                              ),
                              if (exclusion['excluded_until'] != null)
                                Text(
                                  'Jusqu\'au: ${exclusion['excluded_until']}',
                                  style: const TextStyle(color: NeonColors.textMuted, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
      },
    );
  }

  Widget _buildLimits() {
    final configState = ref.watch(adminPlatformConfigProvider);
    final gamingConfigs = configState.configs['gaming'] ?? [];

    // Charger les configs si pas encore fait
    if (!configState.isLoading && gamingConfigs.isEmpty) {
      Future.microtask(() => ref.read(adminPlatformConfigProvider.notifier).loadCategory('gaming'));
    }

    // Configs clés pour le jeu responsable
    final rgKeys = {
      'default_daily_loss_limit': {'label': 'Perte quotidienne max (FCFA)', 'icon': Icons.money_off, 'default': '500000'},
      'default_session_time_minutes': {'label': 'Durée session max (min)', 'icon': Icons.timer_off, 'default': '120'},
      'max_bet_per_round': {'label': 'Mise max par round (FCFA)', 'icon': Icons.casino, 'default': '1000000'},
      'reality_check_interval_minutes': {'label': 'Intervalle rappel réalité (min)', 'icon': Icons.notifications_active, 'default': '30'},
      'fallback_timeout_seconds': {'label': 'Timeout matchmaking (s)', 'icon': Icons.hourglass_empty, 'default': '30'},
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Limites globales (PlatformConfig)', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Ces limites s\'appliquent par défaut à tous les joueurs sans limites personnelles.', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ...rgKeys.entries.map((entry) {
            final key = entry.key;
            final meta = entry.value;
            final config = gamingConfigs.where((c) => c['key'] == key).toList();
            final currentValue = config.isNotEmpty ? (config.first['value'] ?? config.first['default_value'] ?? meta['default']).toString() : meta['default'].toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NeonColors.border),
              ),
              child: Row(
                children: [
                  Icon(meta['icon'] as IconData, color: NeonColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meta['label'] as String, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Valeur: $currentValue', style: const TextStyle(color: NeonColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: NeonColors.secondary, size: 18),
                    onPressed: () => _editGamingLimit(key, currentValue, meta['label'] as String),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _editGamingLimit(String key, String currentValue, String label) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: Text(label, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: NeonColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nouvelle valeur',
            hintStyle: TextStyle(color: NeonColors.textMuted),
            border: OutlineInputBorder(borderSide: BorderSide(color: NeonColors.border)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: NeonColors.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: NeonColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                await ref.read(adminPlatformConfigProvider.notifier).updateConfig('gaming', key, newValue);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskIndicators() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepositoryProvider).getRiskIndicators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NeonColors.primary));
        }
        final data = snapshot.data ?? {};
        final indicators = data['risk_indicators'] as List? ?? data['high_losers'] as List? ?? [];

        return indicators.isEmpty
            ? const Center(child: Text('Aucun indicateur de risque détecté', style: TextStyle(color: NeonColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: indicators.length,
                itemBuilder: (context, index) {
                  final indicator = indicators[index] as Map<String, dynamic>;
                  final riskLevel = indicator['risk_level'] ?? 'medium';
                  final riskColor = riskLevel == 'high' ? NeonColors.error : riskLevel == 'medium' ? NeonColors.warning : NeonColors.info;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NeonColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.warning, color: riskColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User #${indicator['user_id'] ?? 'N/A'}',
                                style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Pertes: ${indicator['total_losses'] ?? indicator['net_loss'] ?? 0} FCFA',
                                style: TextStyle(color: riskColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            riskLevel.toUpperCase(),
                            style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
      },
    );
  }
}

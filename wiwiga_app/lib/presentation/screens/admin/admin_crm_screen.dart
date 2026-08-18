// ============================================================
// Fichier: admin_crm_screen.dart
// Description: Écran CRM admin - Segments, VIP, À risque, Notes
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../providers/admin_crm_provider.dart';

/// Écran CRM avec onglets: Segments, VIP, À risque
class AdminCrmScreen extends ConsumerStatefulWidget {
  const AdminCrmScreen({super.key});

  @override
  ConsumerState<AdminCrmScreen> createState() => _AdminCrmScreenState();
}

class _AdminCrmScreenState extends ConsumerState<AdminCrmScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() => ref.read(adminCrmProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crmState = ref.watch(adminCrmProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('CRM Joueurs', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NeonColors.primary,
          labelColor: NeonColors.primary,
          unselectedLabelColor: NeonColors.textSecondary,
          tabs: const [
            Tab(text: 'Segments', icon: Icon(Icons.grid_view, size: 16)),
            Tab(text: 'VIP', icon: Icon(Icons.star, size: 16)),
            Tab(text: 'À risque', icon: Icon(Icons.warning_amber, size: 16)),
          ],
        ),
      ),
      body: crmState.isLoading
          ? const Center(child: CircularProgressIndicator(color: NeonColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _SegmentsTab(segments: crmState.segments),
                _VipTab(players: crmState.vipPlayers),
                _AtRiskTab(players: crmState.atRiskPlayers),
              ],
            ),
    );
  }
}

// ========================================
// ONGLET SEGMENTS
// ========================================

class _SegmentsTab extends StatelessWidget {
  final List<dynamic> segments;
  const _SegmentsTab({required this.segments});

  Color _segmentColor(String? color) {
    switch (color) {
      case 'gold': return Colors.amber;
      case 'purple': return Colors.purple;
      case 'green': return Colors.green;
      case 'gray': return Colors.grey;
      case 'red': return Colors.red;
      case 'teal': return Colors.teal;
      default: return NeonColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Center(child: Text('Aucun segment disponible', style: TextStyle(color: NeonColors.textSecondary)));
    }

    return RefreshIndicator(
      onRefresh: () async {},
      color: NeonColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final seg = segments[index] as Map<String, dynamic>;
          final color = _segmentColor(seg['color'] as String?);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: NeonColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _segmentIcon(seg['key'] as String?),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seg['label'] as String? ?? 'Segment',
                          style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${seg['count'] ?? 0} joueurs',
                          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${seg['count'] ?? 0}',
                    style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _segmentIcon(String? key) {
    switch (key) {
      case 'total': return Icons.people;
      case 'vip': return Icons.star;
      case 'high_rollers': return Icons.diamond;
      case 'new_players': return Icons.person_add;
      case 'inactive': return Icons.person_off;
      case 'at_risk': return Icons.warning;
      case 'kyc_verified': return Icons.verified;
      default: return Icons.group;
    }
  }
}

// ========================================
// ONGLET VIP
// ========================================

class _VipTab extends StatelessWidget {
  final List<dynamic> players;
  const _VipTab({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(child: Text('Aucun joueur VIP', style: TextStyle(color: NeonColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index] as Map<String, dynamic>;
        final wagered = (player['total_wagered'] as num?)?.toInt() ?? 0;
        final won = (player['total_won'] as num?)?.toInt() ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: NeonColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
              child: Text('#${index + 1}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(
              player['name'] as String? ?? 'Joueur ${player['user_id']}',
              style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Mises: ${(wagered / 100).toStringAsFixed(0)} FCFA | Gains: ${(won / 100).toStringAsFixed(0)} FCFA',
              style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11),
            ),
            trailing: player['has_kyc'] == true
                ? const Icon(Icons.verified, color: Colors.teal, size: 18)
                : const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          ),
        );
      },
    );
  }
}

// ========================================
// ONGLET À RISQUE
// ========================================

class _AtRiskTab extends StatelessWidget {
  final List<dynamic> players;
  const _AtRiskTab({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('Aucun joueur à risque détecté', style: TextStyle(color: NeonColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index] as Map<String, dynamic>;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: NeonColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.red, width: 0.5)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.2),
              child: const Icon(Icons.warning, color: Colors.red, size: 20),
            ),
            title: Text(
              player['name'] as String? ?? 'Joueur ${player['user_id']}',
              style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              player['self_excluded'] == true ? 'Auto-exclu' : 'Solde négatif',
              style: TextStyle(
                color: player['self_excluded'] == true ? Colors.red : Colors.orange,
                fontSize: 12,
              ),
            ),
            trailing: Text(
              '${((player['balance'] as num?)?.toInt() ?? 0) / 100} FCFA',
              style: TextStyle(
                color: ((player['balance'] as num?)?.toInt() ?? 0) >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

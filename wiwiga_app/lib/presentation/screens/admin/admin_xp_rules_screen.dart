// ============================================================
// Fichier: admin_xp_rules_screen.dart
// Description: Configuration des règles de gain XP par type de jeu
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../providers/admin_management_provider.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/skeleton_loader.dart';

/// Écran configuration des règles XP par type de jeu
class AdminXPRulesScreen extends ConsumerStatefulWidget {
  const AdminXPRulesScreen({super.key});

  @override
  ConsumerState<AdminXPRulesScreen> createState() => _AdminXPRulesScreenState();
}

class _AdminXPRulesScreenState extends ConsumerState<AdminXPRulesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminXPRulesProvider.notifier).loadRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminXPRulesProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Règles XP', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(),
            tooltip: 'Ajouter des règles XP',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminXPRulesProvider.notifier).loadRules(),
          ),
        ],
      ),
      body: state.isLoading && state.rules.isEmpty
          ? const AdminSkeletonList(itemCount: 4)
          : state.error != null && state.rules.isEmpty
              ? AdminErrorState(error: state.error!, onRetry: () => ref.read(adminXPRulesProvider.notifier).loadRules())
              : _buildRulesList(state),
    );
  }

  Widget _buildRulesList(AdminXPRulesState state) {
    if (state.rules.isEmpty) {
      return AdminEmptyState(
        icon: Icons.stars,
        title: 'Aucune règle XP configurée',
        subtitle: 'Les règles XP définissent combien d\'XP est gagné\npour chaque action dans chaque type de jeu.',
        actionLabel: 'Créer des règles XP',
        actionIcon: Icons.add,
        onAction: () => _showCreateDialog(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminXPRulesProvider.notifier).loadRules(),
      color: NeonColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.rules.length,
        itemBuilder: (context, index) {
          final rule = state.rules[index] as Map<String, dynamic>;
          return _buildRuleCard(rule);
        },
      ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final gameType = rule['game_type'] as String? ?? '';
    final winXp = rule['win_xp'] as int? ?? 50;
    final lossXp = rule['loss_xp'] as int? ?? 10;
    final drawXp = rule['draw_xp'] as int? ?? 25;
    final partXp = rule['participation_xp'] as int? ?? 5;
    final streakBonus = rule['streak_bonus'] as int? ?? 5;
    final maxStreak = rule['max_streak_bonus'] as int? ?? 50;
    final multiplier = (rule['xp_multiplier'] as num?)?.toDouble() ?? 1.0;
    final isActive = rule['is_active'] as bool? ?? true;

    final colors = [NeonColors.primary, NeonColors.secondary, NeonColors.accent, NeonColors.success];
    final color = colors[gameType.hashCode.abs() % colors.length];

    return Card(
      color: NeonColors.card,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isActive ? color.withValues(alpha: 0.3) : NeonColors.border),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.06), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.stars, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gameType.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (!isActive) const Text('Désactivé', style: TextStyle(color: NeonColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                // Active toggle
                Switch(
                  value: isActive,
                  onChanged: (value) {
                    ref.read(adminXPRulesProvider.notifier).saveRules(gameType, {
                      ...rule, 'is_active': value,
                    });
                  },
                  activeThumbColor: NeonColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // XP Values grid
            Row(
              children: [
                Expanded(child: _buildXpChip('Victoire', '+$winXp', Icons.emoji_events, NeonColors.success)),
                const SizedBox(width: 8),
                Expanded(child: _buildXpChip('Défaite', '+$lossXp', Icons.close, NeonColors.error)),
                const SizedBox(width: 8),
                Expanded(child: _buildXpChip('Nul', '+$drawXp', Icons.balance, NeonColors.secondary)),
                const SizedBox(width: 8),
                Expanded(child: _buildXpChip('Participation', '+$partXp', Icons.person, NeonColors.accent)),
              ],
            ),
            const SizedBox(height: 12),

            // Streak & multiplier
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NeonColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text('Bonus Série', style: TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('+$streakBonus/victoire', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('(max $maxStreak)', style: const TextStyle(color: NeonColors.textMuted, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NeonColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text('Multiplicateur', style: TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('x${multiplier.toStringAsFixed(1)}', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                        const Text('(événements)', style: TextStyle(color: NeonColors.textMuted, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDelete(gameType),
                  icon: const Icon(Icons.delete, color: NeonColors.error, size: 18),
                  label: const Text('Supprimer', style: TextStyle(color: NeonColors.error)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showEditDialog(rule),
                  icon: Icon(Icons.edit, color: color, size: 18),
                  label: Text('Modifier', style: TextStyle(color: color)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: NeonColors.textMuted, fontSize: 9)),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> rule) {
    final gameType = rule['game_type'] as String;
    final winCtrl = TextEditingController(text: '${rule['win_xp'] ?? 50}');
    final lossCtrl = TextEditingController(text: '${rule['loss_xp'] ?? 10}');
    final drawCtrl = TextEditingController(text: '${rule['draw_xp'] ?? 25}');
    final partCtrl = TextEditingController(text: '${rule['participation_xp'] ?? 5}');
    final streakCtrl = TextEditingController(text: '${rule['streak_bonus'] ?? 5}');
    final maxStreakCtrl = TextEditingController(text: '${rule['max_streak_bonus'] ?? 50}');
    final multCtrl = TextEditingController(text: '${(rule['xp_multiplier'] as num?)?.toDouble() ?? 1.0}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Règles XP - ${gameType.toUpperCase()}',
          style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildField('XP Victoire', winCtrl, Icons.emoji_events),
            const SizedBox(height: 12),
            _buildField('XP Défaite', lossCtrl, Icons.close),
            const SizedBox(height: 12),
            _buildField('XP Nul', drawCtrl, Icons.balance),
            const SizedBox(height: 12),
            _buildField('XP Participation', partCtrl, Icons.person),
            const SizedBox(height: 12),
            _buildField('Bonus par série', streakCtrl, Icons.local_fire_department),
            const SizedBox(height: 12),
            _buildField('Max bonus série', maxStreakCtrl, Icons.trending_up),
            const SizedBox(height: 12),
            _buildField('Multiplicateur XP', multCtrl, Icons.bolt),
          ],),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveRules(gameType, winCtrl.text, lossCtrl.text, drawCtrl.text,
                partCtrl.text, streakCtrl.text, maxStreakCtrl.text, multCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final typeCtrl = TextEditingController();
    final winCtrl = TextEditingController(text: '50');
    final lossCtrl = TextEditingController(text: '10');
    final drawCtrl = TextEditingController(text: '25');
    final partCtrl = TextEditingController(text: '5');
    final streakCtrl = TextEditingController(text: '5');
    final maxStreakCtrl = TextEditingController(text: '50');
    final multCtrl = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nouvelles règles XP',
          style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildField('Type de jeu', typeCtrl, Icons.sports_esports),
            const SizedBox(height: 12),
            _buildField('XP Victoire', winCtrl, Icons.emoji_events),
            const SizedBox(height: 12),
            _buildField('XP Défaite', lossCtrl, Icons.close),
            const SizedBox(height: 12),
            _buildField('XP Nul', drawCtrl, Icons.balance),
            const SizedBox(height: 12),
            _buildField('XP Participation', partCtrl, Icons.person),
            const SizedBox(height: 12),
            _buildField('Bonus par série', streakCtrl, Icons.local_fire_department),
            const SizedBox(height: 12),
            _buildField('Max bonus série', maxStreakCtrl, Icons.trending_up),
            const SizedBox(height: 12),
            _buildField('Multiplicateur XP', multCtrl, Icons.bolt),
          ],),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (typeCtrl.text.trim().isEmpty) {
                context.showError('Type de jeu requis');
                return;
              }
              _saveRules(typeCtrl.text.trim().toLowerCase(),
                winCtrl.text, lossCtrl.text, drawCtrl.text,
                partCtrl.text, streakCtrl.text, maxStreakCtrl.text, multCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _saveRules(String gameType, String win, String loss, String draw,
      String part, String streak, String maxStreak, String mult) async {
    final rules = {
      'win_xp': int.tryParse(win) ?? 50,
      'loss_xp': int.tryParse(loss) ?? 10,
      'draw_xp': int.tryParse(draw) ?? 25,
      'participation_xp': int.tryParse(part) ?? 5,
      'streak_bonus': int.tryParse(streak) ?? 5,
      'max_streak_bonus': int.tryParse(maxStreak) ?? 50,
      'xp_multiplier': double.tryParse(mult) ?? 1.0,
      'is_active': true,
    };
    final success = await ref.read(adminXPRulesProvider.notifier).saveRules(gameType, rules);
    if (mounted) {
      context.showResult(success,
        successMsg: 'Règles XP $gameType sauvegardées',
        errorMsg: 'Erreur de sauvegarde',
      );
    }
  }

  void _confirmDelete(String gameType) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Confirmer la suppression',
      message: 'Supprimer les règles XP pour "$gameType" ?',
      confirmLabel: 'Supprimer',
      confirmColor: NeonColors.error,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      final success = await ref.read(adminXPRulesProvider.notifier).deleteRules(gameType);
      if (mounted) {
        context.showResult(success,
          successMsg: 'Règles XP supprimées',
          errorMsg: 'Erreur de suppression',
        );
      }
    }
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: NeonColors.textPrimary),
      keyboardType: label.contains('Multiplicateur')
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeonColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: NeonColors.primary, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: NeonColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.primary)),
      ),
    );
  }
}

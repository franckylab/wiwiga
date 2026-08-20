// ============================================================
// Fichier: admin_player_progression_screen.dart
// Description: Configuration des niveaux/tiers joueur et récompenses
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../providers/admin_management_provider.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran configuration progression joueur (niveaux, XP, récompenses)
class AdminPlayerProgressionScreen extends ConsumerStatefulWidget {
  const AdminPlayerProgressionScreen({super.key});

  @override
  ConsumerState<AdminPlayerProgressionScreen> createState() => _AdminPlayerProgressionScreenState();
}

class _AdminPlayerProgressionScreenState extends ConsumerState<AdminPlayerProgressionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminPlayerProgressionProvider.notifier).loadLevels();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPlayerProgressionProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Progression Joueur', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(),
            tooltip: 'Ajouter un niveau',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminPlayerProgressionProvider.notifier).loadLevels(),
          ),
        ],
      ),
      body: state.isLoading && state.levels.isEmpty
          ? const NeonLoadingSpinner.center()
          : RefreshIndicator(
              color: NeonColors.primary,
              onRefresh: () => ref.read(adminPlayerProgressionProvider.notifier).loadLevels(),
              child: state.error != null && state.levels.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: AdminErrorState(error: state.error!, onRetry: () => ref.read(adminPlayerProgressionProvider.notifier).loadLevels()),
                    )
                  : _buildLevelsList(state),
            ),
    );
  }

  Widget _buildLevelsList(AdminPlayerProgressionState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.levels.length,
      itemBuilder: (context, index) {
        final level = state.levels[index];
        return _buildLevelCard(level, index);
      },
    );
  }

  Widget _buildLevelCard(Map<String, dynamic> level, int index) {
    final tier = level['tier'] as String? ?? '';
    final name = level['name'] as String? ?? tier;
    final minXp = level['min_xp'] as int? ?? 0;
    final maxXp = level['max_xp'];
    final icon = level['icon'] as String? ?? 'shield';
    final colorStr = level['color'] as String? ?? '#808080';
    final benefits = level['benefits'] as Map<String, dynamic>? ?? {};
    final color = _parseColor(colorStr);

    final cashback = ((benefits['cashback_rate'] as num?)?.toDouble() ?? 0) * 100;
    const withdrawBonus = 0.0;
    final betDiscount = ((benefits['bet_discount'] as num?)?.toDouble() ?? 0) * 100;
    final dailyMult = (benefits['daily_bonus_multiplier'] as num?)?.toDouble() ?? 1.0;
    final label = benefits['label'] as String? ?? name;

    return Card(
      color: NeonColors.card,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.08), Colors.transparent],
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
                  child: Icon(_getIconData(icon), color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('#${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // XP Range
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildXpItem('Min XP', '$minXp', color),
                  Container(width: 1, height: 24, color: NeonColors.border),
                  _buildXpItem('Max XP', maxXp != null ? '$maxXp' : 'Illimité', color),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Benefits
            const Text('Avantages', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildBenefitChip('Cashback', '${cashback.toStringAsFixed(0)}%', Icons.savings, color)),
                const SizedBox(width: 8),
                Expanded(child: _buildBenefitChip('Réduc. Commission', '${betDiscount.toStringAsFixed(0)}%', Icons.discount, color)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildBenefitChip('Bonus Journalier', 'x${dailyMult.toStringAsFixed(1)}', Icons.card_giftcard, color)),
                const SizedBox(width: 8),
                Expanded(child: _buildBenefitChip('Bonus Retrait', '${(withdrawBonus * 100).toStringAsFixed(0)}%', Icons.account_balance, color)),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDeleteLevel(tier, name),
                  icon: const Icon(Icons.delete, color: NeonColors.error, size: 18),
                  label: const Text('Supprimer', style: TextStyle(color: NeonColors.error)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showEditDialog(level),
                  icon: Icon(Icons.edit, color: color, size: 18),
                  label: Text('Configurer', style: TextStyle(color: color)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildBenefitChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
                Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> level) {
    final tier = level['tier'] as String;
    final benefits = Map<String, dynamic>.from(level['benefits'] as Map? ?? {});
    final cashbackCtrl = TextEditingController(text: '${((benefits['cashback_rate'] as num?)?.toDouble() ?? 0) * 100}');
    final betDiscountCtrl = TextEditingController(text: '${((benefits['bet_discount'] as num?)?.toDouble() ?? 0) * 100}');
    final dailyMultCtrl = TextEditingController(text: '${(benefits['daily_bonus_multiplier'] as num?)?.toDouble() ?? 1.0}');
    final minXPctrl = TextEditingController(text: '${level['min_xp'] ?? 0}');
    final maxXPctrl = TextEditingController(text: '${level['max_xp'] ?? ''}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Configurer ${level['name']}', style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildDialogField('Min XP', minXPctrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Max XP (vide = illimité)', maxXPctrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Cashback (%)', cashbackCtrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Réduction commission (%)', betDiscountCtrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Multiplicateur bonus journalier', dailyMultCtrl, const TextInputType.numberWithOptions(decimal: true)),
          ],),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveLevelConfig(tier, minXPctrl.text, maxXPctrl.text, cashbackCtrl.text, betDiscountCtrl.text, dailyMultCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, TextInputType type) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: NeonColors.textPrimary),
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeonColors.textSecondary, fontSize: 13),
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

  void _saveLevelConfig(String tier, String minXp, String maxXp, String cashback, String betDiscount, String dailyMult) async {
    final config = <String, dynamic>{
      'min_xp': int.tryParse(minXp) ?? 0,
      'max_xp': int.tryParse(maxXp),
      'benefits': {
        'cashback_rate': (double.tryParse(cashback) ?? 0) / 100,
        'bet_discount': (double.tryParse(betDiscount) ?? 0) / 100,
        'daily_bonus_multiplier': double.tryParse(dailyMult) ?? 1.0,
      },
    };
    final success = await ref.read(adminPlayerProgressionProvider.notifier).updateLevel(tier, config);
    if (mounted) {
      context.showResult(success,
        successMsg: 'Niveau mis à jour',
        errorMsg: 'Erreur de sauvegarde',
      );
    }
  }

  
  void _confirmDeleteLevel(String tier, String name) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Confirmer la suppression',
      message: 'Voulez-vous vraiment supprimer le niveau "$name" ?',
      confirmLabel: 'Supprimer',
      confirmColor: NeonColors.error,
      icon: Icons.delete_outline,
    );
    if (!confirmed) return;
    final success = await ref.read(adminPlayerProgressionProvider.notifier).deleteLevel(tier);
    if (mounted) {
      context.showResult(success,
        successMsg: 'Niveau supprimé',
        errorMsg: 'Erreur de suppression',
      );
    }
  }

  void _showCreateDialog() {
    final tierCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final minXPctrl = TextEditingController(text: '0');
    final maxXPctrl = TextEditingController();
    final cashbackCtrl = TextEditingController(text: '0');
    final betDiscountCtrl = TextEditingController(text: '0');
    final dailyMultCtrl = TextEditingController(text: '1.0');
    final colorCtrl = TextEditingController(text: '#808080');
    final iconCtrl = TextEditingController(text: 'shield');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Créer un nouveau niveau', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildDialogField('Tier (ex: elite)', tierCtrl, TextInputType.text),
            const SizedBox(height: 12),
            _buildDialogField('Nom affiché', nameCtrl, TextInputType.text),
            const SizedBox(height: 12),
            _buildDialogField('Min XP', minXPctrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Max XP (vide = illimité)', maxXPctrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Couleur (hex)', colorCtrl, TextInputType.text),
            const SizedBox(height: 12),
            _buildDialogField('Icône (shield, star, diamond...)', iconCtrl, TextInputType.text),
            const SizedBox(height: 12),
            _buildDialogField('Cashback (%)', cashbackCtrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Réduction commission (%)', betDiscountCtrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildDialogField('Multiplicateur bonus journalier', dailyMultCtrl, const TextInputType.numberWithOptions(decimal: true)),
          ],),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createNewLevel(
                tierCtrl.text, nameCtrl.text, minXPctrl.text, maxXPctrl.text,
                colorCtrl.text, iconCtrl.text, cashbackCtrl.text, betDiscountCtrl.text, dailyMultCtrl.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _createNewLevel(String tier, String name, String minXp, String maxXp, String color, String icon, String cashback, String betDiscount, String dailyMult) async {
    if (tier.isEmpty || name.isEmpty) {
      context.showError('Tier et nom requis');
      return;
    }

    final config = <String, dynamic>{
      'tier': tier.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      'name': name,
      'min_xp': int.tryParse(minXp) ?? 0,
      'max_xp': int.tryParse(maxXp),
      'color': color,
      'icon': icon,
      'benefits': {
        'cashback_rate': (double.tryParse(cashback) ?? 0) / 100,
        'bet_discount': (double.tryParse(betDiscount) ?? 0) / 100,
        'daily_bonus_multiplier': double.tryParse(dailyMult) ?? 1.0,
        'label': name,
      },
    };
    final success = await ref.read(adminPlayerProgressionProvider.notifier).createLevel(config);
    if (mounted) {
      context.showResult(success,
        successMsg: 'Niveau créé',
        errorMsg: 'Erreur de création',
      );
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return NeonColors.primary;
    }
  }

  IconData _getIconData(String name) {
    const icons = {
      'shield': Icons.shield, 'workspace_premium': Icons.workspace_premium,
      'emoji_events': Icons.emoji_events, 'star': Icons.star,
      'diamond': Icons.diamond, 'military_tech': Icons.military_tech,
    };
    return icons[name] ?? Icons.shield;
  }
}

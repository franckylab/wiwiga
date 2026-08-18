// ============================================================
// Fichier: admin_bonuses_screen.dart
// Description: Écran gestion bonus et promotions
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../providers/admin_management_provider.dart';

/// Écran gestion des bonus et promotions
class AdminBonusesScreen extends ConsumerStatefulWidget {
  const AdminBonusesScreen({super.key});

  @override
  ConsumerState<AdminBonusesScreen> createState() => _AdminBonusesScreenState();
}

class _AdminBonusesScreenState extends ConsumerState<AdminBonusesScreen> {
  String? _filterType;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminBonusesManagementProvider.notifier).loadBonuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBonusesManagementProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Bonus & Promotions'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(),
            tooltip: 'Créer un bonus',
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

  Widget _buildContent(AdminBonusesState state) {
    final bonuses = state.bonuses;
    final activeBonuses = bonuses.where((b) => b['is_active'] == true).toList();
    final inactiveBonuses = bonuses.where((b) => b['is_active'] != true).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(adminBonusesManagementProvider.notifier).loadBonuses(),
      color: NeonColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Filtres
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildFilterChip(null, 'Tous'),
                  const SizedBox(width: 8),
                  _buildFilterChip('welcome', 'Bienvenue'),
                  const SizedBox(width: 8),
                  _buildFilterChip('deposit', 'Depot'),
                  const SizedBox(width: 8),
                  _buildFilterChip('cashback', 'Cashback'),
                  const SizedBox(width: 8),
                  _buildFilterChip('tournament', 'Tournoi'),
                ],
              ),
            ),
          ),

          // Résumé
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildSummaryBadge('${activeBonuses.length} actifs', NeonColors.success),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('${inactiveBonuses.length} inactifs', NeonColors.textMuted),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('${bonuses.length} total', NeonColors.primary),
                ],
              ),
            ),
          ),

          // Liste bonus
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildBonusCard(bonuses[index] as Map<String, dynamic>),
                childCount: bonuses.length,
              ),
            ),
          ),

          if (bonuses.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, color: NeonColors.textMuted, size: 64),
                    const SizedBox(height: 16),
                    const Text('Aucun bonus configuré', style: TextStyle(color: NeonColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Créer un bonus'),
                      style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBonusCard(Map<String, dynamic> bonus) {
    final name = bonus['name'] as String? ?? '';
    final type = bonus['type'] as String? ?? '';
    final value = (bonus['value'] as num?)?.toDouble() ?? 0;
    final isActive = bonus['is_active'] as bool? ?? false;
    final usageCount = bonus['usage_count'] as int? ?? 0;
    final totalCost = (bonus['total_cost'] as num?)?.toDouble() ?? 0;
    final wageringReq = (bonus['wagering_requirement'] as num?)?.toDouble() ?? 0;
    final expiresAt = bonus['expires_at'] as String?;

    final typeColors = {
      'welcome': NeonColors.primary,
      'deposit': NeonColors.success,
      'cashback': NeonColors.accent,
      'tournament': NeonColors.secondary,
    };
    final color = typeColors[type] ?? NeonColors.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.3) : NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(type.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Switch(
                value: isActive,
                onChanged: (value) async {
                  final id = bonus['id']?.toString() ?? '';
                  final bonusName = bonus['name'] as String? ?? '';
                  final success = await ref.read(adminBonusesManagementProvider.notifier).toggleBonus(id, value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '"$bonusName" ${value ? "activé" : "désactivé"}'
                            : 'Erreur de mise à jour',),
                        backgroundColor: success ? NeonColors.success : NeonColors.error,
                      ),
                    );
                  }
                },
                activeColor: NeonColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Valeur', '${value.toStringAsFixed(0)} FCFA', color),
              const SizedBox(width: 16),
              _buildStatItem('Wagering', '${wageringReq.toStringAsFixed(0)}x', NeonColors.secondary),
              const SizedBox(width: 16),
              _buildStatItem('Utilisations', '$usageCount', NeonColors.accent),
              const SizedBox(width: 16),
              _buildStatItem('Coût total', _formatAmount(totalCost), NeonColors.error),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Text('Expire: ${_formatDate(expiresAt)}', style: TextStyle(
              color: _isExpired(expiresAt) ? NeonColors.error : NeonColors.textMuted,
              fontSize: 10,
            ),),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? type, String label) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterType = selected ? type : null);
        ref.read(adminBonusesManagementProvider.notifier).loadBonuses(type: selected ? type : null);
      },
      selectedColor: NeonColors.primary.withValues(alpha: 0.2),
      backgroundColor: NeonColors.surface,
      labelStyle: TextStyle(color: isSelected ? NeonColors.primary : NeonColors.textSecondary, fontSize: 11),
      side: BorderSide(color: isSelected ? NeonColors.primary : NeonColors.border),
    );
  }

  Widget _buildSummaryBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: NeonColors.textMuted, fontSize: 9)),
      ],
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'welcome');
    final valueCtrl = TextEditingController(text: '1000');
    final wageringCtrl = TextEditingController(text: '5');
    final minDepositCtrl = TextEditingController(text: '500');
    final maxBonusCtrl = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: const Text('Nouveau Bonus', style: TextStyle(color: NeonColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameCtrl, 'Nom du bonus', Icons.label),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: 'welcome',
                dropdownColor: NeonColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  labelStyle: TextStyle(color: NeonColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: NeonColors.border)),
                ),
                items: const [
                  DropdownMenuItem(value: 'welcome', child: Text('Bienvenue', style: TextStyle(color: NeonColors.textPrimary))),
                  DropdownMenuItem(value: 'deposit', child: Text('Depot', style: TextStyle(color: NeonColors.textPrimary))),
                  DropdownMenuItem(value: 'cashback', child: Text('Cashback', style: TextStyle(color: NeonColors.textPrimary))),
                  DropdownMenuItem(value: 'tournament', child: Text('Tournoi', style: TextStyle(color: NeonColors.textPrimary))),
                ],
                onChanged: (v) => typeCtrl.text = v ?? 'welcome',
              ),
              const SizedBox(height: 12),
              _buildTextField(valueCtrl, 'Valeur (FCFA)', Icons.monetization_on),
              const SizedBox(height: 12),
              _buildTextField(wageringCtrl, 'Wagering Requirement (x)', Icons.refresh),
              const SizedBox(height: 12),
              _buildTextField(minDepositCtrl, 'Depot Min (FCFA)', Icons.arrow_downward),
              const SizedBox(height: 12),
              _buildTextField(maxBonusCtrl, 'Bonus Max (FCFA)', Icons.arrow_upward),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final type = typeCtrl.text.trim();
              final value = double.tryParse(valueCtrl.text) ?? 0;
              final wagering = double.tryParse(wageringCtrl.text) ?? 0;
              final minDeposit = double.tryParse(minDepositCtrl.text) ?? 0;
              final maxBonus = double.tryParse(maxBonusCtrl.text) ?? 0;

              // Validation
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom du bonus est requis'), backgroundColor: NeonColors.error),
                );
                return;
              }
              if (value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La valeur doit être supérieure à 0'), backgroundColor: NeonColors.error),
                );
                return;
              }
              if (minDeposit > maxBonus) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le dépôt min ne peut pas dépasser le bonus max'), backgroundColor: NeonColors.error),
                );
                return;
              }

              if (!context.mounted) return;
              Navigator.pop(ctx);
              final success = await ref.read(adminBonusesManagementProvider.notifier).createBonus({
                'name': name,
                'type': type,
                'value': value,
                'wagering_requirement': wagering,
                'min_deposit': minDeposit,
                'max_bonus': maxBonus,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Bonus "$name" créé avec succès' : 'Erreur lors de la création du bonus'),
                    backgroundColor: success ? NeonColors.success : NeonColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: NeonColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeonColors.textSecondary),
        prefixIcon: Icon(icon, color: NeonColors.primary, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeonColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeonColors.primary),
        ),
      ),
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
            onPressed: () => ref.read(adminBonusesManagementProvider.notifier).loadBonuses(),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
          ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '0 FCFA';
    final amount = (value as num).toDouble();
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K FCFA';
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '-';
    }
  }

  bool _isExpired(String dateStr) {
    try {
      return DateTime.parse(dateStr).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}

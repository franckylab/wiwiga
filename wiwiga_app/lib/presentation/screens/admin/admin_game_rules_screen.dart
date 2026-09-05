// ============================================================
// Fichier: admin_game_rules_screen.dart
// Description: Écran admin des règles moteur (game_rules) — nombre de
//              sets fixe ou aléatoire (tirage serveur), par jeu et règle.
//              Source unique lue par GameMatch/GameRoom/Matchmaking.
// Auteur: WIWIGA Team
// Date: 2026-09-05
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/skeleton_loader.dart';
import '../../providers/admin_management_provider.dart';

/// Écran admin des règles moteur (nombre de sets).
class AdminGameRulesScreen extends ConsumerStatefulWidget {
  const AdminGameRulesScreen({super.key});

  @override
  ConsumerState<AdminGameRulesScreen> createState() =>
      _AdminGameRulesScreenState();
}

class _AdminGameRulesScreenState extends ConsumerState<AdminGameRulesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminGameRulesManagementProvider.notifier).loadRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminGameRulesManagementProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Sets & Règles Moteur'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
      ),
      body: state.isLoading
          ? const AdminSkeletonList(itemCount: 3)
          : state.error != null
              ? AdminErrorState(
                  error: state.error!,
                  onRetry: () => ref
                      .read(adminGameRulesManagementProvider.notifier)
                      .loadRules(),
                )
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminGameRulesState state) {
    if (state.rules.isEmpty) {
      return AdminEmptyState(
        icon: Icons.casino_outlined,
        title: 'Aucune règle moteur',
        actionLabel: 'Recharger',
        actionIcon: Icons.refresh,
        onAction: () => ref
            .read(adminGameRulesManagementProvider.notifier)
            .loadRules(),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(adminGameRulesManagementProvider.notifier).loadRules(),
      color: NeonColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.rules.length,
        itemBuilder: (context, index) {
          final rule = state.rules[index];
          final map = rule is Map<String, dynamic>
              ? rule
              : Map<String, dynamic>.from(rule as Map);
          return _buildRuleCard(map);
        },
      ),
    );
  }

  Map<String, dynamic> _setsOf(Map<String, dynamic> rule) {
    final sets = rule['sets'];
    if (sets is Map<String, dynamic>) return sets;
    if (sets is Map) return Map<String, dynamic>.from(sets);
    final config = rule['config'];
    final cfg = config is Map<String, dynamic>
        ? config
        : config is Map
            ? Map<String, dynamic>.from(config)
            : <String, dynamic>{};
    int intOf(String key, int fallback) {
      final value = cfg[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? fallback;
      return fallback;
    }

    final min = intOf('min_sets', 1);
    final max = intOf('max_sets', 11) >= min ? intOf('max_sets', 11) : min;
    final mode = cfg['sets_mode']?.toString() == 'random' ? 'random' : 'fixed';
    return {
      'mode': mode,
      'fixed': intOf('default_sets', 3).clamp(min, max),
      'random_min': intOf('sets_random_min', min).clamp(min, max),
      'random_max': intOf('sets_random_max', max)
          .clamp(intOf('sets_random_min', min).clamp(min, max), max),
      'min_sets': min,
      'max_sets': max,
      'default_sets': intOf('default_sets', 3).clamp(min, max),
    };
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final gameType = rule['game_type']?.toString() ?? '';
    final ruleType = rule['rule_type']?.toString() ?? '';
    final name = rule['name']?.toString() ?? ruleType;
    final sets = _setsOf(rule);
    final isRandom = sets['mode'] == 'random';
    final accent = isRandom ? NeonColors.secondary : NeonColors.primary;
    final setsLabel = isRandom
        ? ((sets['random_min'] == sets['random_max'])
            ? 'BO${sets['random_min']}'
            : 'Aléatoire (${sets['random_min']}–${sets['random_max']})')
        : 'BO${sets['fixed']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isRandom ? Icons.casino_outlined : Icons.looks_one_outlined,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${gameType.toUpperCase()} • $name',
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRandom
                          ? 'Tirage serveur à la création (équitable)'
                          : 'Nombre fixe pour toutes les parties',
                      style: const TextStyle(
                        color: NeonColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  setsLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('Min', '${sets['min_sets']}', NeonColors.textSecondary),
              _buildChip('Max', '${sets['max_sets']}', NeonColors.textSecondary),
              _buildChip(
                'Défaut',
                '${sets['default_sets']}',
                NeonColors.primary,
              ),
              if (isRandom) ...[
                _buildChip(
                  'Tirage min',
                  '${sets['random_min']}',
                  NeonColors.secondary,
                ),
                _buildChip(
                  'Tirage max',
                  '${sets['random_max']}',
                  NeonColors.secondary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showEditDialog(rule, sets),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(foregroundColor: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(
              color: NeonColors.textMuted,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> rule, Map<String, dynamic> sets) {
    final gameType = rule['game_type']?.toString() ?? '';
    final ruleType = rule['rule_type']?.toString() ?? '';
    var isRandom = sets['mode'] == 'random';

    final minCtrl =
        TextEditingController(text: '${sets['min_sets']}');
    final maxCtrl =
        TextEditingController(text: '${sets['max_sets']}');
    final defaultCtrl =
        TextEditingController(text: '${sets['default_sets']}');
    final randMinCtrl =
        TextEditingController(text: '${sets['random_min']}');
    final randMaxCtrl =
        TextEditingController(text: '${sets['random_max']}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.surface,
          title: Text(
            'Sets ${gameType.toUpperCase()} • $ruleType',
            style: const TextStyle(color: NeonColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sélecteur de mode : fixe ou tirage serveur
                const Text(
                  'Mode de détermination',
                  style: TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Fixe'),
                      icon: Icon(Icons.looks_one_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Aléatoire'),
                      icon: Icon(Icons.casino_outlined, size: 16),
                    ),
                  ],
                  selected: {isRandom},
                  onSelectionChanged: (selection) =>
                      setDialogState(() => isRandom = selection.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? NeonColors.primary.withValues(alpha: 0.2)
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStateProperty.all(
                      NeonColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildNumberField(minCtrl, 'Min sets', Icons.arrow_downward),
                const SizedBox(height: 12),
                _buildNumberField(maxCtrl, 'Max sets', Icons.arrow_upward),
                const SizedBox(height: 12),
                if (!isRandom)
                  _buildNumberField(
                    defaultCtrl,
                    'Sets par défaut (fixe)',
                    Icons.looks_3_outlined,
                  )
                else ...[
                  _buildNumberField(
                    randMinCtrl,
                    'Tirage min (intervalle)',
                    Icons.casino_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    randMaxCtrl,
                    'Tirage max (valeur maximale)',
                    Icons.casino_outlined,
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Le tirage utilise le générateur crypto du serveur. '
                  'En mode aléatoire, la valeur est tirée une fois à la '
                  'création et reste figée jusqu’à la fin de la partie.',
                  style: TextStyle(
                    color: NeonColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Annuler',
                style: TextStyle(color: NeonColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final min = int.tryParse(minCtrl.text.trim());
                final max = int.tryParse(maxCtrl.text.trim());
                final def = int.tryParse(defaultCtrl.text.trim());
                final rmin = int.tryParse(randMinCtrl.text.trim());
                final rmax = int.tryParse(randMaxCtrl.text.trim());
                final error = _validateSets(
                  isRandom: isRandom,
                  min: min,
                  max: max,
                  def: def,
                  rmin: rmin,
                  rmax: rmax,
                );
                if (error != null) {
                  context.showError(error);
                  return;
                }
                Navigator.pop(ctx);
                final patch = <String, dynamic>{
                  'min_sets': min!,
                  'max_sets': max!,
                  'sets_mode': isRandom ? 'random' : 'fixed',
                  if (!isRandom) 'default_sets': def!,
                  if (isRandom) 'sets_random_min': rmin!,
                  if (isRandom) 'sets_random_max': rmax!,
                };
                final success = await ref
                    .read(adminGameRulesManagementProvider.notifier)
                    .updateRule(gameType, ruleType, patch);
                if (mounted) {
                  context.showResult(
                    success,
                    successMsg: 'Règles $gameType/$ruleType mises à jour',
                    errorMsg: 'Erreur de sauvegarde',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonColors.primary,
              ),
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  /// Validation locale miroir du backend (le serveur revalide toujours).
  String? _validateSets({
    required bool isRandom,
    required int? min,
    required int? max,
    required int? def,
    required int? rmin,
    required int? rmax,
  }) {
    if (min == null || max == null) {
      return 'Min et Max doivent être des nombres entiers';
    }
    if (min < 1 || max > 99) {
      return 'Min/Max doivent être entre 1 et 99';
    }
    if (min > max) return 'Min doit être <= Max';
    if (!isRandom) {
      if (def == null) return 'Le défaut doit être un nombre entier';
      if (def < min || def > max) {
        return 'Le défaut doit être entre Min et Max';
      }
    } else {
      if (rmin == null || rmax == null) {
        return 'L’intervalle de tirage doit contenir des entiers';
      }
      if (rmin < min || rmax > max) {
        return 'L’intervalle doit rester dans [Min, Max]';
      }
      if (rmin > rmax) return 'Tirage min doit être <= Tirage max';
    }
    return null;
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: NeonColors.textPrimary),
      keyboardType: TextInputType.number,
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
}

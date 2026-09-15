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

  /// Timings de jeu par règle : tour (secondes), enchaînement auto des
  /// sets, grâce de sortie transport + transition tatami (ms).
  /// `turn_timeout_seconds` absent (null) = héritage du global existant
  /// (GameTimeoutConfig) — affiché « Auto ».
  /// Transition tatami : `roll_reveal_delay_ms` (révélation après fin d'anim
  /// 3D, jamais avant) + `roll_result_hold_delay_ms` (maintien avant overlay).
  /// Miroir des défauts backend (1800ms / 3000ms).
  Map<String, dynamic> _timingOf(Map<String, dynamic> rule) {
    final config = rule['config'];
    final cfg = config is Map<String, dynamic>
        ? config
        : config is Map
            ? Map<String, dynamic>.from(config)
            : <String, dynamic>{};
    int? intOrNull(String key, int min, int max) {
      final value = cfg[key];
      int? parsed;
      if (value is int) {
        parsed = value;
      } else if (value is num) {
        parsed = value.toInt();
      } else if (value is String) {
        parsed = int.tryParse(value.trim());
      }
      if (parsed == null) return null;
      return parsed.clamp(min, max);
    }

    int intOfMs(String key, int fallback, int min, int max) {
      final value = cfg[key];
      int parsed;
      if (value is int) {
        parsed = value;
      } else if (value is num) {
        parsed = value.toInt();
      } else if (value is String) {
        parsed = int.tryParse(value.trim()) ?? fallback;
      } else {
        parsed = fallback;
      }
      return parsed.clamp(min, max);
    }

    return {
      'turn_timeout_seconds': intOrNull('turn_timeout_seconds', 10, 300),
      'auto_next_set_delay_seconds':
          intOrNull('auto_next_set_delay_seconds', 2, 15) ?? 4,
      'leave_grace_seconds': intOrNull('leave_grace_seconds', 5, 120) ?? 20,
      'roll_reveal_delay_ms': intOfMs('roll_reveal_delay_ms', 1800, 500, 5000),
      'roll_result_hold_delay_ms':
          intOfMs('roll_result_hold_delay_ms', 3000, 1000, 10000),
    };
  }

  /// Paramètres de vote cible (règle cible uniquement) : timer global
  /// synchrone, délai d'affichage du résultat, mode de calcul.
  /// Valeurs miroir des défauts backend (20s / 5s / average).
  Map<String, dynamic> _voteOf(Map<String, dynamic> rule) {
    final config = rule['config'];
    final cfg = config is Map<String, dynamic>
        ? config
        : config is Map
            ? Map<String, dynamic>.from(config)
            : <String, dynamic>{};
    int intOf(String key, int fallback, int min, int max) {
      final value = cfg[key];
      int parsed;
      if (value is int) {
        parsed = value;
      } else if (value is num) {
        parsed = value.toInt();
      } else if (value is String) {
        parsed = int.tryParse(value.trim()) ?? fallback;
      } else {
        parsed = fallback;
      }
      return parsed.clamp(min, max);
    }

    final mode = cfg['target_vote_mode']?.toString() == 'mode'
        ? 'mode'
        : 'average';
    return {
      'vote_timeout_seconds': intOf('vote_timeout_seconds', 20, 5, 120),
      'vote_result_delay_seconds':
          intOf('vote_result_delay_seconds', 5, 2, 30),
      'target_vote_mode': mode,
    };
  }

  /// Paramètres gameplay moteur lus depuis `config` (dés, joueurs,
  /// mises règle, commission, égalité). Miroir des défauts backend.
  Map<String, dynamic> _gameplayOf(Map<String, dynamic> rule) {
    final config = rule['config'];
    final cfg = config is Map<String, dynamic>
        ? config
        : config is Map
            ? Map<String, dynamic>.from(config)
            : <String, dynamic>{};
    int intOf(String key, int fallback, int min, int max) {
      final value = cfg[key];
      int parsed;
      if (value is int) {
        parsed = value;
      } else if (value is num) {
        parsed = value.toInt();
      } else if (value is String) {
        parsed = int.tryParse(value.trim()) ?? fallback;
      } else {
        parsed = fallback;
      }
      return parsed.clamp(min, max);
    }

    double doubleOf(String key, double fallback, double min, double max) {
      final value = cfg[key];
      double parsed;
      if (value is num) {
        parsed = value.toDouble();
      } else if (value is String) {
        parsed = double.tryParse(value.trim()) ?? fallback;
      } else {
        parsed = fallback;
      }
      return parsed.clamp(min, max);
    }

    return {
      'min_dice': intOf('min_dice', 1, 1, 10),
      'max_dice': intOf('max_dice', 2, 1, 10),
      'default_dice': intOf('default_dice', 2, 1, 10),
      'dice_faces': intOf('dice_faces', 6, 4, 20),
      'min_players': intOf('min_players', 2, 2, 10),
      'max_players': intOf('max_players', 5, 2, 10),
      'min_bet': intOf('min_bet', 100, 0, 10000000),
      'max_bet': intOf('max_bet', 50000, 0, 10000000),
      'commission_rate': doubleOf('commission_rate', 0.05, 0.0, 1.0),
      'tie_rule': cfg['tie_rule']?.toString() == 'no_winner' ? 'no_winner' : 'replay',
    };
  }

  Map<String, dynamic> _setsOf(Map<String, dynamic> rule) {    final sets = rule['sets'];
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
    final isCible = ruleType == 'cible';
    final timing = _timingOf(rule);
    final turnLabel = timing['turn_timeout_seconds'] == null
        ? 'Auto'
        : '${timing['turn_timeout_seconds']}s';
    final vote = isCible ? _voteOf(rule) : <String, dynamic>{};
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
              _buildChip('Tour', turnLabel, NeonColors.primary),
              _buildChip(
                'Set suivant',
                '${timing['auto_next_set_delay_seconds']}s',
                NeonColors.textSecondary,
              ),
              _buildChip(
                'Grâce sortie',
                '${timing['leave_grace_seconds']}s',
                NeonColors.textSecondary,
              ),
              _buildChip(
                'Révélation',
                '${timing['roll_reveal_delay_ms']}ms',
                NeonColors.accent,
              ),
              _buildChip(
                'Maintien',
                '${timing['roll_result_hold_delay_ms']}ms',
                NeonColors.accent,
              ),
              if (isCible) ...[
                _buildChip(
                  'Vote',
                  '${vote['vote_timeout_seconds']}s',
                  NeonColors.secondary,
                ),
                _buildChip(
                  'Résultat',
                  '${vote['vote_result_delay_seconds']}s',
                  NeonColors.secondary,
                ),
                _buildChip(
                  'Mode',
                  '${vote['target_vote_mode']}',
                  NeonColors.primary,
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
    final isCible = ruleType == 'cible';
    final vote = isCible ? _voteOf(rule) : <String, dynamic>{};
    var isRandom = sets['mode'] == 'random';
    var voteIsMode = vote['target_vote_mode'] == 'mode';

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
    final voteTimeoutCtrl = TextEditingController(
      text: '${vote['vote_timeout_seconds'] ?? 20}',
    );
    final voteDelayCtrl = TextEditingController(
      text: '${vote['vote_result_delay_seconds'] ?? 5}',
    );
    final timing = _timingOf(rule);
    final turnTimeoutCtrl = TextEditingController(
      text: timing['turn_timeout_seconds'] == null
          ? ''
          : '${timing['turn_timeout_seconds']}',
    );
    final autoNextCtrl = TextEditingController(
      text: '${timing['auto_next_set_delay_seconds']}',
    );
    final leaveGraceCtrl = TextEditingController(
      text: '${timing['leave_grace_seconds']}',
    );
    // Transition tatami (ms) : révélation après fin d'anim + maintien avant
    // overlay. Miroir des bornes backend (500–5000 / 1000–10000).
    final revealDelayCtrl = TextEditingController(
      text: '${timing['roll_reveal_delay_ms']}',
    );
    final holdDelayCtrl = TextEditingController(
      text: '${timing['roll_result_hold_delay_ms']}',
    );
    // Gameplay moteur (dés, joueurs, mises règle, commission, égalité).
    // Miroir des bornes backend (changeset GameRule + endpoint admin).
    final gameplay = _gameplayOf(rule);
    var tieIsReplay = (gameplay['tie_rule']?.toString() ?? 'replay') != 'no_winner';
    final minDiceCtrl = TextEditingController(text: '${gameplay['min_dice']}');
    final maxDiceCtrl = TextEditingController(text: '${gameplay['max_dice']}');
    final defDiceCtrl = TextEditingController(text: '${gameplay['default_dice']}');
    final facesCtrl = TextEditingController(text: '${gameplay['dice_faces']}');
    final minPlayersCtrl = TextEditingController(text: '${gameplay['min_players']}');
    final maxPlayersCtrl = TextEditingController(text: '${gameplay['max_players']}');
    final minBetCtrl = TextEditingController(text: '${gameplay['min_bet']}');
    final maxBetCtrl = TextEditingController(text: '${gameplay['max_bet']}');
    final commissionCtrl = TextEditingController(
      text: '${((gameplay['commission_rate'] as num?)?.toDouble() ?? 0.05) * 100}',
    );

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
                const SizedBox(height: 20),
                const Text(
                  'Temps de jeu (secondes)',
                  style: TextStyle(
                    color: NeonColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  turnTimeoutCtrl,
                  'Tour par joueur (10–300, vide = auto)',
                  Icons.timer_outlined,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  autoNextCtrl,
                  'Set suivant auto (2–15)',
                  Icons.skip_next_outlined,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  leaveGraceCtrl,
                  'Grâce sortie transport (5–120)',
                  Icons.wifi_off_outlined,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  revealDelayCtrl,
                  'Révélation tatami (ms, 500–5000)',
                  Icons.visibility_outlined,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  holdDelayCtrl,
                  'Maintien résultat (ms, 1000–10000)',
                  Icons.hourglass_bottom_outlined,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Révélation = attente fin d’animation 3D avant la somme '
                  '(jamais avant). Maintien = temps où faces + somme restent '
                  'visibles avant l’overlay de set/match.',
                  style: TextStyle(
                    color: NeonColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vide = héritage du global (écran « Timeouts Globaux »). '
                  'Les matchs en cours gardent leurs valeurs gelées ; les '
                  'nouveaux matchs appliquent la nouvelle config.',
                  style: TextStyle(
                    color: NeonColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Dés & joueurs (moteur)',
                  style: TextStyle(
                    color: NeonColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNumberField(minDiceCtrl, 'Dés min (1–10)', Icons.arrow_downward),
                const SizedBox(height: 12),
                _buildNumberField(maxDiceCtrl, 'Dés max (1–10)', Icons.arrow_upward),
                const SizedBox(height: 12),
                _buildNumberField(defDiceCtrl, 'Dés par défaut', Icons.casino_outlined),
                const SizedBox(height: 12),
                _buildNumberField(facesCtrl, 'Faces par dé (4–20)', Icons.hexagon_outlined),
                const SizedBox(height: 12),
                _buildNumberField(minPlayersCtrl, 'Joueurs min (2–10)', Icons.person_outline),
                const SizedBox(height: 12),
                _buildNumberField(maxPlayersCtrl, 'Joueurs max (2–10)', Icons.people_outline),
                const SizedBox(height: 20),
                const Text(
                  'Mises & commission (moteur)',
                  style: TextStyle(
                    color: NeonColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNumberField(minBetCtrl, 'Mise min règle (jetons)', Icons.arrow_downward),
                const SizedBox(height: 12),
                _buildNumberField(maxBetCtrl, 'Mise max règle (jetons)', Icons.arrow_upward),
                const SizedBox(height: 12),
                _buildNumberField(commissionCtrl, 'Commission règle (% 0–100)', Icons.percent_outlined),
                const SizedBox(height: 8),
                const Text(
                  'Moteur : ces bornes valident la création des matchs ; le '
                  'catalogue (écran Config. Jeux) reste l\u2019affichage. La '
                  'commission est gelée par match au démarrage.',
                  style: TextStyle(
                    color: NeonColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Set nul (égalité)',
                  style: TextStyle(
                    color: NeonColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Rejouer'),
                      icon: Icon(Icons.replay_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Sans gagnant'),
                      icon: Icon(Icons.block_outlined, size: 16),
                    ),
                  ],
                  selected: {tieIsReplay},
                  onSelectionChanged: (selection) =>
                      setDialogState(() => tieIsReplay = selection.first),
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
                if (isCible) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Vote cible (timer global synchrone)',
                    style: TextStyle(
                      color: NeonColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mode de calcul',
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
                        label: Text('Moyenne'),
                        icon: Icon(Icons.functions_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Mode'),
                        icon: Icon(Icons.bar_chart_outlined, size: 16),
                      ),
                    ],
                    selected: {voteIsMode},
                    onSelectionChanged: (selection) =>
                        setDialogState(() => voteIsMode = selection.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? NeonColors.secondary.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      foregroundColor: WidgetStateProperty.all(
                        NeonColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    voteTimeoutCtrl,
                    'Timer de vote (secondes, 5–120)',
                    Icons.timer_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    voteDelayCtrl,
                    'Affichage résultat (secondes, 2–30)',
                    Icons.visibility_outlined,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'À expiration du timer, les joueurs sans vote se voient '
                    'attribuer automatiquement leur position de sélecteur '
                    '(filet serveur : valeur médiane). Le résultat reste '
                    'affiché le temps configuré avant reprise auto.',
                    style: TextStyle(
                      color: NeonColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
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
                int? voteTimeout;
                int? voteDelay;
                if (isCible) {
                  voteTimeout = int.tryParse(voteTimeoutCtrl.text.trim());
                  voteDelay = int.tryParse(voteDelayCtrl.text.trim());
                  final voteError = _validateVote(
                    timeout: voteTimeout,
                    delay: voteDelay,
                  );
                  if (voteError != null) {
                    context.showError(voteError);
                    return;
                  }
                }
                // Tour vide = héritage global (clé omise du patch).
                final turnText = turnTimeoutCtrl.text.trim();
                final int? turnTimeout =
                    turnText.isEmpty ? null : int.tryParse(turnText);
                if (turnText.isNotEmpty && turnTimeout == null) {
                  context.showError('Le tour doit être un entier ou vide');
                  return;
                }
                final autoNext = int.tryParse(autoNextCtrl.text.trim());
                final leaveGrace = int.tryParse(leaveGraceCtrl.text.trim());
                final revealDelay = int.tryParse(revealDelayCtrl.text.trim());
                final holdDelay = int.tryParse(holdDelayCtrl.text.trim());
                final timingError = _validateTimings(
                  turnTimeout: turnTimeout,
                  autoNext: autoNext,
                  leaveGrace: leaveGrace,
                  revealDelay: revealDelay,
                  holdDelay: holdDelay,
                );
                if (timingError != null) {
                  context.showError(timingError);
                  return;
                }
                final minDice = int.tryParse(minDiceCtrl.text.trim());
                final maxDice = int.tryParse(maxDiceCtrl.text.trim());
                final defDice = int.tryParse(defDiceCtrl.text.trim());
                final faces = int.tryParse(facesCtrl.text.trim());
                final minPlayers = int.tryParse(minPlayersCtrl.text.trim());
                final maxPlayers = int.tryParse(maxPlayersCtrl.text.trim());
                final minBet = int.tryParse(minBetCtrl.text.trim());
                final maxBet = int.tryParse(maxBetCtrl.text.trim());
                final commissionPct = double.tryParse(commissionCtrl.text.trim().replaceAll(',', '.'));
                final gameplayError = _validateGameplay(
                  minDice: minDice,
                  maxDice: maxDice,
                  defDice: defDice,
                  faces: faces,
                  minPlayers: minPlayers,
                  maxPlayers: maxPlayers,
                  minBet: minBet,
                  maxBet: maxBet,
                  commissionPct: commissionPct,
                );
                if (gameplayError != null) {
                  context.showError(gameplayError);
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
                  // null = retour à l'héritage global (clé supprimée côté
                  // serveur). Toujours envoyé pour permettre la réinitialisation.
                  'turn_timeout_seconds': turnTimeout,
                  'auto_next_set_delay_seconds': autoNext!,
                  'leave_grace_seconds': leaveGrace!,
                  'roll_reveal_delay_ms': revealDelay!,
                  'roll_result_hold_delay_ms': holdDelay!,
                  'min_dice': minDice!,
                  'max_dice': maxDice!,
                  'default_dice': defDice!,
                  'dice_faces': faces!,
                  'min_players': minPlayers!,
                  'max_players': maxPlayers!,
                  'min_bet': minBet!,
                  'max_bet': maxBet!,
                  'commission_rate': commissionPct! / 100,
                  'tie_rule': tieIsReplay ? 'replay' : 'no_winner',
                  if (isCible) ...{
                    'target_vote_mode': voteIsMode ? 'mode' : 'average',
                    'vote_timeout_seconds': voteTimeout!,
                    'vote_result_delay_seconds': voteDelay!,
                  },
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

  /// Validation gameplay moteur, miroir du backend.
  String? _validateGameplay({
    required int? minDice,
    required int? maxDice,
    required int? defDice,
    required int? faces,
    required int? minPlayers,
    required int? maxPlayers,
    required int? minBet,
    required int? maxBet,
    required double? commissionPct,
  }) {
    if (minDice == null || maxDice == null || minDice < 1 || maxDice > 10) {
      return 'Dés : 1–10';
    }
    if (minDice > maxDice) return 'Dés min doit être <= max';
    if (defDice == null || defDice < minDice || defDice > maxDice) {
      return 'Dés par défaut dans [Min, Max]';
    }
    if (faces == null || faces < 4 || faces > 20) return 'Faces : 4–20';
    if (minPlayers == null ||
        maxPlayers == null ||
        minPlayers < 2 ||
        maxPlayers > 10) {
      return 'Joueurs : 2–10';
    }
    if (minPlayers > maxPlayers) return 'Joueurs min doit être <= max';
    if (minBet == null || maxBet == null || minBet < 0 || maxBet > 10000000) {
      return 'Mises : 0–10 000 000';
    }
    if (minBet > maxBet) return 'Mise min doit être <= max';
    if (commissionPct == null || commissionPct < 0 || commissionPct > 100) {
      return 'Commission : 0–100 %';
    }
    return null;
  }

  /// Validation locale miroir du backend (le serveur revalide toujours).
  String? _validateSets({    required bool isRandom,
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

  /// Validation locale du vote cible, miroir du backend (5–120s / 2–30s).
  String? _validateVote({required int? timeout, required int? delay}) {
    if (timeout == null) return 'Le timer de vote doit être un entier';
    if (timeout < 5 || timeout > 120) {
      return 'Le timer de vote doit être entre 5 et 120 secondes';
    }
    if (delay == null) return 'Le délai résultat doit être un entier';
    if (delay < 2 || delay > 30) {
      return 'Le délai résultat doit être entre 2 et 30 secondes';
    }
    return null;
  }

  /// Validation locale des timings, miroir du backend. `turnTimeout` null
  /// = héritage global (valide, clé omise du patch).
  /// Transition tatami (ms) : révélation 500–5000, maintien 1000–10000.
  String? _validateTimings({
    required int? turnTimeout,
    required int? autoNext,
    required int? leaveGrace,
    required int? revealDelay,
    required int? holdDelay,
  }) {
    if (turnTimeout != null && (turnTimeout < 10 || turnTimeout > 300)) {
      return 'Le tour doit être entre 10 et 300 secondes (ou vide = auto)';
    }
    if (autoNext == null) return 'Le délai set suivant doit être un entier';
    if (autoNext < 2 || autoNext > 15) {
      return 'Le délai set suivant doit être entre 2 et 15 secondes';
    }
    if (leaveGrace == null) return 'La grâce sortie doit être un entier';
    if (leaveGrace < 5 || leaveGrace > 120) {
      return 'La grâce sortie doit être entre 5 et 120 secondes';
    }
    if (revealDelay == null) return 'La révélation doit être un entier (ms)';
    if (revealDelay < 500 || revealDelay > 5000) {
      return 'La révélation doit être entre 500 et 5000 ms';
    }
    if (holdDelay == null) return 'Le maintien doit être un entier (ms)';
    if (holdDelay < 1000 || holdDelay > 10000) {
      return 'Le maintien doit être entre 1000 et 10000 ms';
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

// ============================================================
// Fichier: admin_games_overview_screen.dart
// Description: Hub central « Jeux — Vue d'ensemble » : configuration
//              EFFECTIVE de chaque couple jeu × règle (lecture seule).
//              Fusionne game_rules + game_configs + timeouts + xp en miroir
//              des chaînes de résolution du moteur, chaque valeur étant
//              annotée de sa source. L'écriture reste sur les écrans
//              spécialisés (liens directs par carte).
// Auteur: WIWIGA Team
// Date: 2026-09-08
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/skeleton_loader.dart';
import '../../widgets/neon/neon_card.dart';
import '../../providers/admin_management_provider.dart';

/// Hub central de configuration des jeux (lecture seule + liens d'édition).
class AdminGamesOverviewScreen extends ConsumerWidget {
  const AdminGamesOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(adminEffectiveGameConfigsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text("Jeux — Vue d'ensemble"),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
      ),
      body: configsAsync.when(
        loading: () => const AdminSkeletonList(itemCount: 2),
        error: (e, _) => AdminErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(adminEffectiveGameConfigsProvider),
        ),
        data: (configs) {
          if (configs.isEmpty) {
            return AdminEmptyState(
              icon: Icons.casino_outlined,
              title: 'Aucune règle active',
              actionLabel: 'Recharger',
              actionIcon: Icons.refresh,
              onAction: () =>
                  ref.invalidate(adminEffectiveGameConfigsProvider),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminEffectiveGameConfigsProvider),
            color: NeonColors.primary,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: configs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildIntro();
                final item = configs[index - 1];
                final map = item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map);
                return _buildGameCard(context, map);
              },
            ),
          );
        },
      ),
    );
  }

  /// Bandeau expliquant la centralisation (pourquoi plusieurs écrans).
  Widget _buildIntro() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: NeonColors.primary,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Valeurs réellement appliquées en partie, avec leur source : '
              'Règle moteur, Catalogue, Global ou Défaut code. '
              'La modification se fait dans les écrans spécialisés.',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, Map<String, dynamic> cfg) {
    final gameType = cfg['game_type']?.toString() ?? '?';
    final ruleType = cfg['rule_type']?.toString() ?? '?';
    final ruleName = cfg['rule_name']?.toString() ?? '$gameType/$ruleType';
    final active = cfg['rule_active'] == true;
    final vote =
        cfg['vote'] is Map ? Map<String, dynamic>.from(cfg['vote'] as Map) : null;

    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$gameType · $ruleType'.toUpperCase(),
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(
                  label: active ? 'Actif' : 'Inactif',
                  color: active ? NeonColors.success : NeonColors.error,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              ruleName,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Sets',
              icon: Icons.layers_outlined,
              children: _annotatedChildren(
                cfg['sets'] as Map?,
                const {
                  'mode': 'Mode',
                  'min': 'Min',
                  'max': 'Max',
                  'default': 'Défaut',
                  'random_min': 'Aléa min',
                  'random_max': 'Aléa max',
                },
              ),
            ),
            _Section(
              title: 'Dés',
              icon: Icons.casino_outlined,
              children: _annotatedChildren(
                cfg['dice'] as Map?,
                const {
                  'min': 'Min',
                  'max': 'Max',
                  'default': 'Défaut',
                  'faces': 'Faces',
                },
              ),
            ),
            _Section(
              title: 'Mises (jetons)',
              icon: Icons.monetization_on,
              hint: 'Création bornée par la règle, mise validée contre le catalogue.',
              children: _annotatedChildren(
                cfg['bets'] as Map?,
                const {
                  'rule_min': 'Règle min',
                  'rule_max': 'Règle max',
                  'catalog_min': 'Catalogue min',
                  'catalog_max': 'Catalogue max',
                  'catalog_min_tokens': 'Catalogue min (tickets)',
                },
              ),
            ),
            _Section(
              title: 'Commission',
              icon: Icons.percent,
              hint: 'Taux gelé par match depuis la règle.',
              children: _annotatedChildren(
                cfg['commission'] as Map?,
                const {
                  'rule_rate': 'Règle (taux)',
                  'catalog_rate': 'Catalogue (taux)',
                  'catalog_mode': 'Catalogue (mode)',
                },
                percentKeys: const {'rule_rate', 'catalog_rate'},
              ),
            ),
            _Section(
              title: 'Délais',
              icon: Icons.timer_outlined,
              children: [
                ..._annotatedChildren(
                  cfg['timeouts'] as Map?,
                  const {
                    'turn_seconds': 'Tour (s)',
                    'auto_next_set_seconds': 'Enchaînement (s)',
                    'leave_grace_seconds': 'Grâce sortie (s)',
                  },
                ),
                if (vote != null)
                  ..._annotatedChildren(
                    vote,
                    const {
                      'target_vote_mode': 'Vote (mode)',
                      'vote_timeout_seconds': 'Vote (s)',
                      'vote_result_delay_seconds': 'Résultat vote (s)',
                    },
                  ),
              ],
            ),
            _Section(
              title: 'Joueurs',
              icon: Icons.group_outlined,
              children: _annotatedChildren(
                cfg['players'] as Map?,
                const {'min': 'Min', 'max': 'Max'},
              ),
            ),
            _Section(
              title: 'Affichage catalogue',
              icon: Icons.visibility_outlined,
              children: _annotatedChildren(
                cfg['display'] as Map?,
                const {
                  'name': 'Nom',
                  'enabled': 'Activé',
                  'coming_soon': 'Bientôt',
                  'display_order': 'Ordre',
                },
              ),
            ),
            _Section(
              title: 'XP',
              icon: Icons.stars,
              children: _annotatedChildren(
                cfg['xp'] as Map?,
                const {
                  'win': 'Victoire',
                  'loss': 'Défaite',
                  'draw': 'Nul',
                  'participation': 'Participation',
                  'streak_bonus': 'Bonus série',
                  'max_streak_bonus': 'Série max',
                  'xp_multiplier': 'Multiplicateur',
                  'active': 'Actif',
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EditLink(
                  label: 'Sets & règles',
                  icon: Icons.casino_outlined,
                  onTap: () => context.go('/admin/game-rules'),
                ),
                _EditLink(
                  label: 'Catalogue & mises',
                  icon: Icons.tune,
                  onTap: () => context.go('/admin/game-config'),
                ),
                _EditLink(
                  label: 'Timeouts',
                  icon: Icons.timer_outlined,
                  onTap: () => context.go('/admin/game-timeouts'),
                ),
                _EditLink(
                  label: 'Règles XP',
                  icon: Icons.stars,
                  onTap: () => context.go('/admin/xp-rules'),
                ),
              ],
            ),
          ],
        ),
      );
  }

  /// Lignes `label : valeur [source]` pour un bloc annoté.
  List<Widget> _annotatedChildren(
    Map? block,
    Map<String, String> labels, {
    Set<String> percentKeys = const {},
  }) {
    if (block == null) return const [];
    final rows = <Widget>[];
    labels.forEach((key, label) {
      final node = block[key];
      if (node is! Map) return;
      final raw = node['value'];
      final source = node['source']?.toString() ?? 'absent';
      rows.add(
        _AnnotatedRow(
          label: label,
          value: _formatValue(raw, percent: percentKeys.contains(key)),
          source: source,
        ),
      );
    });
    return rows;
  }

  String _formatValue(dynamic raw, {bool percent = false}) {
    if (raw == null) return '—';
    if (raw is bool) return raw ? 'Oui' : 'Non';
    if (percent && raw is num) {
      return '${(raw * 100).toStringAsFixed(raw < 0.1 ? 1 : 0)} %';
    }
    return raw.toString();
  }
}

/// Section repliable visuellement (titre + lignes).
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? hint;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NeonColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: NeonColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: NeonColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// Ligne `label : valeur` + pastille de source.
class _AnnotatedRow extends StatelessWidget {
  final String label;
  final String value;
  final String source;

  const _AnnotatedRow({
    required this.label,
    required this.value,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          _SourceChip(source: source),
        ],
      ),
    );
  }
}

/// Pastille de source (couleur par origine).
class _SourceChip extends StatelessWidget {
  final String source;

  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final short = _shortSource(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: short.$2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: short.$2.withValues(alpha: 0.4)),
      ),
      child: Text(
        short.$1,
        style: TextStyle(
          color: short.$2,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Libellé court + couleur par origine de la valeur.
  (String, Color) _shortSource(String source) {
    if (source.startsWith('game_rules.')) {
      return ('Règle', NeonColors.primary);
    }
    if (source.startsWith('game_configs.')) {
      return ('Catalogue', NeonColors.secondary);
    }
    if (source.startsWith('game_timeout_configs.')) {
      return ('Global', NeonColors.accent);
    }
    if (source.startsWith('xp_rules.')) {
      return ('XP', NeonColors.success);
    }
    if (source == 'absent') {
      return ('Non défini', NeonColors.warning);
    }
    return ('Défaut', NeonColors.textSecondary);
  }
}

/// Pastille de statut actif/inactif.
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Bouton de lien vers un écran d'édition spécialisé.
class _EditLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _EditLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: NeonColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: NeonColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: NeonColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: NeonColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Fichier: admin_game_timeout_screen.dart
// Description: Écran admin des timeouts GLOBAUX (game_timeout_configs) —
//              repli utilisé quand une règle ne fige pas son propre
//              `turn_timeout_seconds` (champ vide = héritage global).
//              Prend effet sur les nouveaux matchs (valeurs gelées).
// Auteur: WIWIGA Team
// Date: 2026-09-08
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/skeleton_loader.dart';
import '../../providers/admin_management_provider.dart';

/// Écran admin des timeouts globaux (grâce, action, reconnexion).
class AdminGameTimeoutScreen extends ConsumerStatefulWidget {
  const AdminGameTimeoutScreen({super.key});

  @override
  ConsumerState<AdminGameTimeoutScreen> createState() =>
      _AdminGameTimeoutScreenState();
}

class _AdminGameTimeoutScreenState
    extends ConsumerState<AdminGameTimeoutScreen> {
  static const List<String> _actions = ['forfeit', 'refund', 'pause'];
  static const List<String> _distributions = ['to_winner', 'split', 'pool'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminGameTimeoutManagementProvider.notifier).loadTimeouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminGameTimeoutManagementProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Timeouts Globaux'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
      ),
      body: state.isLoading
          ? const AdminSkeletonList(itemCount: 2)
          : state.error != null
              ? AdminErrorState(
                  error: state.error!,
                  onRetry: () => ref
                      .read(adminGameTimeoutManagementProvider.notifier)
                      .loadTimeouts(),
                )
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminGameTimeoutState state) {
    if (state.timeouts.isEmpty) {
      return AdminEmptyState(
        icon: Icons.timer_outlined,
        title: 'Aucun timeout global',
        actionLabel: 'Recharger',
        actionIcon: Icons.refresh,
        onAction: () => ref
            .read(adminGameTimeoutManagementProvider.notifier)
            .loadTimeouts(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(adminGameTimeoutManagementProvider.notifier)
          .loadTimeouts(),
      color: NeonColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.timeouts.length,
        itemBuilder: (context, index) {
          final item = state.timeouts[index];
          final map = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map);
          return _buildTimeoutCard(map);
        },
      ),
    );
  }

  Widget _buildTimeoutCard(Map<String, dynamic> item) {
    final gameType = item['game_type']?.toString() ?? '';
    final grace = item['grace_period_seconds'];
    final action = item['action_on_timeout']?.toString() ?? 'forfeit';
    final distribution =
        item['forfeit_distribution']?.toString() ?? 'to_winner';
    final reconnect = item['reconnect_allowed'] == true;
    final maxAttempts = item['max_reconnect_attempts']?.toString() ?? '3';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonColors.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NeonColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: NeonColors.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameType.toUpperCase(),
                      style: const TextStyle(
                        color: NeonColors.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Repli des règles sans tour configuré',
                      style: TextStyle(
                        color: NeonColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: NeonColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: NeonColors.secondary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${grace}s',
                  style: const TextStyle(
                    color: NeonColors.secondary,
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
              _buildChip('Action', action, NeonColors.primary),
              _buildChip(
                'Distribution',
                distribution,
                NeonColors.textSecondary,
              ),
              _buildChip(
                'Reconnexion',
                reconnect ? 'oui ($maxAttempts)' : 'non',
                reconnect
                    ? NeonColors.success
                    : NeonColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showEditDialog(item),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(
                foregroundColor: NeonColors.secondary,
              ),
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

  void _showEditDialog(Map<String, dynamic> item) {
    final gameType = item['game_type']?.toString() ?? '';
    var action = item['action_on_timeout']?.toString() ?? 'forfeit';
    if (!_actions.contains(action)) action = 'forfeit';
    var distribution =
        item['forfeit_distribution']?.toString() ?? 'to_winner';
    if (!_distributions.contains(distribution)) distribution = 'to_winner';
    var reconnect = item['reconnect_allowed'] != false;

    final graceCtrl = TextEditingController(
      text: '${item['grace_period_seconds'] ?? 120}',
    );
    final attemptsCtrl = TextEditingController(
      text: '${item['max_reconnect_attempts'] ?? 3}',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.surface,
          title: Text(
            'Timeouts $gameType',
            style: const TextStyle(color: NeonColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNumberField(
                  graceCtrl,
                  'Grâce / tour (secondes, 10–300)',
                  Icons.timer_outlined,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Action au timeout',
                  style: TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'forfeit',
                      label: Text('Forfait'),
                    ),
                    ButtonSegment(
                      value: 'refund',
                      label: Text('Rembours.'),
                    ),
                    ButtonSegment(
                      value: 'pause',
                      label: Text('Pause'),
                    ),
                  ],
                  selected: {action},
                  onSelectionChanged: (selection) =>
                      setDialogState(() => action = selection.first),
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
                const Text(
                  'Distribution du forfait',
                  style: TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: distribution,
                  dropdownColor: NeonColors.surface,
                  style: const TextStyle(color: NeonColors.textPrimary),
                  decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: NeonColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: NeonColors.secondary),
                    ),
                  ),
                  items: _distributions
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text(d)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => distribution = v);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Reconnexion autorisée',
                    style: TextStyle(
                      color: NeonColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  value: reconnect,
                  activeThumbColor: NeonColors.secondary,
                  onChanged: (v) => setDialogState(() => reconnect = v),
                ),
                _buildNumberField(
                  attemptsCtrl,
                  'Tentatives reconnexion (≥ 1)',
                  Icons.refresh,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prend effet sur les nouveaux matchs (valeurs gelées). '
                  'La grâce sert aussi de délai de tour par défaut.',
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
                final grace = int.tryParse(graceCtrl.text.trim());
                final attempts = int.tryParse(attemptsCtrl.text.trim());
                if (grace == null || grace < 10 || grace > 300) {
                  context.showError(
                    'La grâce doit être entre 10 et 300 secondes',
                  );
                  return;
                }
                if (attempts == null || attempts < 1) {
                  context.showError(
                    'Les tentatives doivent être un entier ≥ 1',
                  );
                  return;
                }
                Navigator.pop(ctx);
                final success = await ref
                    .read(adminGameTimeoutManagementProvider.notifier)
                    .updateTimeout(gameType, {
                  'grace_period_seconds': grace,
                  'action_on_timeout': action,
                  'forfeit_distribution': distribution,
                  'reconnect_allowed': reconnect,
                  'max_reconnect_attempts': attempts,
                });
                if (mounted) {
                  context.showResult(
                    success,
                    successMsg: 'Timeouts $gameType mis à jour',
                    errorMsg: 'Erreur de sauvegarde',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonColors.secondary,
              ),
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
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
        prefixIcon: Icon(icon, color: NeonColors.secondary, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeonColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeonColors.secondary),
        ),
      ),
    );
  }
}

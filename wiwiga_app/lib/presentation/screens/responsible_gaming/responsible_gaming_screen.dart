// ============================================================
// Fichier: responsible_gaming_screen.dart
// Description: Hub Jeu Responsable — limites (mises, pertes, activité),
//   usage du jour, pause courte et auto-exclusion. Valeurs en jetons,
//   durées en minutes. Hausse différée 24h (baisse immédiate).
// Auteur: WIWIGA Team
// Date: 2026-09-06
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/responsible_gaming_provider.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';

/// Hub Jeu Responsable (route `/responsible-gaming/limits`).
class ResponsibleGamingScreen extends ConsumerStatefulWidget {
  const ResponsibleGamingScreen({super.key});

  @override
  ConsumerState<ResponsibleGamingScreen> createState() =>
      _ResponsibleGamingScreenState();
}

class _ResponsibleGamingScreenState
    extends ConsumerState<ResponsibleGamingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(responsibleGamingProvider.notifier).loadLimits(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(responsibleGamingProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Jeu Responsable'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: NeonColors.primary,
        onRefresh: () =>
            ref.read(responsibleGamingProvider.notifier).loadLimits(),
        child: state.isLoading && state.dailyLossLimit == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: NeonColors.primary,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.isSelfExcluded || state.isCoolingOff)
                    _buildPauseBanner(state),
                  if (state.hasPendingIncrease)
                    _buildPendingBanner(state),
                  _buildSectionTitle('Aujourd\'hui', Icons.today_outlined),
                  _buildUsageCard(state),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Mises (jetons)', Icons.monetization_on),
                  _buildLimitTile(
                    title: 'Mise max par coup',
                    subtitle: _valueOrUnset(
                      state.maxBetAmount,
                      (v) => '$v jetons',
                    ),
                    onTap: () => _editInt(
                      title: 'Mise max par coup (jetons)',
                      initial: state.maxBetAmount,
                      hint: 'Ex : 5000',
                      field: 'max_bet_amount',
                    ),
                  ),
                  _buildLimitTile(
                    title: 'Total misé / jour',
                    subtitle:
                        '${state.stakedToday} / ${_valueOrUnset(state.dailyWagerLimit, (v) => '$v jetons')}',
                    onTap: () => _editInt(
                      title: 'Total misé par jour (jetons)',
                      initial: state.dailyWagerLimit,
                      hint: 'Ex : 25000',
                      field: 'daily_wager_limit',
                    ),
                  ),
                  _buildLimitTile(
                    title: 'Dépôt / jour',
                    subtitle:
                        '${state.depositsToday} / ${_valueOrUnset(state.dailyDepositLimit, (v) => '$v jetons')}',
                    onTap: () => _editInt(
                      title: 'Dépôt par jour (jetons)',
                      initial: state.dailyDepositLimit,
                      hint: 'Ex : 100000',
                      field: 'daily_deposit_limit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Pertes nettes (jetons)', Icons.money_off),
                  _buildLimitTile(
                    title: 'Perte nette / jour',
                    subtitle:
                        '${state.netLossToday} / ${_valueOrUnset(state.dailyLossLimit, (v) => '$v jetons')}',
                    onTap: () => _editInt(
                      title: 'Perte nette par jour (jetons)',
                      initial: state.dailyLossLimit,
                      hint: 'Ex : 10000',
                      field: 'daily_loss_limit',
                    ),
                  ),
                  _buildLimitTile(
                    title: 'Perte nette / semaine',
                    subtitle: _valueOrUnset(
                      state.weeklyLossLimit,
                      (v) => '$v jetons',
                    ),
                    onTap: () => _editInt(
                      title: 'Perte nette par semaine (jetons)',
                      initial: state.weeklyLossLimit,
                      hint: 'Ex : 50000',
                      field: 'weekly_loss_limit',
                    ),
                  ),
                  _buildLimitTile(
                    title: 'Perte nette / mois',
                    subtitle: _valueOrUnset(
                      state.monthlyLossLimit,
                      (v) => '$v jetons',
                    ),
                    onTap: () => _editInt(
                      title: 'Perte nette par mois (jetons)',
                      initial: state.monthlyLossLimit,
                      hint: 'Ex : 150000',
                      field: 'monthly_loss_limit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Activité', Icons.timer_outlined),
                  _buildLimitTile(
                    title: 'Parties / jour',
                    subtitle:
                        '${state.matchesToday} / ${_valueOrUnset(state.dailyMatchesLimit, (v) => '$v parties')}',
                    onTap: () => _editInt(
                      title: 'Participations payantes par jour',
                      initial: state.dailyMatchesLimit,
                      hint: 'Ex : 20',
                      field: 'daily_matches_limit',
                    ),
                  ),
                  _buildLimitTile(
                    title: 'Durée de session',
                    subtitle: _valueOrUnset(
                      state.sessionTimeLimitMinutes,
                      (v) => '$v min',
                    ),
                    onTap: () => _editInt(
                      title: 'Durée max de session (minutes)',
                      initial: state.sessionTimeLimitMinutes,
                      hint: 'Ex : 120',
                      field: 'session_time_limit_minutes',
                    ),
                  ),
                  _buildLimitTile(
                    title: 'Rappel de réalité',
                    subtitle: _valueOrUnset(
                      state.realityCheckIntervalMinutes,
                      (v) => 'Toutes les $v min',
                    ),
                    onTap: () => _editInt(
                      title: 'Rappel toutes les X minutes',
                      initial: state.realityCheckIntervalMinutes,
                      hint: 'Ex : 30',
                      field: 'reality_check_interval_minutes',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Pause & Exclusion', Icons.shield_outlined),
                  _buildCoolingOffCard(state),
                  const SizedBox(height: 12),
                  _buildSelfExclusionCard(state),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  String _valueOrUnset(int? value, String Function(int) format) =>
      value != null ? format(value) : 'Pas de limite';

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: NeonColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(ResponsibleGamingState state) {
    return NeonCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _usageStat('${state.stakedToday}', 'Misés'),
          _usageStat('${state.netLossToday}', 'Perte nette'),
          _usageStat('${state.matchesToday}', 'Parties'),
          _usageStat('${state.depositsToday}', 'Dépôts'),
        ],
      ),
    );
  }

  Widget _usageStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: NeonColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLimitTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return NeonCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.edit_outlined,
            color: NeonColors.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildPauseBanner(ResponsibleGamingState state) {
    final text = state.isSelfExcluded
        ? 'Compte en pause : ${state.selfExclusionLabel}'
        : 'Pause courte active — jeu et dépôts bloqués';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: NeonColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: NeonColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(ResponsibleGamingState state) {
    final keys = state.pendingConfig.keys.join(', ');
    final when = state.pendingEffectiveAt != null
        ? '${state.pendingEffectiveAt!.day}/${state.pendingEffectiveAt!.month} à ${state.pendingEffectiveAt!.hour.toString().padLeft(2, '0')}h${state.pendingEffectiveAt!.minute.toString().padLeft(2, '0')}'
        : 'dans 24h';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonColors.secondary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom, color: NeonColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hausse en attente ($keys) — effective $when. Les baisses sont immédiates.',
              style: const TextStyle(
                color: NeonColors.secondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoolingOffCard(ResponsibleGamingState state) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pause courte (24h ou 7 jours)',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bloque jeu et dépôts. Prend effet aussitôt, irrévocable pendant la durée.',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'Pause 24h',
                  variant: NeonButtonVariant.secondary,
                  icon: Icons.pause_circle_outline,
                  onPressed: state.isCoolingOff || state.isSelfExcluded
                      ? () {}
                      : () => _confirmCoolingOff(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'Pause 7 jours',
                  variant: NeonButtonVariant.secondary,
                  icon: Icons.pause_circle_outline,
                  onPressed: state.isCoolingOff || state.isSelfExcluded
                      ? () {}
                      : () => _confirmCoolingOff(7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelfExclusionCard(ResponsibleGamingState state) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Auto-exclusion',
                  style: TextStyle(
                    color: NeonColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                state.selfExclusionLabel,
                style: TextStyle(
                  color: state.isSelfExcluded
                      ? NeonColors.error
                      : NeonColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Bloque totalement le compte. Irréversible pendant la durée choisie.',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          NeonButton(
            text: state.isSelfExcluded
                ? 'Exclusion active'
                : 'Demander une exclusion',
            variant: NeonButtonVariant.danger,
            icon: Icons.block,
            onPressed: state.isSelfExcluded ? () {} : _showSelfExclusionSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _editInt({
    required String title,
    required int? initial,
    required String hint,
    required String field,
  }) async {
    final controller = TextEditingController(
      text: initial?.toString() ?? '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: Text(title,
            style: const TextStyle(
                color: NeonColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: NeonColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: NeonColors.textMuted),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: NeonColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: NeonColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: NeonColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Définir',
                style: TextStyle(
                    color: NeonColors.primary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) {
      if (mounted && controller.text.trim().isNotEmpty) {
        _snack('Montant invalide : entier positif requis');
      }
      return;
    }
    final success = await ref
        .read(responsibleGamingProvider.notifier)
        .updateLimits({field: value});
    if (mounted) {
      _snack(success
          ? 'Limite mise à jour (hausse effective sous 24h)'
          : 'Erreur lors de la mise à jour');
    }
  }

  void _confirmCoolingOff(int days) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: Text(
          'Pause de $days jour${days > 1 ? 's' : ''} ?',
          style: const TextStyle(color: NeonColors.textPrimary, fontSize: 16),
        ),
        content: const Text(
          'Jeu et dépôts seront bloqués aussitôt, sans possibilité d’annuler avant la fin.',
          style: TextStyle(color: NeonColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: NeonColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(responsibleGamingProvider.notifier)
                  .startCoolingOff(days: days);
              if (mounted) {
                _snack(success
                    ? 'Pause activée'
                    : 'Erreur lors de l’activation');
              }
            },
            child: const Text('Confirmer',
                style: TextStyle(
                    color: NeonColors.secondary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSelfExclusionSheet() {
    const durations = <int, String>{
      1: '24 heures',
      7: '7 jours',
      30: '30 jours',
      90: '90 jours',
      0: 'Permanente',
    };
    int selected = 30;
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto-exclusion',
                style: TextStyle(
                  color: NeonColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Irréversible pendant la durée choisie.',
                style: TextStyle(
                    color: NeonColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: durations.entries.map((entry) {
                  final isSelected = selected == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) =>
                        setSheetState(() => selected = entry.key),
                    selectedColor:
                        NeonColors.error.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? NeonColors.error
                          : NeonColors.textSecondary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: NeonColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Motif (min. 3 caractères)',
                  labelStyle:
                      TextStyle(color: NeonColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: NeonColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: NeonColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: NeonButton(
                  text: 'Confirmer l’exclusion',
                  variant: NeonButtonVariant.danger,
                  icon: Icons.block,
                  onPressed: () async {
                    if (reasonCtrl.text.trim().length < 3) {
                      _snack('Motif requis (3 caractères minimum)');
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await ref
                        .read(responsibleGamingProvider.notifier)
                        .selfExclude(
                          durationDays: selected,
                          reason: reasonCtrl.text.trim(),
                        );
                    if (mounted) {
                      _snack(success
                          ? 'Auto-exclusion activée'
                          : 'Erreur lors de l’auto-exclusion');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

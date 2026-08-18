// ============================================================
// Fichier: create_game_screen.dart
// Description: Écran de création de partie
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/models/game_stats_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';

/// Écran de création de partie (Free ou Betting)
class CreateGameScreen extends ConsumerStatefulWidget {
  final String gameType;

  const CreateGameScreen({super.key, this.gameType = 'dice'});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  // État du formulaire
  String _mode = 'free'; // 'free' | 'betting'
  String _ruleType = 'normal'; // 'normal' | 'cible'
  int _setsCount = 3;
  int _diceCount = 2;
  int _betAmount = 50;
  int _maxPlayers = 2;

  bool _isCreating = false;
  String? _error;

  // Default fallback ranges (overridden by dynamic rules from provider)
  int minSets = 1;
  int maxSets = 11;
  int minDice = 1;
  int maxDice = 5;
  int minBet = 10;
  int maxBet = 50000;
  int minPlayers = 2;
  int maxPlayers = 5;

  List<int> get _betPresets {
    final presets = <int>[];
    final steps = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000];
    for (final s in steps) {
      final val = s * (minBet > 0 ? (minBet / 10).ceil() : 1);
      if (val >= minBet && val <= maxBet) presets.add(val);
    }
    if (presets.isEmpty && minBet <= maxBet) presets.addAll([minBet, maxBet]);
    return presets.take(6).toList();
  }

  /// Extract rule config bounds from the loaded GameRuleInfo
  void _applyRulesConfig(List<GameRuleInfo> rules) {
    if (rules.isEmpty) return;
    // Find the rule matching current _ruleType, fallback to first
    final rule = rules.firstWhere(
      (r) => r.ruleType == _ruleType,
      orElse: () => rules.first,
    );
    final c = rule.config;
    minSets = (c['min_sets'] as num?)?.toInt() ?? minSets;
    maxSets = (c['max_sets'] as num?)?.toInt() ?? maxSets;
    minDice = (c['min_dice'] as num?)?.toInt() ?? minDice;
    maxDice = (c['max_dice'] as num?)?.toInt() ?? maxDice;
    minBet = (c['min_bet'] as num?)?.toInt() ?? minBet;
    maxBet = (c['max_bet'] as num?)?.toInt() ?? maxBet;
    minPlayers = (c['min_players'] as num?)?.toInt() ?? minPlayers;
    maxPlayers = (c['max_players'] as num?)?.toInt() ?? maxPlayers;

    // Clamp current values to new bounds
    _setsCount = _setsCount.clamp(minSets, maxSets);
    _diceCount = _diceCount.clamp(minDice, maxDice);
    _maxPlayers = _maxPlayers.clamp(minPlayers, maxPlayers);
    if (_betAmount < minBet) _betAmount = minBet;
    if (_betAmount > maxBet) _betAmount = maxBet;
  }

  @override
  Widget build(BuildContext context) {
    // Watch game rules from admin config (dynamic per game type)
    final rulesAsync = ref.watch(gameRulesProvider(widget.gameType));

    return rulesAsync.when(
      data: (rules) {
        _applyRulesConfig(rules);
        return _buildBody();
      },
      loading: () => _buildBody(),
      error: (_, __) => _buildBody(),
    );
  }

  Widget _buildBody() {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Créer une partie'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 20),
            _buildRuleTypeSelector(),
            const SizedBox(height: 20),
            _buildSetsSlider(),
            const SizedBox(height: 20),
            _buildDiceSlider(),
            const SizedBox(height: 20),
            _buildPlayersSlider(),
            if (_mode == 'betting') ...[
              const SizedBox(height: 20),
              _buildBetSection(),
            ],
            const SizedBox(height: 30),
            _buildSummary(),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: NeonColors.error), textAlign: TextAlign.center),
              ),
            NeonButton(
              text: 'Créer la partie',
              onPressed: _isCreating ? () {} : _createRoom,
              isLoading: _isCreating,
              icon: Icons.add_circle_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mode de jeu', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _modeButton('free', 'Gratuit', Icons.people_outline, 'Entre amis')),
              const SizedBox(width: 12),
              Expanded(child: _modeButton('betting', 'Pari', Icons.monetization_on_outlined, 'Mise en ligne')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String mode, String title, IconData icon, String subtitle) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.15) : NeonColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? NeonColors.primary : NeonColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: NeonColors.primary.withValues(alpha: 0.3), blurRadius: 8)] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? NeonColors.primary : NeonColors.textSecondary, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: isSelected ? NeonColors.primary : NeonColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTypeSelector() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type de règles', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ruleButton('normal', 'Normal', 'High roll séquentiel\nOrdre tournant')),
              const SizedBox(width: 12),
              Expanded(child: _ruleButton('cible', 'Cible', 'Vote pour cible\nPlus proche gagne')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ruleButton(String type, String title, String description) {
    final isSelected = _ruleType == type;
    return GestureDetector(
      onTap: () => setState(() => _ruleType = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.secondary.withValues(alpha: 0.15) : NeonColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? NeonColors.secondary : NeonColors.border, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: isSelected ? NeonColors.secondary : NeonColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsSlider() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nombre de sets', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: NeonColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('$_setsCount', style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: NeonColors.primary,
              inactiveTrackColor: NeonColors.border,
              thumbColor: NeonColors.primary,
              overlayColor: NeonColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _setsCount.toDouble(),
              min: minSets.toDouble(),
              max: maxSets.toDouble(),
              divisions: maxSets - minSets,
              onChanged: (v) => setState(() => _setsCount = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$minSets', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
              Text('$maxSets', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiceSlider() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nombre de dés', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: NeonColors.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('🎲 $_diceCount', style: const TextStyle(color: NeonColors.secondary, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          SliderTheme(
            data: const SliderThemeData(
              activeTrackColor: NeonColors.secondary,
              inactiveTrackColor: NeonColors.border,
              thumbColor: NeonColors.secondary,
            ),
            child: Slider(
              value: _diceCount.toDouble(),
              min: minDice.toDouble(),
              max: maxDice.toDouble(),
              divisions: maxDice - minDice,
              onChanged: (v) => setState(() => _diceCount = v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersSlider() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Max joueurs', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: NeonColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('$_maxPlayers', style: const TextStyle(color: NeonColors.accent, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          SliderTheme(
            data: const SliderThemeData(
              activeTrackColor: NeonColors.accent,
              inactiveTrackColor: NeonColors.border,
              thumbColor: NeonColors.accent,
            ),
            child: Slider(
              value: _maxPlayers.toDouble(),
              min: minPlayers.toDouble(),
              max: maxPlayers.toDouble(),
              divisions: maxPlayers - minPlayers,
              onChanged: (v) => setState(() => _maxPlayers = v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetSection() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mise (jetons)', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _betPresets.map((preset) {
              final isSelected = _betAmount == preset;
              return GestureDetector(
                onTap: () => setState(() => _betAmount = preset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? NeonColors.success.withValues(alpha: 0.2) : NeonColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? NeonColors.success : NeonColors.border),
                  ),
                  child: Text(
                    '$preset jetons',
                    style: TextStyle(color: isSelected ? NeonColors.success : NeonColors.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Custom
          Row(
            children: [
              const Text('Custom: ', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _betAmount.toDouble().clamp(minBet.toDouble(), maxBet.toDouble()),
                  min: minBet.toDouble(),
                  max: maxBet.toDouble(),
                  activeColor: NeonColors.success,
                  onChanged: (v) => setState(() => _betAmount = v.round()),
                ),
              ),
              Text('$_betAmount', style: const TextStyle(color: NeonColors.success, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Récapitulatif', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _summaryRow('Mode', _mode == 'free' ? 'Gratuit (amis)' : 'Pari en ligne'),
          _summaryRow('Règles', _ruleType == 'normal' ? 'Normal' : 'Cible'),
          _summaryRow('Sets', '$_setsCount (majorité: ${(_setsCount ~/ 2) + 1})'),
          _summaryRow('Dés', '$_diceCount dé${_diceCount > 1 ? 's' : ''}'),
          _summaryRow('Joueurs', '$_maxPlayers max'),
          if (_mode == 'betting') _summaryRow('Mise', '$_betAmount jetons'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _createRoom() async {
    setState(() { _isCreating = true; _error = null; });

    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);

      final config = CreateGameConfig(
        gameType: widget.gameType,
        ruleType: _ruleType,
        mode: _mode,
        setsCount: _setsCount,
        diceCount: _diceCount,
        betAmount: _mode == 'betting' ? _betAmount : 0,
        maxPlayers: _maxPlayers,
      );

      final room = await roomRepo.createRoom(config);

      if (!mounted) return;

      context.pushReplacement('/games/${widget.gameType}/room/${room.roomId}', extra: room);
    } catch (e) {
      setState(() { _isCreating = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }
}

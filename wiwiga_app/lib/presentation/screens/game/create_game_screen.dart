// ============================================================
// Fichier: create_game_screen.dart
// Description: Écran de création de partie
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/constants/game_mode.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/models/game_stats_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import '../../widgets/neon/token_coin.dart';
import '../../widgets/neon/token_chip.dart';
import '../../widgets/neon/token_stack.dart';
import '../../providers/config_provider.dart';

/// Écran de création de partie (Free ou Betting)
class CreateGameScreen extends ConsumerStatefulWidget {
  final String gameType;

  const CreateGameScreen({super.key, this.gameType = 'dice'});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  // État du formulaire — migration brutale 2026-08-30: free/staked seuls (betting supprimé)
  String _mode = GameMode.free.apiValue; // 'free' | 'staked'
  String _ruleType = 'normal'; // 'normal' | 'cible'
  int _setsCount = 3;
  int _diceCount = 2;
  int _betAmount = 50;
  int _maxPlayers = 2;

  bool get _isStaked => GameMode.parse(_mode).isStaked;

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
    // Watch tokens config for min bets
    final tokensConfigAsync = ref.watch(tokensConfigProvider);

    return rulesAsync.when(
      data: (rules) {
        _applyRulesConfig(rules);
        // Apply tokens config min bets
        tokensConfigAsync.whenData((tokensConfig) {
          if (widget.gameType == 'dice') {
            minBet = tokensConfig.diceMinBet > minBet ? tokensConfig.diceMinBet : minBet;
          } else if (widget.gameType == 'cards') {
            minBet = tokensConfig.cardsMinBet > minBet ? tokensConfig.cardsMinBet : minBet;
          }
          if (_betAmount < minBet) _betAmount = minBet;
        });
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
            if (_isStaked) ...[
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
          const SizedBox(height: 4),
          const Text('Choisissez le type de partie', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _modeButton(
                  GameMode.free.apiValue,
                  GameMode.free.shortLabel, // Sans mise
                  Icons.people_outline,
                  GameMode.free.displayLabel, // Partie sans mise (gratuit)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeButton(
                  GameMode.staked.apiValue,
                  GameMode.staked.shortLabel, // Avec mise
                  Icons.monetization_on_outlined,
                  GameMode.staked.displayLabel, // Partie avec mise
                ),
              ),
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
          Row(
            children: [
              const Text('Mise (wiga)', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              // Aperçu pot 3D selon mise
              TokenStack(
                count: (_betAmount / (minBet > 0 ? minBet : 10)).clamp(1, 7).round(),
                size: 28,
                metal: TokenMetal.emerald,
                altMetal: TokenMetal.gold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Presets 3D — TokenChip
          TokenChipGroup(
            amounts: _betPresets,
            selectedAmount: _betAmount,
            onSelected: (v) => setState(() => _betAmount = v),
            chipSize: 40,
          ),
          const SizedBox(height: 14),
          // Custom slider
          Row(
            children: [
              const TokenCoin(size: 20, metal: TokenMetal.emerald),
              const SizedBox(width: 6),
              const Text('Perso : ', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _betAmount.toDouble().clamp(minBet.toDouble(), maxBet.toDouble()),
                  min: minBet.toDouble(),
                  max: maxBet.toDouble(),
                  activeColor: NeonColors.success,
                  onChanged: (v) => setState(() => _betAmount = v.round()),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: NeonColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeonColors.success.withValues(alpha: 0.32)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TokenCoin(size: 14, metal: _betAmount >= 5000 ? TokenMetal.gold : TokenMetal.emerald, lod: TokenLod.flat, showShadow: false),
                    const SizedBox(width: 4),
                    Text('$_betAmount', style: const TextStyle(color: NeonColors.success, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final modeLabel = GameMode.parse(_mode).displayLabel;
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Récapitulatif', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _summaryRow('Mode', modeLabel),
          _summaryRow('Règles', _ruleType == 'normal' ? 'Normal' : 'Cible'),
          _summaryRow('Sets', '$_setsCount (majorité: ${(_setsCount ~/ 2) + 1})'),
          _summaryRow('Dés', '$_diceCount dé${_diceCount > 1 ? 's' : ''}'),
          _summaryRow('Joueurs', '$_maxPlayers max'),
          if (_isStaked) _summaryRow('Mise', '$_betAmount wiga'),
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

    // Vérifier d'abord si le joueur a déjà un salon en attente / en cours → redirection immédiate
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final userId = ref.read(authProvider).user?.id ?? '';
      if (userId.isNotEmpty) {
        final waiting = await roomRepo.listWaitingRooms(gameType: widget.gameType);
        final myExisting = waiting.where((r) => r.creatorId == userId && r.status == 'waiting').toList();
        if (myExisting.isNotEmpty) {
          final existing = myExisting.first;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vous avez déjà un salon (${existing.roomCode}) — redirection'), backgroundColor: NeonColors.warning, duration: const Duration(seconds: 2)),
          );
          context.pushReplacement('/games/${widget.gameType}/room/${existing.roomId}', extra: existing);
          return;
        }
        // Vérifier aussi les salles en cours où le joueur est participant
        final myActive = waiting.where((r) => r.players.any((p) => p.id == userId)).toList();
        if (myActive.isNotEmpty) {
          final existing = myActive.first;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous êtes déjà dans une salle — redirection'), backgroundColor: NeonColors.info),
          );
          context.pushReplacement('/games/${widget.gameType}/room/${existing.roomId}', extra: existing);
          return;
        }
      }
    } catch (_) {
      // Non bloquant — poursuivre la création
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);

      final config = CreateGameConfig(
        gameType: widget.gameType,
        ruleType: _ruleType,
        mode: _mode,
        setsCount: _setsCount,
        diceCount: _diceCount,
        betAmount: _isStaked ? _betAmount : 0,
        maxPlayers: _maxPlayers,
      );

      final room = await roomRepo.createRoom(config);

      if (!mounted) return;

      // Si le backend a retourné une salle existante (redirection), informer l'utilisateur
      final isRedirect = room.playersCount > 1 || (DateTime.now().difference(room.createdAt ?? DateTime.now()).inSeconds > 5);
      if (isRedirect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Redirection vers votre salon existant ${room.roomCode}'), backgroundColor: NeonColors.info),
        );
      }

      context.pushReplacement('/games/${widget.gameType}/room/${room.roomId}', extra: room);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'CreateGame.createRoom');
      // Gestion spécifique des erreurs de salon déjà existant renvoyées par le backend (409 ou message)
      final msg = ErrorHandler.userMessage(e);
      final lower = msg.toLowerCase();
      if (lower.contains('déjà') || lower.contains('already') || lower.contains('existant') || lower.contains('waiting_room') || lower.contains('active_match')) {
        try {
          final apiService = ref.read(apiServiceProvider);
          final roomRepo = RoomRepository(apiService);
          final waiting = await roomRepo.listWaitingRooms(gameType: widget.gameType);
          final userId = ref.read(authProvider).user?.id ?? '';
          final myExisting = waiting.where((r) => r.players.any((p) => p.id == userId)).toList();
          if (myExisting.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: NeonColors.warning));
            context.pushReplacement('/games/${widget.gameType}/room/${myExisting.first.roomId}', extra: myExisting.first);
            return;
          }
        } catch (_) {}
      }
      if (mounted) setState(() { _isCreating = false; _error = msg; });
    }
  }
}

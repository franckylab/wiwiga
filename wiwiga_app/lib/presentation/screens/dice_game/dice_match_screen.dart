// ============================================================
// Fichier: dice_match_screen.dart
// Description: Écran de match de dés avec système multi-sets
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';

/// Écran de match de dés avec support multi-sets
///
/// Phases:
/// 1. Set intro : "Set 1/3" avec animation
/// 2. Turn order : "À [Joueur] de lancer"
/// 3. Dice roll : animation séquentielle
/// 4. Set result : qui a gagné ce set
/// 5. Match score : score des sets
/// 6. Match result : gagnant final + gains
class DiceMatchScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String ruleType; // 'normal' | 'cible'
  final int setsCount;
  final int diceCount;
  final int betAmount;
  final List<Map<String, dynamic>> players;

  const DiceMatchScreen({
    super.key,
    required this.matchId,
    this.ruleType = 'normal',
    this.setsCount = 3,
    this.diceCount = 2,
    this.betAmount = 0,
    required this.players,
  });

  @override
  ConsumerState<DiceMatchScreen> createState() => _DiceMatchScreenState();
}

class _DiceMatchScreenState extends ConsumerState<DiceMatchScreen> with TickerProviderStateMixin {
  // État du match
  int _currentSet = 1;
  int _currentTurnIndex = 0;
  bool _isRolling = false;
  bool _showSetIntro = true;
  bool _showSetResult = false;
  bool _showMatchResult = false;

  // Scores
  final Map<String, int> _setWins = {};
  final Map<String, int> _currentRolls = {};
  final List<Map<String, dynamic>> _setResults = [];

  // Vote cible (mode cible)
  final Map<String, int> _targetVotes = {};
  bool _isVotingPhase = false;
  int? _targetValue;

  // Animation
  late AnimationController _diceAnimController;
  List<int> _currentDice = [];

  // Dés par joueur pour le set en cours
  Map<String, List<int>> _playerDice = {};
  Map<String, int> _playerSums = {};

  @override
  void initState() {
    super.initState();
    _diceAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Initialiser les scores
    for (var player in widget.players) {
      _setWins[player['id'].toString()] = 0;
    }

    // Démarrer avec l'intro du set 1
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _showSetIntro = false);
    });
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    super.dispose();
  }

  int get _setsToWin => (widget.setsCount ~/ 2) + 1;
  String get _currentPlayerId => widget.players[_currentTurnIndex % widget.players.length]['id'].toString();
  String get _currentPlayerName => widget.players[_currentTurnIndex % widget.players.length]['name'].toString();
  bool get _isCibleMode => widget.ruleType == 'cible';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: Text('Set $_currentSet/${widget.setsCount}'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
        elevation: 0,
        actions: [
          _buildScoreBadge(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildScoreBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: NeonColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.players.asMap().entries.map((entry) {
          final idx = entry.key;
          final player = entry.value;
          final pid = player['id'].toString();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (idx > 0) const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('-', style: TextStyle(color: NeonColors.textSecondary)),
              ),
              Text(
                '${_setWins[pid] ?? 0}',
                style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_showMatchResult) return _buildMatchResult();
    if (_showSetIntro) return _buildSetIntro();
    if (_showSetResult) return _buildSetResult();
    if (_isVotingPhase) return _buildVotingPhase();

    return Column(
      children: [
        // Scoreboard des sets
        _buildSetScoreboard(),
        const SizedBox(height: 16),
        // Tour du joueur
        _buildTurnIndicator(),
        const SizedBox(height: 24),
        // Zone de dés
        Expanded(child: _buildDiceArea()),
        // Bouton lancer
        _buildRollButton(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSetIntro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_esports, color: NeonColors.primary, size: 64),
          const SizedBox(height: 16),
          Text(
            'Set $_currentSet',
            style: const TextStyle(color: NeonColors.primary, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'sur ${widget.setsCount}',
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 18),
          ),
          if (_isCibleMode) ...[
            const SizedBox(height: 16),
            const Text('Mode Cible - Votez pour la cible !', style: TextStyle(color: NeonColors.secondary, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildSetScoreboard() {
    return NeonCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: widget.players.map((player) {
          final pid = player['id'].toString();
          final name = player['name'].toString();
          final wins = _setWins[pid] ?? 0;
          final isCurrentTurn = pid == _currentPlayerId;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrentTurn ? NeonColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrentTurn ? Border.all(color: NeonColors.primary, width: 2) : null,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isCurrentTurn ? NeonColors.primary.withValues(alpha: 0.3) : NeonColors.surface,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: NeonColors.primary)),
                    ),
                    const SizedBox(height: 4),
                    Text(name, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('$wins set${wins > 1 ? 's' : ''}', style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTurnIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: NeonColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_forward, color: NeonColors.secondary),
          const SizedBox(width: 8),
          Text(
            'À $_currentPlayerName de lancer',
            style: const TextStyle(color: NeonColors.secondary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dés actuels
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _currentDice.isEmpty
                ? List.generate(widget.diceCount, (i) => _buildEmptyDice(i))
                : _currentDice.asMap().entries.map((e) => _buildDiceFace(e.value, e.key)).toList(),
          ),
          const SizedBox(height: 24),
          // Somme
          if (_playerSums.containsKey(_currentPlayerId))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: NeonColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Somme: ${_playerSums[_currentPlayerId]}',
                style: const TextStyle(color: NeonColors.accent, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          // Cible (mode cible)
          if (_targetValue != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: NeonColors.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cible: $_targetValue',
                  style: const TextStyle(color: NeonColors.secondary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDice(int index) {
    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: const Icon(Icons.casino, color: NeonColors.textSecondary, size: 32),
    );
  }

  Widget _buildDiceFace(int value, int index) {
    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.primary, width: 2),
        boxShadow: [BoxShadow(color: NeonColors.primary.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Center(
        child: Text(
          '$value',
          style: const TextStyle(color: NeonColors.primary, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRollButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: NeonButton(
        text: _isRolling ? 'Lancement...' : 'Lancer les dés',
        onPressed: _isRolling ? () {} : _rollDice,
        icon: Icons.casino,
        variant: NeonButtonVariant.primary,
      ),
    );
  }

  Widget _buildVotingPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Votez pour la cible !', style: TextStyle(color: NeonColors.secondary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text('Max: ${widget.diceCount * 6}', style: const TextStyle(color: NeonColors.textSecondary)),
          const SizedBox(height: 24),
          // Slider de vote
          SizedBox(
            width: 300,
            child: Slider(
              value: (_targetVotes[_currentPlayerId] ?? 7).toDouble(),
              min: widget.diceCount.toDouble(),
              max: (widget.diceCount * 6).toDouble(),
              divisions: (widget.diceCount * 6) - widget.diceCount,
              label: '${_targetVotes[_currentPlayerId] ?? 7}',
              activeColor: NeonColors.secondary,
              onChanged: (v) {
                setState(() => _targetVotes[_currentPlayerId] = v.round());
              },
            ),
          ),
          Text(
            '${_targetVotes[_currentPlayerId] ?? 7}',
            style: const TextStyle(color: NeonColors.secondary, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          NeonButton(
            text: 'Voter',
            onPressed: _submitVote,
            variant: NeonButtonVariant.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSetResult() {
    final lastResult = _setResults.isNotEmpty ? _setResults.last : null;
    final isTie = lastResult?['result'] == 'tie';
    final winnerName = isTie ? null : _findPlayerName(lastResult?['winner_id']?.toString());

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTie ? Icons.horizontal_rule : Icons.emoji_events,
            color: isTie ? NeonColors.warning : NeonColors.success,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            isTie ? 'Set nul !' : '$winnerName gagne le set !',
            style: TextStyle(
              color: isTie ? NeonColors.warning : NeonColors.success,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Détails des lancers
          ...widget.players.map((player) {
            final pid = player['id'].toString();
            final sum = lastResult?['sums']?[pid] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${player['name']}: $sum',
                style: const TextStyle(color: NeonColors.textPrimary, fontSize: 16),
              ),
            );
          }),
          const SizedBox(height: 24),
          // Score global
          Text(
            'Score: ${widget.players.map((p) => '${p['name']}: ${_setWins[p['id'].toString()]}').join(' - ')}',
            style: const TextStyle(color: NeonColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          NeonButton(
            text: isTie ? 'Rejouer le set' : 'Set suivant',
            onPressed: _nextSet,
            variant: NeonButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchResult() {
    // Trouver le gagnant
    final winner = _setWins.entries.where((e) => e.value >= _setsToWin).first;
    final winnerPlayer = widget.players.firstWhere((p) => p['id'].toString() == winner.key);
    final isBetting = widget.betAmount > 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
          const SizedBox(height: 16),
          Text(
            '${winnerPlayer['name']} gagne !',
            style: const TextStyle(color: NeonColors.success, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Score final: ${_setWins[winner.key]} sets',
            style: const TextStyle(color: NeonColors.textPrimary, fontSize: 18),
          ),
          if (isBetting) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: NeonColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Gains', style: TextStyle(color: NeonColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '+${widget.betAmount * 2} jetons',
                    style: const TextStyle(color: NeonColors.success, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          NeonButton(
            text: 'Retour au jeu',
            onPressed: () => context.go('/games/dice'),
            variant: NeonButtonVariant.primary,
          ),
          const SizedBox(height: 12),
          NeonButton(
            text: 'Ajouter comme ami',
            onPressed: () {
              // TODO: Ajouter ami
            },
            variant: NeonButtonVariant.outline,
            icon: Icons.person_add_outlined,
          ),
        ],
      ),
    );
  }

  // === Actions ===

  void _rollDice() {
    setState(() => _isRolling = true);

    // Animation de lancement
    final random = Random();
    _diceAnimController.forward(from: 0);

    // Simulation animation
    int animCount = 0;
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) { timer?.cancel(); return; }
      setState(() {
        _currentDice = List.generate(widget.diceCount, (_) => random.nextInt(6) + 1);
      });
      animCount++;
      if (animCount >= 8) {
        timer?.cancel();
        _finalizeRoll();
      }
    });
  }

  void _finalizeRoll() {
    final random = Random.secure();
    final dice = List.generate(widget.diceCount, (_) => random.nextInt(6) + 1);
    final sum = dice.fold<int>(0, (a, b) => a + b);

    setState(() {
      _currentDice = dice;
      _playerDice[_currentPlayerId] = dice;
      _playerSums[_currentPlayerId] = sum;
      _isRolling = false;
    });

    // Passer au joueur suivant ou évaluer le set
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_currentTurnIndex + 1 >= widget.players.length) {
        // Tous les joueurs ont lancé → évaluer
        _evaluateSet();
      } else {
        setState(() => _currentTurnIndex++);
      }
    });
  }

  void _evaluateSet() {
    final sums = Map<String, int>.from(_playerSums);

    // Trouver le max
    final maxSum = sums.values.fold<int>(0, max);
    final winners = sums.entries.where((e) => e.value == maxSum).toList();

    String? winnerId;
    String result;

    if (winners.length == 1) {
      winnerId = winners.first.key;
      result = 'winner';
      _setWins[winnerId] = (_setWins[winnerId] ?? 0) + 1;
    } else {
      result = 'tie';
    }

    setState(() {
      _setResults.add({
        'set_number': _currentSet,
        'result': result,
        'winner_id': winnerId,
        'sums': sums,
      });
      _showSetResult = true;
    });

    // Vérifier si le match est terminé
    if (_setWins.values.any((v) => v >= _setsToWin)) {
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() => _showMatchResult = true);
      });
    }
  }

  void _nextSet() {
    final lastResult = _setResults.last;
    final isTie = lastResult['result'] == 'tie';

    setState(() {
      if (!isTie) _currentSet++;
      _currentTurnIndex = 0;
      _currentDice = [];
      _playerDice = {};
      _playerSums = {};
      _showSetResult = false;
      _showSetIntro = true;
      _isVotingPhase = _isCibleMode;
    });

    // Masquer l'intro après un délai
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSetIntro = false);
    });
  }

  void _submitVote() {
    setState(() {
      _isVotingPhase = false;
    });

    // Calculer la cible (moyenne des votes)
    if (_targetVotes.length >= widget.players.length) {
      final sum = _targetVotes.values.fold<int>(0, (a, b) => a + b);
      final target = (sum / _targetVotes.length).round();
      setState(() => _targetValue = target);
    }
  }

  String? _findPlayerName(String? playerId) {
    if (playerId == null) return null;
    final player = widget.players.firstWhere((p) => p['id'].toString() == playerId, orElse: () => {});
    return player.isNotEmpty ? player['name']?.toString() : 'Inconnu';
  }
}

// Extension pour iterer avec index sur une Map
extension MapEntriesExtension<K, V> on Map<K, V> {
  Iterable<MapEntry<int, V>> asMap() sync* {
    int i = 0;
    for (var value in values) {
      yield MapEntry(i++, value);
    }
  }
}

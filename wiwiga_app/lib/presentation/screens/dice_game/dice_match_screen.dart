// ============================================================
// Fichier: dice_match_screen.dart
// Description: Écran de match de dés refactorisé — tatami central + zones joueurs
//              Joueur "Moi", tour actif/verrouillé, icône dé cliquable, score/niveau/mise,
//              délai forfait 30s, animations 3D, responsive extrême
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import '../../widgets/neon/token_coin.dart';
import '../../widgets/neon/token_stack.dart';
import '../../widgets/game/reality_check_overlay.dart';
import '../../widgets/game/dice_tatami.dart';
import '../../widgets/game/dice_3d.dart';
import '../../widgets/game/player_zone.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/friend_provider.dart';
import '../../providers/config_provider.dart';

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

class _DiceMatchScreenState extends ConsumerState<DiceMatchScreen>
    with TickerProviderStateMixin {
  // === État match ===
  int _currentSet = 1;
  int _currentTurnIndex = 0;
  bool _isRolling = false;
  bool _showSetIntro = true;
  bool _showSetResult = false;
  bool _showMatchResult = false;

  // Scores
  final Map<String, int> _setWins = {};
  final List<Map<String, dynamic>> _setResults = [];

  // Vote cible
  final Map<String, int> _targetVotes = {};
  bool _isVotingPhase = false;
  int? _targetValue;

  // Animations
  late AnimationController _introCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _boardGlowCtrl;
  List<int> _currentDice = [];
  Map<String, List<int>> _playerDice = {};
  Map<String, int> _playerSums = {};
  Set<String> _eliminated = {};
  Timer? _turnTimer;
  int _turnSeconds = 30;
  int _turnRemaining = 30;
  DateTime? _turnDeadline;

  // Serveur source de vérité
  Map<String, dynamic>? _serverMatch;
  Map<String, dynamic>? _serverSetState;

  // WebSocket state
  bool _useWebSocket = false;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _resultCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _boardGlowCtrl =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat(reverse: true);

    for (var p in widget.players) {
      _setWins[p['id'].toString()] = 0;
    }
    _loadTurnTimeout();
    _initWebSocket();
    _startSetIntro();
  }

  Future<void> _loadTurnTimeout() async {
    // Essaie de récupérer le timeout depuis la config (GamesConfig turnTimeout)
    try {
      final gamesCfg = ref.read(gamesConfigProvider);
      gamesCfg.whenData((cfg) {
        if (cfg.turnTimeout > 0) {
          _turnSeconds = cfg.turnTimeout.clamp(15, 90);
          _turnRemaining = _turnSeconds;
        }
      });
    } catch (_) {}
    // Fallback via GameTimeoutConfig -> utilise 30s par défaut si non chargé
  }

  void _syncFromServer(Map<String, dynamic> match) {
    if (!mounted) return;
    setState(() {
      _serverMatch = match;
      _serverSetState = match['current_set_state'] as Map<String, dynamic>?;
      final scores = match['set_scores'] as Map?;
      if (scores != null) {
        for (var e in scores.entries) {
          _setWins[e.key.toString()] = (e.value as num).toInt();
        }
      }
      final elim = match['eliminated_players'] as List?;
      if (elim != null) {
        _eliminated = elim.map((e) => e.toString()).toSet();
      }
      final cs = match['current_set'] as int?;
      if (cs != null && cs > 0) _currentSet = cs;
      final css = _serverSetState;
      if (css != null) {
        final tv = css['target_value'] as int?;
        if (tv != null) _targetValue = tv;
        _isVotingPhase = css['vote_phase'] == true;
        final dlStr = css['turn_deadline']?.toString() ??
            match['turn_deadline']?.toString();
        if (dlStr != null) {
          try {
            _turnDeadline = DateTime.parse(dlStr);
            _turnRemaining = _turnDeadline!
                .difference(DateTime.now())
                .inSeconds
                .clamp(0, _turnSeconds);
            _startTurnCountdownFromDeadline();
          } catch (_) {}
        }
        final status = match['status']?.toString();
        if (status == 'set_in_progress' && !_isVotingPhase) {
          _showSetIntro = false;
          _showSetResult = false;
        }
      }
      if (match['status']?.toString() == 'match_ended') {
        _showMatchResult = true;
        _showSetIntro = false;
        _showSetResult = false;
      }
    });
  }

  void _startTurnCountdownFromDeadline() {
    _turnTimer?.cancel();
    if (_turnDeadline == null) {
      _startTurnCountdown();
      return;
    }
    _turnTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      final rem = _turnDeadline!.difference(DateTime.now()).inSeconds;
      final clamped = rem.clamp(0, _turnSeconds);
      if (clamped != _turnRemaining) setState(() => _turnRemaining = clamped);
      if (clamped <= 0) {
        _turnTimer?.cancel();
        if (_displayEliminated.contains(_currentPlayerId)) return;
      }
    });
  }

  void _initWebSocket() {
    try {
      final ws = ref.read(gameWebSocketServiceProvider);
      // Rejoindre le match channel
      ws.joinGame(widget.matchId);
      _useWebSocket = true;

      ws.onSetStarted = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>? ?? payload;
        _syncFromServer(match);
        setState(() {
          _showSetResult = false;
          _showSetIntro = true;
          _currentDice = [];
          _playerDice.clear();
          _playerSums.clear();
          _isRolling = false;
        });
        _introCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _showSetIntro = false);
        });
      };

      ws.onDiceRolled = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match);
        final roll = payload['roll'] as Map<String, dynamic>? ?? payload;
        final dice = List<int>.from(
          roll['dice'] ?? roll['dice_results'] ?? roll['diceValues'] ?? [],
        );
        final sum = roll['sum'] as int? ?? roll['total_sum'] as int?;
        final playerId =
            roll['player_id']?.toString() ?? roll['playerId']?.toString() ?? '';
        if (dice.isNotEmpty) {
          setState(() {
            _currentDice = dice;
            if (playerId.isNotEmpty) {
              _playerDice[playerId] = dice;
              _playerSums[playerId] = sum ?? dice.fold<int>(0, (a, b) => a + b);
            }
            _isRolling = false;
          });
        }
        if (match != null) {
          _turnTimer?.cancel();
        } else {
          _advanceAfterRollWs(payload);
        }
      };
      ws.onSetResult = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match);
        final result = payload['result'] ?? payload['set_result'];
        String? winnerId;
        if (payload['winner_id'] != null) {
          winnerId = payload['winner_id'].toString();
        } else if (result is Map && result['winner_id'] != null) {
          winnerId = result['winner_id'].toString();
        } else if (match != null && match['winner_id'] != null) {
          winnerId = match['winner_id'].toString();
        }
        final lastSetNum = _serverMatch?['current_set'] as int? ?? _currentSet;
        if (_setResults.isEmpty ||
            _setResults.last['set_number'] != lastSetNum) {
          setState(() {
            _setResults.add({
              'set_number': lastSetNum,
              'result': winnerId == null ? 'tie' : 'winner',
              'winner_id': winnerId,
              'sums': Map<String, int>.from(_playerSums),
            });
            _showSetResult = true;
          });
        } else {
          setState(() => _showSetResult = true);
        }
        _resultCtrl.forward(from: 0);
        if (_checkMatchOver()) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _showMatchResult = true);
          });
        }
      };
      ws.onMatchResult = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match);
        setState(() => _showMatchResult = true);
      };
      ws.onTargetVoted = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match);
        final target = payload['target_value'] as int? ??
            payload['target'] as int? ??
            _serverSetState?['target_value'] as int?;
        if (target != null) {
          setState(() {
            _targetValue = target;
            _isVotingPhase = false;
          });
        }
      };
      ws.onPlayerForfeited = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match);
        final pid =
            payload['player_id']?.toString() ?? payload['playerId']?.toString();
        if (pid != null && !_displayEliminated.contains(pid)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_findPlayerName(pid) ?? pid} forfait — éliminé'),
              backgroundColor: NeonColors.warning,
            ),
          );
        }
      };
      ws.onMatchForfeit = ws.onPlayerForfeited;
      ws.onGameResult = (payload) {
        if (payload['event'] == 'player_forfeited' ||
            payload['event'] == 'match_forfeit') {
          ws.onPlayerForfeited?.call(payload);
        }
      };
      ws.onMatchState = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>? ?? payload;
        _syncFromServer(match);
      };
      ws.onRoomUpdated = (payload) {
        final room = payload['room'] as Map<String, dynamic>? ?? payload;
        final mid = room['match_id']?.toString();
        if (mid != null && mid == widget.matchId) {}
      };
    } catch (_) {
      _useWebSocket = false;
    }
  }

  void _advanceAfterRollWs(Map<String, dynamic> payload) {
    final match = payload['match'] as Map<String, dynamic>?;
    if (match != null) {
      final status = match['status']?.toString();
      if (status == 'set_ended' || status == 'match_ended') {
        // Géré via onSetResult
        return;
      }
      final css = match['current_set_state'] as Map<String, dynamic>?;
      if (css != null) {
        final idx = css['current_turn_index'] as int? ?? 0;
        final deadlineStr = css['turn_deadline']?.toString() ??
            match['turn_deadline']?.toString();
        setState(() {
          _currentTurnIndex = idx;
          _currentDice = [];
          if (deadlineStr != null) {
            try {
              _turnDeadline = DateTime.parse(deadlineStr);
            } catch (_) {}
            _startTurnCountdown();
          }
        });
      }
    } else {
      // fallback local
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        if (_currentTurnIndex + 1 >= _activePlayers.length) {
          _evaluateSet();
        } else {
          setState(() => _currentTurnIndex++);
          _startTurnCountdown();
        }
      });
    }
  }

  void _startSetIntro() {
    _introCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showSetIntro = false);
      _startTurnCountdown();
      if (_isCibleMode && _targetValue == null) {
        setState(() => _isVotingPhase = true);
      }
    });
  }

  void _startTurnCountdown() {
    _turnTimer?.cancel();
    _turnDeadline = DateTime.now().add(Duration(seconds: _turnSeconds));
    _turnRemaining = _turnSeconds;
    _turnTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      final rem = _turnDeadline!.difference(DateTime.now()).inSeconds;
      final clamped = rem.clamp(0, _turnSeconds);
      if (clamped != _turnRemaining) setState(() => _turnRemaining = clamped);
      if (clamped <= 0) {
        _turnTimer?.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    // Si WS connecté, le serveur gère le forfait via turn_timeout — on attend son broadcast
    if (_useWebSocket && _serverMatch != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temps écoulé — forfait en cours...'),
            backgroundColor: NeonColors.warning,
          ),
        );
      }
      return;
    }
    final currentId = _currentPlayerId;
    final isMe = currentId == _myId;
    setState(() => _eliminated.add(currentId));
    if (isMe) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temps écoulé — vous êtes forfait !'),
            backgroundColor: NeonColors.error,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_currentPlayerName forfait (temps écoulé)'),
            backgroundColor: NeonColors.warning,
          ),
        );
      }
    }
    final remaining = _activePlayers;
    if (remaining.length <= 1) {
      setState(() => _showMatchResult = true);
      _turnTimer?.cancel();
      return;
    }
    _advanceTurnAfterForfeit();
  }

  void _advanceTurnAfterForfeit() {
    // Trouver prochain index non éliminé
    int nextIdx = _currentTurnIndex + 1;
    while (nextIdx < _turnOrder.length &&
        _eliminated.contains(_turnOrder[nextIdx])) {
      nextIdx++;
    }
    if (nextIdx >= _turnOrder.length) {
      // Fin de set — évaluer avec joueurs restants
      _evaluateSet();
    } else {
      setState(() => _currentTurnIndex = nextIdx);
      _startTurnCountdown();
    }
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _introCtrl.dispose();
    _resultCtrl.dispose();
    _boardGlowCtrl.dispose();
    super.dispose();
  }

  int get _setsToWin => (widget.setsCount ~/ 2) + 1;
  bool get _isCibleMode => widget.ruleType == 'cible';
  String get _myId {
    final uid = ref.read(authProvider).user?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    return widget.players.isNotEmpty
        ? widget.players.first['id'].toString()
        : 'me';
  }

  // Source de vérité: serveur si disponible, sinon local
  int get _displaySet => (_serverMatch?['current_set'] as int?) ?? _currentSet;
  Map<String, int> get _displayWins {
    final scores = _serverMatch?['set_scores'] as Map?;
    if (scores != null && scores.isNotEmpty) {
      return {
        for (var e in scores.entries)
          e.key.toString(): (e.value as num).toInt(),
      };
    }
    return _setWins;
  }

  Set<String> get _displayEliminated {
    final elim = _serverMatch?['eliminated_players'] as List?;
    if (elim != null) return elim.map((e) => e.toString()).toSet();
    return _eliminated;
  }

  List<Map<String, dynamic>> get _activePlayers {
    final elim = _displayEliminated;
    return widget.players
        .where((p) => !elim.contains(p['id'].toString()))
        .toList();
  }

  List<String> get _turnOrder {
    final serverOrder = _serverSetState?['turn_order'] as List?;
    if (serverOrder != null && serverOrder.isNotEmpty) {
      return serverOrder.map((e) => e.toString()).toList();
    }
    final ids = widget.players.map((p) => p['id'].toString()).toList();
    if (_displaySet % 2 == 0) return ids.reversed.toList();
    return ids;
  }

  int get _displayTurnIndex {
    final idx = _serverSetState?['current_turn_index'] as int?;
    if (idx != null) return idx;
    return _currentTurnIndex;
  }

  String get _currentPlayerId {
    final order = _turnOrder;
    final idx = _displayTurnIndex;
    if (order.isEmpty) return '';
    if (idx >= order.length) return order.isNotEmpty ? order.last : '';
    final pid = order[idx];
    final elim = _displayEliminated;
    if (elim.contains(pid)) {
      int nxt = idx + 1;
      while (nxt < order.length && elim.contains(order[nxt])) {
        nxt++;
      }
      if (nxt < order.length) return order[nxt];
      final active = _activePlayers;
      return active.isNotEmpty ? active.first['id'].toString() : pid;
    }
    return pid;
  }

  String get _currentPlayerName {
    final pid = _currentPlayerId;
    final p = widget.players.firstWhere(
      (e) => e['id'].toString() == pid,
      orElse: () => {'name': 'Joueur'},
    );
    if (pid == _myId) return 'Moi';
    return p['name']?.toString() ?? 'Joueur';
  }

  bool get _isMyTurn =>
      _currentPlayerId == _myId &&
      !_displayEliminated.contains(_myId) &&
      !_showSetIntro &&
      !_showSetResult &&
      !_showMatchResult &&
      !_isVotingPhase;
  bool get _isEliminatedMe => _displayEliminated.contains(_myId);

  @override
  Widget build(BuildContext context) {
    return RealityCheckOverlay(
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: _buildAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isCompact = w < 620;
            return Column(
              children: [
                _buildMatchHeader(),
                if (_isVotingPhase)
                  Expanded(child: _buildVotingPhase())
                else if (_showMatchResult)
                  Expanded(child: _buildMatchResult())
                else if (_showSetIntro)
                  Expanded(child: _buildSetIntro())
                else if (_showSetResult)
                  Expanded(child: _buildSetResult())
                else
                  Expanded(
                    child: isCompact ? _buildCompactBoard() : _buildWideBoard(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isBetting = widget.betAmount > 0;
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: NeonColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: NeonColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'SET $_displaySet/${widget.setsCount}',
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: NeonColors.primary,
              ),
            ),
          ),
          if (isBetting) ...[
            const SizedBox(width: 8),
            const TokenCoin(
              size: 16,
              metal: TokenMetal.gold,
              lod: TokenLod.flat,
              showShadow: false,
            ),
            const SizedBox(width: 3),
            Text(
              '${widget.betAmount}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: NeonColors.tokenGold,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (_isCibleMode ? NeonColors.secondary : NeonColors.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    (_isCibleMode ? NeonColors.secondary : NeonColors.primary)
                        .withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              _isCibleMode ? 'CIBLE' : 'NORMAL',
              style: TextStyle(
                color: _isCibleMode ? NeonColors.secondary : NeonColors.primary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: NeonColors.surface,
      foregroundColor: NeonColors.primary,
      elevation: 0,
      actions: [
        if (isBetting)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(
              child: TokenCoin(
                size: 18,
                metal: TokenMetal.gold,
                lod: TokenLod.bevel,
                showShadow: false,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeonColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 11,
                    color: NeonColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_displaySet/${widget.setsCount}',
                    style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchHeader() {
    final showProgress = !_showSetIntro &&
        !_showSetResult &&
        !_showMatchResult &&
        !_isVotingPhase;
    final progressColor =
        _turnRemaining <= 5 ? NeonColors.warning : NeonColors.primary;
    // Header épuré: pas de redondance avec zones joueurs (tour indiqué uniquement via PlayerZone)
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        border: Border(
          bottom: BorderSide(color: NeonColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _headerChip(
                Icons.layers_outlined,
                'Sets $_displaySet/${widget.setsCount} • ${widget.diceCount} dé${widget.diceCount > 1 ? 's' : ''}',
              ),
              const SizedBox(width: 6),
              _headerChip(Icons.emoji_events_outlined, 'Premier à $_setsToWin'),
              const Spacer(),
              if (_isVotingPhase)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NeonColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: NeonColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.how_to_vote_rounded,
                        size: 11,
                        color: NeonColors.secondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VOTE',
                        style: TextStyle(
                          color: NeonColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_targetValue != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NeonColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: NeonColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Cible $_targetValue',
                    style: const TextStyle(
                      color: NeonColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (showProgress) ...[
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 12, color: progressColor),
                const SizedBox(width: 3),
                Text(
                  '$_turnRemaining s',
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _turnRemaining / _turnSeconds,
                minHeight: 3,
                backgroundColor: NeonColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: NeonColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // === BOARD layouts ===

  Widget _buildCompactBoard() {
    // Mobile/Tablette compact: tatami toujours visible, zones autour sans masquage
    final me = _buildPlayerZoneFor(_myId, isMe: true);
    final opponents =
        widget.players.where((p) => p['id'].toString() != _myId).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final isTiny = c.maxWidth < 360;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              if (opponents.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: isTiny ? 6 : 8,
                  runSpacing: isTiny ? 6 : 8,
                  children: opponents
                      .map(
                        (p) => SizedBox(
                          width: isTiny ? (c.maxWidth - 24) / 2 : 168,
                          child: _buildPlayerZoneFor(
                            p['id'].toString(),
                            isMe: false,
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: c.maxWidth * 0.96,
                  maxHeight: c.maxHeight * 0.55,
                ),
                child: _buildTatamiCenter(),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: me),
              const SizedBox(height: 8),
              _buildTurnHint(),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWideBoard() {
    // Desktop/Tablette large: tatami centré, zones autour sans jamais le masquer
    final me = _buildPlayerZoneFor(_myId, isMe: true);
    final opponents =
        widget.players.where((p) => p['id'].toString() != _myId).toList();
    final topOps = <Map<String, dynamic>>[];
    final leftOps = <Map<String, dynamic>>[];
    final rightOps = <Map<String, dynamic>>[];
    if (opponents.length == 1) {
      topOps.add(opponents[0]);
    } else if (opponents.length == 2) {
      leftOps.add(opponents[0]);
      rightOps.add(opponents[1]);
    } else if (opponents.length == 3) {
      topOps.add(opponents[0]);
      leftOps.add(opponents[1]);
      rightOps.add(opponents[2]);
    } else if (opponents.length >= 4) {
      topOps.add(opponents[0]);
      leftOps.addAll(opponents.sublist(1, (opponents.length ~/ 2) + 1));
      rightOps.addAll(opponents.sublist((opponents.length ~/ 2) + 1));
    }

    return LayoutBuilder(
      builder: (context, c) {
        final sideW = (c.maxWidth * 0.22).clamp(160.0, 220.0);
        final topW = (c.maxWidth * 0.26).clamp(180.0, 240.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              if (topOps.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: topOps
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SizedBox(
                            width: topW,
                            child: _buildPlayerZoneFor(
                              p['id'].toString(),
                              isMe: false,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (topOps.isNotEmpty) const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leftOps.isNotEmpty)
                      SizedBox(
                        width: sideW,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: leftOps
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildPlayerZoneFor(
                                      p['id'].toString(),
                                      isMe: false,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: _buildTatamiCenter()),
                          const SizedBox(height: 10),
                          _buildTurnHint(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (rightOps.isNotEmpty)
                      SizedBox(
                        width: sideW,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: rightOps
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildPlayerZoneFor(
                                      p['id'].toString(),
                                      isMe: false,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: me,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTatamiCenter() {
    final sum = _playerSums[_currentPlayerId];
    final showSum = sum != null && !_isRolling && !_isVotingPhase;
    final dice = _currentDice.isEmpty ? null : _currentDice;
    // Pour le tatami, afficher les dés du joueur courant s'il a lancé, sinon vide
    final displayDice = _isRolling
        ? List<int>.filled(widget.diceCount, 3)
        : (dice ?? (showSum ? _playerDice[_currentPlayerId] ?? [] : []));
    return DiceTatami(
      diceValues: displayDice,
      diceCount: widget.diceCount,
      isRolling: _isRolling,
      lastSum: showSum ? sum : null,
      targetLabel:
          _isCibleMode && _targetValue != null ? 'CIBLE $_targetValue' : null,
      maxWidth: 360,
    );
  }

  Widget _buildTurnHint() {
    if (_isEliminatedMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: NeonColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NeonColors.error.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 16, color: NeonColors.error),
            SizedBox(width: 6),
            Text(
              'Tu es éliminé — forfait',
              style: TextStyle(
                color: NeonColors.error,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    if (_isMyTurn) {
      return AnimatedBuilder(
        animation: _boardGlowCtrl,
        builder: (context, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: NeonColors.success
                .withValues(alpha: 0.14 + _boardGlowCtrl.value * 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: NeonColors.success.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: NeonColors.success.withValues(alpha: 0.22),
                blurRadius: 10,
              ),
            ],
          ),
          child: child,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.casino_rounded, size: 16, color: NeonColors.success),
            SizedBox(width: 6),
            Text(
              'À toi — clique sur le dé dans ta zone pour lancer',
              style: TextStyle(
                color: NeonColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            size: 14,
            color: NeonColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            'En attente de $_currentPlayerName',
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerZoneFor(String playerId, {required bool isMe}) {
    final raw = widget.players.firstWhere(
      (p) => p['id'].toString() == playerId,
      orElse: () => {'id': playerId, 'name': 'Joueur'},
    );
    final name = raw['name']?.toString() ?? 'Joueur';
    final displayName = isMe ? 'Moi' : name;
    final pid = playerId;
    final isActive = pid == _currentPlayerId &&
        !_eliminated.contains(pid) &&
        !_showSetIntro &&
        !_showSetResult &&
        !_showMatchResult &&
        !_isVotingPhase;
    final level = _deriveLevel(pid, name);
    final xpProg = _deriveXp(pid);
    final accent = isMe
        ? NeonColors.primary
        : (pid.hashCode % 3 == 0
            ? NeonColors.secondary
            : (pid.hashCode % 3 == 1 ? NeonColors.accent : NeonColors.primary));
    final score = _displayWins[pid] ?? 0;
    final lastSum = _playerSums[pid];
    final lastDice = _playerDice[pid];
    final isEliminated = _displayEliminated.contains(pid);
    final isWaiting = !isActive && !isEliminated;

    final data = PlayerZoneData(
      id: pid,
      name: name,
      displayName: displayName,
      score: score,
      level: level,
      xpProgress: xpProg,
      betAmount: widget.betAmount,
      isActiveTurn: isActive,
      isEliminated: isEliminated,
      isWaiting: isWaiting,
      lastSum: lastSum,
      lastDice: lastDice,
      setsToWin: _setsToWin,
      avatarLetter: name.isNotEmpty ? name[0] : '?',
      accent: accent,
    );

    final isMyZone = isMe;
    return PlayerZone(
      data: data,
      isMe: isMyZone,
      showTimer: isActive,
      turnSeconds: _turnSeconds,
      onTapDice: (isMyZone && isActive && !_isRolling) ? _rollDice : null,
      onTimeout: isActive ? _handleTimeout : null,
    );
  }

  int _deriveLevel(String pid, String name) {
    // Essaie depuis provider si possible, sinon hash
    try {
      // Si on a des stats globales, on pourrait interpoler
      final base = pid.hashCode.abs() % 30 + 1;
      final bonus = name.length % 5;
      return (base + bonus).clamp(1, 60);
    } catch (_) {
      return 5;
    }
  }

  int _deriveXp(String pid) {
    final h = pid.hashCode.abs();
    return (h % 97);
  }

  // === Intro / Result / Voting / MatchResult ===

  Widget _buildSetIntro() {
    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: _introCtrl, curve: Curves.elasticOut),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [NeonColors.primary, NeonColors.accent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: NeonColors.primary.withValues(alpha: 0.35),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SET $_currentSet',
              style: const TextStyle(
                color: NeonColors.primary,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontFamily: 'Orbitron',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'sur ${widget.setsCount}',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 15,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NeonColors.border),
              ),
              child: Text(
                _isCibleMode
                    ? 'Mode Cible — Votez la cible !'
                    : 'Mode Normal — Plus haut gagne',
                style: TextStyle(
                  color:
                      _isCibleMode ? NeonColors.secondary : NeonColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: NeonColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(NeonColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetResult() {
    final last = _setResults.isNotEmpty ? _setResults.last : null;
    final isTie = last?['result'] == 'tie';
    final winnerId = last?['winner_id']?.toString();
    final winnerName = isTie ? null : _findPlayerName(winnerId);
    final isMeWinner = winnerId == _myId;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                CurvedAnimation(
                  parent: _resultCtrl..forward(from: 0),
                  curve: Curves.elasticOut,
                ),
              ),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isTie
                          ? NeonColors.warning
                          : (isMeWinner
                              ? NeonColors.success
                              : NeonColors.primary))
                      .withValues(alpha: 0.14),
                  border: Border.all(
                    color: isTie
                        ? NeonColors.warning
                        : (isMeWinner
                            ? NeonColors.success
                            : NeonColors.primary),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isTie ? NeonColors.warning : NeonColors.success)
                          .withValues(alpha: 0.25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  isTie
                      ? Icons.horizontal_rule_rounded
                      : (isMeWinner
                          ? Icons.emoji_events_rounded
                          : Icons.casino_rounded),
                  color: isTie
                      ? NeonColors.warning
                      : (isMeWinner ? NeonColors.success : NeonColors.primary),
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isTie
                  ? 'SET NUL !'
                  : '${isMeWinner ? 'Moi' : winnerName} gagne le set !',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isTie
                    ? NeonColors.warning
                    : (isMeWinner ? NeonColors.success : NeonColors.primary),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            // Détails lancers modernes
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NeonColors.border),
              ),
              child: Column(
                children: widget.players.map((p) {
                  final pid = p['id'].toString();
                  final sum = last?['sums']?[pid] ?? _playerSums[pid] ?? 0;
                  final dice = _playerDice[pid] ?? [];
                  final isWinner = pid == winnerId;
                  final isMeP = pid == _myId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isWinner
                                ? NeonColors.success.withValues(alpha: 0.18)
                                : NeonColors.surface,
                            border: Border.all(
                              color: isWinner
                                  ? NeonColors.success
                                  : NeonColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (isMeP
                                  ? 'M'
                                  : p['name'].toString()[0].toUpperCase()),
                              style: TextStyle(
                                color: isWinner
                                    ? NeonColors.success
                                    : NeonColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isMeP ? 'Moi' : p['name'].toString(),
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (dice.isNotEmpty)
                          Row(
                            children: dice
                                .map(
                                  (v) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Dice3D(
                                      value: v,
                                      size: 26,
                                      borderColor: isWinner
                                          ? NeonColors.success
                                          : NeonColors.border,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isWinner
                                ? NeonColors.success.withValues(alpha: 0.14)
                                : NeonColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isWinner
                                  ? NeonColors.success.withValues(alpha: 0.4)
                                  : NeonColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '$sum',
                            style: TextStyle(
                              color: isWinner
                                  ? NeonColors.success
                                  : NeonColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ),
                        if (isWinner)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: 14,
                              color: NeonColors.success,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Score: ${widget.players.map((p) => '${p['id'].toString() == _myId ? 'Moi' : p['name']}: ${_displayWins[p['id'].toString()] ?? 0}').join('  •  ')}',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_isCibleMode && _targetValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Cible: $_targetValue',
                  style: const TextStyle(
                    color: NeonColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NeonButton(
                  text: isTie ? 'Rejouer le set' : 'Set suivant',
                  onPressed: _nextSet,
                  variant: NeonButtonVariant.primary,
                  icon: isTie
                      ? Icons.replay_rounded
                      : Icons.arrow_forward_rounded,
                ),
              ],
            ),
            if (_displayEliminated.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Éliminés: ${_displayEliminated.map((id) => id == _myId ? 'Moi' : _findPlayerName(id) ?? id).join(', ')}',
                style: const TextStyle(
                  color: NeonColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchResult() {
    final winsForCalc = _displayWins;
    final winnerEntry = winsForCalc.entries
            .where((e) => e.value >= _setsToWin)
            .isNotEmpty
        ? winsForCalc.entries.where((e) => e.value >= _setsToWin).first
        : (winsForCalc.entries.isEmpty
            ? null
            : winsForCalc.entries.reduce((a, b) => a.value > b.value ? a : b));
    final winnerId = winnerEntry?.key;
    final isMeWinner = winnerId == _myId;
    final winnerName = winnerId == null
        ? 'Match nul'
        : (isMeWinner ? 'Moi' : _findPlayerName(winnerId) ?? 'Joueur');
    final isBetting = widget.betAmount > 0;

    // Déterminer si forfait a décidé
    final forfeitDecided = _displayEliminated.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation victoire/défaite
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isMeWinner
                        ? [NeonColors.success, const Color(0xFF059669)]
                        : (winnerId == null
                            ? [NeonColors.warning, NeonColors.secondary]
                            : [NeonColors.error, const Color(0xFFDC2626)]),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isMeWinner ? NeonColors.success : NeonColors.error)
                              .withValues(alpha: 0.35),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isMeWinner
                      ? Icons.emoji_events_rounded
                      : (winnerId == null
                          ? Icons.handshake_rounded
                          : Icons.sentiment_dissatisfied_rounded),
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isMeWinner
                  ? 'VICTOIRE !'
                  : (winnerId == null ? 'MATCH NUL' : 'DÉFAITE'),
              style: TextStyle(
                color: isMeWinner
                    ? NeonColors.success
                    : (winnerId == null
                        ? NeonColors.warning
                        : NeonColors.error),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                fontFamily: 'Orbitron',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              forfeitDecided
                  ? (isMeWinner
                      ? 'Adversaire forfait — tu gagnes !'
                      : (_isEliminatedMe
                          ? 'Forfait — temps écoulé'
                          : '$winnerName gagne par forfait'))
                  : '$winnerName gagne !',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Score final: ${winnerEntry?.value ?? 0} sets',
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isBetting) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const TokenStack(
                    count: 5,
                    size: 28,
                    metal: TokenMetal.gold,
                    altMetal: TokenMetal.emerald,
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isMeWinner ? NeonColors.success : NeonColors.surface)
                              .withValues(alpha: isMeWinner ? 0.14 : 1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isMeWinner
                                ? NeonColors.success
                                : NeonColors.border)
                            .withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        if (isMeWinner)
                          BoxShadow(
                            color: NeonColors.success.withValues(alpha: 0.18),
                            blurRadius: 12,
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'GAINS',
                          style: TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 10,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TokenCoin(
                              size: 20,
                              metal: TokenMetal.gold,
                              lod: TokenLod.bevel,
                              showShadow: false,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isMeWinner ? '+${widget.betAmount * 2}' : '0',
                              style: TextStyle(
                                color: isMeWinner
                                    ? NeonColors.success
                                    : NeonColors.textSecondary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'wiga',
                          style: TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            NeonButton(
              text: 'Retour au jeu',
              onPressed: () => context.go('/games/dice'),
              variant: NeonButtonVariant.primary,
              icon: Icons.home_rounded,
            ),
            const SizedBox(height: 10),
            NeonButton(
              text: isMeWinner ? 'Revanche' : 'Rejouer',
              onPressed: () {
                // Reset et rejouer
                setState(() {
                  _currentSet = 1;
                  _currentTurnIndex = 0;
                  _setWins.updateAll((k, v) => 0);
                  _setResults.clear();
                  _playerDice.clear();
                  _playerSums.clear();
                  _currentDice = [];
                  _eliminated.clear();
                  _showMatchResult = false;
                  _showSetIntro = true;
                });
                _startSetIntro();
              },
              variant: NeonButtonVariant.secondary,
              icon: Icons.replay_rounded,
            ),
            const SizedBox(height: 10),
            NeonButton(
              text: 'Ajouter comme ami',
              onPressed: () async {
                final currentUserId = ref.read(authProvider).user?.id ?? '';
                final opponent = widget.players.firstWhere(
                  (p) => p['id'].toString() != currentUserId,
                  orElse: () => {},
                );
                if (opponent.isEmpty) return;
                final opponentId = int.tryParse(opponent['id'].toString());
                if (opponentId == null) return;
                final repo = ref.read(friendRepositoryProvider);
                try {
                  await repo.sendRequest(userId: opponentId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demande d\'ami envoyée !'),
                        backgroundColor: NeonColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erreur lors de l\'envoi'),
                        backgroundColor: NeonColors.error,
                      ),
                    );
                  }
                }
              },
              variant: NeonButtonVariant.outline,
              icon: Icons.person_add_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingPhase() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: NeonColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: NeonColors.secondary.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.how_to_vote_rounded,
                    color: NeonColors.secondary,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'VOTEZ POUR LA CIBLE',
                    style: TextStyle(
                      color: NeonColors.secondary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cible entre ${widget.diceCount} et ${widget.diceCount * 6}',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 320,
              child: NeonCard(
                child: Column(
                  children: [
                    SliderTheme(
                      data: const SliderThemeData(
                        activeTrackColor: NeonColors.secondary,
                        inactiveTrackColor: NeonColors.border,
                        thumbColor: NeonColors.secondary,
                      ),
                      child: Slider(
                        value: (_targetVotes[_myId] ??
                                ((_targetVotes[_currentPlayerId] ?? 7)))
                            .toDouble()
                            .clamp(
                              widget.diceCount.toDouble(),
                              (widget.diceCount * 6).toDouble(),
                            ),
                        min: widget.diceCount.toDouble(),
                        max: (widget.diceCount * 6).toDouble(),
                        divisions: (widget.diceCount * 6) - widget.diceCount,
                        label: '${_targetVotes[_myId] ?? 7}',
                        onChanged: _isEliminatedMe
                            ? null
                            : (v) =>
                                setState(() => _targetVotes[_myId] = v.round()),
                      ),
                    ),
                    Text(
                      '${_targetVotes[_myId] ?? 7}',
                      style: const TextStyle(
                        color: NeonColors.secondary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const SizedBox(height: 8),
                    NeonButton(
                      text: 'Voter',
                      onPressed: _isEliminatedMe ? () {} : _submitVote,
                      variant: NeonButtonVariant.secondary,
                      icon: Icons.check_rounded,
                      isEnabled: !_isEliminatedMe,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_targetVotes.length}/${widget.players.length} votes',
                      style: const TextStyle(
                        color: NeonColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_eliminated.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Éliminés: ${_eliminated.join(', ')}',
                  style: const TextStyle(color: NeonColors.error, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // === Actions ===

  void _rollDice() {
    if (_isRolling || _isEliminatedMe || !_isMyTurn) return;
    setState(() => _isRolling = true);
    _turnTimer?.cancel();

    // Si WebSocket connecté, déléguer au serveur
    if (_useWebSocket) {
      try {
        final ws = ref.read(gameWebSocketServiceProvider);
        ws.rollDice(widget.matchId);
        // L'animation sera déclenchée via onDiceRolled; en attendant, fausse animation
        final random = Random();
        int animCount = 0;
        Timer? timer;
        timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
          if (!mounted) {
            timer?.cancel();
            return;
          }
          setState(
            () => _currentDice =
                List.generate(widget.diceCount, (_) => random.nextInt(6) + 1),
          );
          animCount++;
          if (animCount >= 9) {
            timer?.cancel();
            // On attend la réponse serveur; fallback si pas de réponse en 1.5s
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && _isRolling) {
                // Fallback local (dev)
                _finalizeRollLocal();
              }
            });
          }
        });
        return;
      } catch (_) {}
    }

    // Fallback local (simulation)
    final random = Random();
    int animCount = 0;
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) {
        timer?.cancel();
        return;
      }
      setState(
        () => _currentDice =
            List.generate(widget.diceCount, (_) => random.nextInt(6) + 1),
      );
      animCount++;
      if (animCount >= 9) {
        timer?.cancel();
        _finalizeRollLocal();
      }
    });
  }

  void _finalizeRollLocal() {
    final random = Random.secure();
    final dice = List.generate(widget.diceCount, (_) => random.nextInt(6) + 1);
    final sum = dice.fold<int>(0, (a, b) => a + b);
    setState(() {
      _currentDice = dice;
      _playerDice[_currentPlayerId] = dice;
      _playerSums[_currentPlayerId] = sum;
      _isRolling = false;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final activeCount = _activePlayers.length;
      if (_playerSums.length >= activeCount ||
          _currentTurnIndex + 1 >= _turnOrder.length) {
        _evaluateSet();
      } else {
        // Trouver prochain non éliminé
        int next = _currentTurnIndex + 1;
        while (next < _turnOrder.length &&
            _eliminated.contains(_turnOrder[next])) {
          next++;
        }
        if (next >= _turnOrder.length) {
          _evaluateSet();
        } else {
          setState(() => _currentTurnIndex = next);
          _startTurnCountdown();
        }
      }
    });
  }

  void _evaluateSet() {
    _turnTimer?.cancel();
    final sums = Map<String, int>.from(_playerSums);
    // Filtrer éliminés
    sums.removeWhere((k, v) => _eliminated.contains(k));
    if (sums.isEmpty) {
      // Tous éliminés ou pas de lancers → set nul
      setState(() {
        _setResults.add({
          'set_number': _currentSet,
          'result': 'tie',
          'winner_id': null,
          'sums': _playerSums,
        });
        _showSetResult = true;
      });
      _resultCtrl.forward(from: 0);
      return;
    }

    String? winnerId;
    String result;
    if (_isCibleMode && _targetValue != null) {
      // Plus proche de la cible
      final distances =
          sums.map((pid, s) => MapEntry(pid, (s - _targetValue!).abs()));
      final minDist = distances.values.reduce(min);
      final winners =
          distances.entries.where((e) => e.value == minDist).toList();
      if (winners.length == 1) {
        winnerId = winners.first.key;
        result = 'winner';
        _setWins[winnerId] = (_setWins[winnerId] ?? 0) + 1;
      } else {
        result = 'tie';
      }
    } else {
      final maxSum = sums.values.fold<int>(0, max);
      final winners = sums.entries.where((e) => e.value == maxSum).toList();
      if (winners.length == 1) {
        winnerId = winners.first.key;
        result = 'winner';
        _setWins[winnerId] = (_setWins[winnerId] ?? 0) + 1;
      } else {
        result = 'tie';
      }
    }

    setState(() {
      _setResults.add({
        'set_number': _currentSet,
        'result': result,
        'winner_id': winnerId,
        'sums': Map<String, int>.from(_playerSums),
      });
      _showSetResult = true;
    });
    _resultCtrl.forward(from: 0);
    if (_setWins.values.any((v) => v >= _setsToWin)) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showMatchResult = true);
      });
    }
  }

  void _nextSet() {
    // Toujours incrémenter — cohérence avec backend (tie compte comme set)
    if (_useWebSocket) {
      try {
        ref.read(gameWebSocketServiceProvider).startSet(widget.matchId);
      } catch (_) {}
      setState(() {
        _showSetResult = false;
        _showSetIntro = true;
        _currentDice = [];
        _playerDice.clear();
        _playerSums.clear();
      });
      _introCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _showSetIntro) {
          setState(() => _showSetIntro = false);
          _startTurnCountdown();
        }
      });
      return;
    }
    setState(() {
      _currentSet++;
      _currentTurnIndex = 0;
      while (_currentTurnIndex < _turnOrder.length &&
          _displayEliminated.contains(_turnOrder[_currentTurnIndex])) {
        _currentTurnIndex++;
      }
      _currentDice = [];
      _playerDice = {};
      _playerSums = {};
      _showSetResult = false;
      _showSetIntro = true;
      _isVotingPhase = _isCibleMode && _targetValue == null;
      if (_displayEliminated.length >= widget.players.length - 1) {
        _showMatchResult = true;
        _showSetIntro = false;
        _isVotingPhase = false;
      }
    });
    if (_showMatchResult) return;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSetIntro = false);
      _startTurnCountdown();
    });
  }

  void _submitVote() {
    final myVote = _targetVotes[_myId] ?? 7;
    setState(() => _targetVotes[_myId] = myVote);
    // Si WebSocket, envoyer vote
    if (_useWebSocket) {
      try {
        ref
            .read(gameWebSocketServiceProvider)
            .voteTarget(widget.matchId, myVote);
      } catch (_) {}
    }
    // Si tous ont voté, calculer cible localement (fallback)
    if (_targetVotes.length >= widget.players.length) {
      final sum = _targetVotes.values.fold<int>(0, (a, b) => a + b);
      final target = (sum / _targetVotes.length).round();
      setState(() {
        _targetValue = target;
        _isVotingPhase = false;
      });
      _startTurnCountdown();
    } else {
      // Simuler votes adverses pour démo si pas de WS
      if (!_useWebSocket) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          final rnd = Random();
          for (var p in widget.players) {
            final pid = p['id'].toString();
            if (!_targetVotes.containsKey(pid) && pid != _myId) {
              _targetVotes[pid] =
                  rnd.nextInt(widget.diceCount * 6 - widget.diceCount + 1) +
                      widget.diceCount;
            }
          }
          final s = _targetVotes.values.fold<int>(0, (a, b) => a + b);
          setState(() {
            _targetValue = (s / _targetVotes.length).round();
            _isVotingPhase = false;
          });
          _startTurnCountdown();
        });
      }
    }
  }

  String? _findPlayerName(String? playerId) {
    if (playerId == null) return null;
    if (playerId == _myId) return 'Moi';
    final p = widget.players
        .firstWhere((e) => e['id'].toString() == playerId, orElse: () => {});
    return p.isNotEmpty ? p['name']?.toString() : 'Joueur';
  }

  bool _checkMatchOver() {
    return _displayWins.values.any((v) => v >= _setsToWin) ||
        _displayEliminated.length >= widget.players.length - 1;
  }
}

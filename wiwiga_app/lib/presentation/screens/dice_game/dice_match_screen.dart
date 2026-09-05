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
import '../../widgets/game/reality_check_overlay.dart';
import '../../widgets/game/dice_tatami.dart';
import '../../widgets/game/dice_3d.dart';
import '../../widgets/game/player_zone.dart';
import '../../../core/errors/api_exception.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/friend_provider.dart';
import '../../../data/providers/token_provider.dart';
import '../../../data/providers/game_stats_providers.dart';
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
  final Map<String, List<int>> _playerDice = {};
  final Map<String, int> _playerSums = {};
  Set<String> _eliminated = {};
  // Plus de _turnTimer parent : chaque PlayerZone gère son propre TurnTimer
  // via deadline serveur (évite double ticker + deadline repoussée par polling).
  Timer? _rollAnimTimer;
  Timer? _rollFallbackTimer;
  Timer? _rollRevealTimer;
  Timer? _syncPollTimer;
  int _turnSeconds = 30;
  int _turnRemaining = 30;
  DateTime? _turnDeadline;
  // Lancer synchronisé : tous les joueurs voient la même animation puis le
  // même résultat au même moment (serveur = arbitre, reveal commun).
  String? _rollingPlayerId;
  String? _lastRollerId;
  int? _lastRollSum;
  DateTime? _rollAnimStartedAt;
  // Durée min d'animation commune avant révélation (synchro tous joueurs)
  static const Duration _minRollAnim = Duration(milliseconds: 950);
  Map<String, dynamic>? _pendingReveal;
  // Ma demande de lancer en vol (anti-double-tap). Séparé de _isRolling qui
  // est purement visuel (anim du tatami, y compris celle des autres) : le
  // bouton du joueur suivant ne doit JAMAIS être verrouillé par l'anim du
  // joueur précédent, sinon il faut cliquer plusieurs fois.
  bool _isSendingRoll = false;

  // Revanche opt-out (fin de partie) : lobby serveur synchronisé.
  Map<String, dynamic>? _rematchLobby;
  bool _confirmRematch = false;
  bool _rematchBusy = false;
  final Set<String> _rematchNavDone = {};
  int _postMatchEmptyPolls = 0;

  // Serveur source de vérité
  Map<String, dynamic>? _serverMatch;
  Map<String, dynamic>? _serverSetState;
  // Ordre des events serveur (seq monotone backend) — ignore les events stale/doublons
  int _lastSeq = -1;
  DateTime? _lastWsEventAt;
  // Id joueur résolu (auth prioritaire, jamais de fallback ambigu)
  String _resolvedMyId = '';

  // WebSocket state
  bool _useWebSocket = false;
  VoidCallback? _wsListener;

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
    _resolveMyId();
    _loadTurnTimeout();
    _initWebSocket();
    _fetchInitialState();
    _startSyncPolling();
    _startSetIntro();
  }

  /// Résout l'identité locale UNE fois depuis l'auth (source unique).
  /// Ne devine jamais : si auth absente, on attend (évite que 2 appareils
  /// se prennent tous deux pour le 1er joueur → tours figés).
  void _resolveMyId() {
    try {
      final uid = ref.read(authProvider).user?.id.toString();
      if (uid != null && uid.isNotEmpty) {
        _resolvedMyId = uid;
        return;
      }
    } catch (_) {}
    // Auth pas encore restaurée : réessaie au prochain build via _myId getter.
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

  Future<void> _fetchInitialState() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _serverMatch != null) return;
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data = await repo.getMatchStateRest(widget.matchId);
      if (data.isNotEmpty && mounted) {
        if (data.containsKey('match_id')) {
          _syncFromServer(data);
        } else if (data['data'] is Map) {
          _syncFromServer(Map<String, dynamic>.from(data['data'] as Map));
        }
        final status =
            data['status']?.toString() ?? _serverMatch?['status']?.toString();
        if (status == 'set_ended') {
          setState(() {
            _showSetIntro = false;
            _showSetResult = true;
          });
        } else if (status == 'match_ended') {
          setState(() {
            _showSetIntro = false;
            _showSetResult = false;
            _showMatchResult = true;
          });
        }
      }
    } catch (_) {}
    if (_serverMatch == null && mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || _serverMatch != null) return;
      try {
        final repo = ref.read(gameRepositoryProvider);
        final data = await repo.getMatchStateRest(widget.matchId);
        if (data.isNotEmpty && data.containsKey('match_id')) {
          _syncFromServer(data);
        }
      } catch (_) {}
    }
  }

  void _syncFromServer(Map<String, dynamic> match, {int? seq}) {
    if (!mounted) return;
    // Ignore les events stale/doublons (double broadcast backend supprimé,
    // mais PubSub + polling peuvent encore se chevaucher).
    if (seq != null) {
      if (seq <= _lastSeq) return;
      _lastSeq = seq;
    }
    _lastWsEventAt = DateTime.now();
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
      // Lobby revanche synchronisé (serveur) : tous voient les mêmes
      // acceptations/refus en temps réel.
      final rm = match['rematch'];
      if (rm is Map) {
        final status = rm['status']?.toString();
        if (status == null || status == 'none') {
          _rematchLobby = null;
        } else {
          _rematchLobby = Map<String, dynamic>.from(rm);
          _confirmRematch = false;
          if (status == 'started') {
            final newId = rm['new_match_id']?.toString();
            final accepted = rm['accepted'] is List
                ? (rm['accepted'] as List).map((e) => e.toString()).toSet()
                : <String>{};
            if (newId != null &&
                newId.isNotEmpty &&
                !_rematchNavDone.contains(newId)) {
              if (accepted.contains(_myId)) {
                _rematchNavDone.add(newId);
                Future.microtask(() {
                  if (mounted) _fetchAndOpenRematch(newId);
                });
              } else {
                _rematchLobby = null;
              }
            }
          }
        }
      }
      final cs = match['current_set'] as int?;
      if (cs != null && cs > 0) _currentSet = cs;
      final css = _serverSetState;
      if (css != null) {
        final tv = css['target_value'] as int?;
        if (tv != null) _targetValue = tv;
        if (css['target_value'] == null &&
            _targetValue != null &&
            css['vote_phase'] == false) {
          // garder ancienne cible
        }
        _isVotingPhase = css['vote_phase'] == true;
        final votesMap = css['votes'] as Map?;
        if (votesMap != null) {
          _targetVotes.clear();
          for (var e in votesMap.entries) {
            _targetVotes[e.key.toString()] = (e.value as num).toInt();
          }
        }
        // Synchroniser les lancers déjà effectués dans le set courant.
        // IMPORTANT : on met à jour les zones individuelles par clé (déterministe),
        // mais JAMAIS le tatami depuis l'ordre d'itération de la map (non
        // déterministe en Elixir/JSON). Le tatami suit uniquement `last_roll` /
        // `last_roller_id` explicites du serveur, ou l'event `dice_rolled`.
        final rolls = css['rolls'] as Map?;
        if (rolls != null) {
          for (var e in rolls.entries) {
            final pid = e.key.toString();
            final rawRoll = e.value;
            final roll = rawRoll is Map<String, dynamic>
                ? rawRoll
                : rawRoll is Map
                    ? Map<String, dynamic>.from(rawRoll)
                    : null;
            if (roll != null) {
              final dice = List<int>.from(roll['dice'] as List? ?? []);
              final sum =
                  roll['sum'] as int? ?? dice.fold<int>(0, (a, b) => a + b);
              if (dice.isNotEmpty && dice.any((d) => d != 0)) {
                _playerDice[pid] = dice;
                _playerSums[pid] = sum;
              } else if (dice.isNotEmpty) {
                // Lancer forfait (timeout) : 0 — visible aussi chez les autres
                _playerDice[pid] = dice;
                _playerSums[pid] = sum;
              }
            }
          }
          // Tatami via last_roll explicite (pas d'itération de map).
          final lastRollRaw = match['last_roll'];
          final lastRollerRaw = match['last_roller_id']?.toString() ??
              match['lastRollerId']?.toString();
          if (lastRollRaw is Map && lastRollerRaw != null) {
            final lastRoll = lastRollRaw is Map<String, dynamic>
                ? lastRollRaw
                : Map<String, dynamic>.from(lastRollRaw);
            final dice = List<int>.from(lastRoll['dice'] as List? ?? []);
            final sum =
                lastRoll['sum'] as int? ?? dice.fold<int>(0, (a, b) => a + b);
            if (dice.isNotEmpty && !_isRolling) {
              // Ne pas écraser une révélation planifiée plus récente
              if (_pendingReveal == null) {
                _currentDice = dice;
                _lastRollerId = lastRollerRaw;
                _lastRollSum = sum;
              }
            } else if (_currentDice.isEmpty && dice.isNotEmpty) {
              _currentDice = dice;
              _lastRollerId = lastRollerRaw;
              _lastRollSum = sum;
            }
          }
        }
        // Synchroniser index de tour serveur
        final idx = css['current_turn_index'] as int?;
        if (idx != null) {
          _currentTurnIndex = idx;
        }
        // Timeout serveur (évite dérive horloge)
        final timeoutMs =
            match['turn_timeout_ms'] as int? ?? css['turn_timeout_ms'] as int?;
        if (timeoutMs != null && timeoutMs > 0) {
          _turnSeconds = (timeoutMs ~/ 1000).clamp(15, 180);
        }
        // Timing serveur : on stocke deadline + remaining SANS ticker parent.
        // Chaque PlayerZone fait son propre décompte via TurnTimer (source unique).
        // Ne pas recréer de Timer ici (évite deadline repoussée à chaque polling).
        final remSec = css['turn_remaining_seconds'] as int? ??
            match['turn_remaining_seconds'] as int?;
        if (remSec != null) {
          _turnRemaining = remSec.clamp(0, _turnSeconds);
          _turnDeadline = DateTime.now().add(Duration(seconds: _turnRemaining));
        } else {
          final dlStr = css['turn_deadline']?.toString() ??
              match['turn_deadline']?.toString();
          if (dlStr != null) {
            try {
              _turnDeadline = DateTime.parse(dlStr);
              final diff = _turnDeadline!.difference(DateTime.now()).inSeconds;
              _turnRemaining = diff.clamp(0, _turnSeconds);
              if (diff > _turnSeconds) {
                _turnSeconds = diff.clamp(15, 180);
                _turnRemaining = diff.clamp(0, _turnSeconds);
              }
            } catch (_) {}
          } else if (css['vote_phase'] == true) {
            // Phase vote : pas de deadline de tour, les zones n'affichent pas de timer.
            _turnDeadline = null;
          }
        }
        final status = match['status']?.toString();
        if (status == 'set_in_progress' && !_isVotingPhase) {
          _showSetIntro = false;
          _showSetResult = false;
          // Ne PAS toucher _isRolling ici : l'animation/reveal est pilotée
          // exclusivement par dice_rolling/dice_rolled (sinon turn_changed,
          // émis juste après dice_rolled, tuerait l'anim avant révélation).
        }
        if (status == 'set_ended') {
          // Ne pas couper un reveal en cours : le résultat du set s'affiche
          // après la révélation (voir _scheduleReveal -> set_result).
          if (_pendingReveal == null && !_isRolling) {
            _isRolling = false;
          }
        }
      }
      if (match['status']?.toString() == 'match_ended') {
        _showMatchResult = true;
        _showSetIntro = false;
        _showSetResult = false;
        // Si un reveal est en cours, il terminera avant l'affichage final
        // (le overlay match recouvre de toute façon le tatami).
        _rollAnimTimer?.cancel();
        _rollFallbackTimer?.cancel();
        // Pas de ticker parent : les TurnTimer des zones disparaissent
        // automatiquement car isActive devient faux (_showMatchResult).
        _turnDeadline = null;
      }
    });
  }

  // Supprimé : _startTurnCountdownFromDeadline (ticker parent).
  // Le décompte est assuré par TurnTimer dans chaque PlayerZone active,
  // piloté par _turnDeadline/_turnRemaining serveur (synchrone pour tous).

  Future<void> _initWebSocket() async {
    try {
      final ws = ref.read(gameWebSocketServiceProvider);
      final api = ref.read(apiServiceProvider);
      // Listener reconnexion : re-join game channel automatiquement (synchro tour)
      _wsListener = () {
        if (!mounted) return;
        final live = ws.isConnected;
        final reconnected = live && !_useWebSocket;
        if (live) {
          try {
            ws.joinGame(widget.matchId);
          } catch (_) {}
        }
        if (_useWebSocket != live) {
          setState(() => _useWebSocket = live);
        }
        // Reconnexion uniquement : le join repousse l'état complet
        // (match_state) ; réconciliation en plus pour ne rater ni tour
        // ni revanche. (Pas à chaque event : éviter une tempête REST.)
        if (reconnected) _refreshFromServer();
      };
      ws.addListener(_wsListener!);
      // Auth WS avec vrai user_id (évite guest → not_your_turn)
      try {
        final token = await api.getAccessToken();
        if (token != null && token.isNotEmpty) ws.setAuthToken(token);
      } catch (_) {}
      // Assurer connexion (auto-récupère token si manquant)
      try {
        await ws.connect();
      } catch (_) {}
      // Définir callbacks AVANT join pour ne pas rater push_match_state
      // Wallet / stats temps réel : plus besoin de reload page
      ws.onWalletUpdate = (payload) {
        if (!mounted) return;
        try {
          ref.read(tokenProvider.notifier).loadSummary();
          ref.read(tokenProvider.notifier).loadTransactions();
        } catch (_) {}
        try {
          ref.read(walletProvider.notifier).loadBalance();
        } catch (_) {}
      };
      ws.onStatsUpdate = (payload) {
        if (!mounted) return;
        try {
          ref.invalidate(gameStatsProvider);
          ref.invalidate(tokenProvider);
        } catch (_) {}
      };
      ws.onSetStarted = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>? ?? payload;
        _rollRevealTimer?.cancel();
        _pendingReveal = null;
        _rollingPlayerId = null;
        _syncFromServer(match, seq: payload['seq'] as int?);
        setState(() {
          _showSetResult = false;
          _showSetIntro = true;
          _currentDice = [];
          _lastRollerId = null;
          _lastRollSum = null;
          _playerDice.clear();
          _playerSums.clear();
          _isRolling = false;
        });
        _introCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _showSetIntro = false);
        });
      };
      ws.onDiceRolling = (payload) {
        if (!mounted) return;
        String rollerId = payload['roller_id']?.toString() ??
            payload['rollerId']?.toString() ??
            '';
        if (rollerId.isEmpty) {
          // Repli : tour courant du match joint au payload
          final m = payload['match'];
          if (m is Map) {
            final mm = Map<String, dynamic>.from(m);
            final css = mm['current_set_state'];
            if (css is Map) {
              final order = css['turn_order'];
              final idx = css['current_turn_index'];
              if (order is List && order.isNotEmpty && idx is int) {
                final safeIdx = idx.clamp(0, order.length - 1);
                rollerId = order[safeIdx]?.toString() ?? '';
              }
            }
          }
        }
        if (rollerId.isEmpty) rollerId = _currentPlayerId;
        if (rollerId.isNotEmpty) {
          final diceCount = payload['dice_count'] as int? ?? _displayDiceCount;
          _handleDiceRolling(rollerId, diceCount: diceCount);
        }
      };
      ws.onDiceRolled = (payload) {
        if (!mounted) return;
        _rollFallbackTimer?.cancel();
        final match = payload['match'] as Map<String, dynamic>?;
        final roll = payload['roll'] as Map<String, dynamic>? ?? payload;
        final dice = List<int>.from(
          roll['dice'] ?? roll['dice_results'] ?? roll['diceValues'] ?? [],
        );
        final sum = roll['sum'] as int? ?? roll['total_sum'] as int?;
        final playerId =
            roll['player_id']?.toString() ?? roll['playerId']?.toString() ?? '';
        if (dice.isNotEmpty) {
          _handleDiceRolledEvent(
            playerId: playerId.isNotEmpty ? playerId : (_lastRollerId ?? ''),
            dice: dice,
            sum: sum ?? dice.fold<int>(0, (a, b) => a + b),
            match: match,
            seq: payload['seq'] as int?,
          );
        } else {
          if (match != null)
            _syncFromServer(match, seq: payload['seq'] as int?);
          _rollRevealTimer?.cancel();
          _pendingReveal = null;
          // Ne lever l'anti-double-tap que si ce n'est pas l'anim d'un autre.
          _isSendingRoll = false;
          if (_rollingPlayerId == null || _rollingPlayerId == _myId) {
            _rollingPlayerId = null;
            setState(() => _isRolling = false);
          }
        }
        // fallback local supprimé — polling REST garantit synchro même si match null
      };
      ws.onTurnChanged = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) {
          _syncFromServer(match, seq: payload['seq'] as int?);
          return;
        }
        final index = payload['current_turn_index'];
        if (index is num) {
          setState(() => _currentTurnIndex = index.toInt());
        }
      };
      ws.onSetResult = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match, seq: payload['seq'] as int?);
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
        if (match != null) _syncFromServer(match, seq: payload['seq'] as int?);
        setState(() => _showMatchResult = true);
        try {
          ref.read(tokenProvider.notifier).loadSummary();
          ref.read(tokenProvider.notifier).loadTransactions();
        } catch (_) {}
        try {
          ref.read(walletProvider.notifier).loadBalance();
        } catch (_) {}
      };
      ws.onTargetVoted = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match, seq: payload['seq'] as int?);
        final target = payload['target_value'] as int? ??
            payload['target'] as int? ??
            _serverSetState?['target_value'] as int?;
        if (target != null) {
          setState(() {
            _targetValue = target;
            _isVotingPhase = false;
          });
        } else {
          setState(() {});
        }
      };
      ws.onPlayerForfeited = (payload) {
        if (!mounted) return;
        final match = payload['match'] as Map<String, dynamic>?;
        if (match != null) _syncFromServer(match, seq: payload['seq'] as int?);
        final pid =
            payload['player_id']?.toString() ?? payload['playerId']?.toString();
        if (pid == null) return;
        final elimList = (match?['eliminated_players'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {};
        final isEliminatedFromMatch = elimList.contains(pid);
        final isMatchEnded = match?['status'] == 'match_ended';
        final css = match?['current_set_state'] as Map<String, dynamic>?;
        final rolls = css?['rolls'] as Map?;
        final roll = rolls?[pid] as Map<String, dynamic>?;
        final isForfeitedTurn = roll?['forfeited'] == true ||
            (roll?['sum'] == 0 &&
                roll?['dice'] is List &&
                (roll?['dice'] as List).every((d) => d == 0));
        if (isEliminatedFromMatch) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_findPlayerName(pid) ?? pid} forfait — éliminé du match',
              ),
              backgroundColor: NeonColors.error,
            ),
          );
        } else if (isForfeitedTurn || !isMatchEnded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_findPlayerName(pid) ?? pid} a perdu le set (temps écoulé)',
              ),
              backgroundColor: NeonColors.warning,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_findPlayerName(pid) ?? pid} forfait'),
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
        _syncFromServer(match, seq: payload['seq'] as int?);
      };
      // Revanche opt-out : lobby synchronisé pour tous les joueurs restants.
      ws.onRematchProposed = (payload) {
        if (!mounted) return;
        _syncRematchPayload(payload, fallbackEvent: 'propose');
      };
      ws.onRematchUpdated = (payload) {
        if (!mounted) return;
        _syncRematchPayload(payload, fallbackEvent: 'update');
      };
      ws.onRematchReady = (payload) {
        if (!mounted) return;
        final lobby = payload['lobby'];
        if (lobby is Map) {
          _rematchLobby = Map<String, dynamic>.from(lobby);
        }
        final match = payload['match'];
        if (match is Map) {
          _syncFromServer(
            Map<String, dynamic>.from(match),
            seq: payload['seq'] as int?,
          );
        }
        _openRematchIfAccepted(payload);
      };
      ws.onRematchCancelled = (payload) {
        if (!mounted) return;
        final match = payload['match'];
        if (match is Map) {
          _syncFromServer(
            Map<String, dynamic>.from(match),
            seq: payload['seq'] as int?,
          );
        } else {
          setState(() {
            _rematchLobby = null;
            _confirmRematch = false;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Revanche annulée'),
              backgroundColor: NeonColors.textSecondary,
            ),
          );
        }
      };
      // Erreurs channel immédiates (not_your_turn, etc.) : sort du mode rolling
      // sans attendre le fallback REST de 3s → UI réactive pour tous.
      ws.onChannelError = (err) {
        if (!mounted) return;
        // Lever l'anti-double-tap pour permettre de rejouer immédiatement.
        // Ne couper l'animation que si c'était la mienne.
        final rollingMine =
            _rollingPlayerId == null || _rollingPlayerId == _myId;
        _isSendingRoll = false;
        if (_isRolling && rollingMine) {
          _rollAnimTimer?.cancel();
          _rollRevealTimer?.cancel();
          _pendingReveal = null;
          _rollingPlayerId = null;
          setState(() => _isRolling = false);
        }
        final reason = err['reason']?.toString() ?? '';
        String? userMsg;
        if (reason.contains('not_your_turn')) {
          userMsg = "Ce n'est pas votre tour";
        } else if (reason.contains('already_rolled')) {
          userMsg = 'Vous avez déjà lancé ce tour';
        } else if (reason.contains('voting_phase')) {
          userMsg = 'Phase de vote en cours';
        } else if (reason.contains('eliminated')) {
          userMsg = 'Vous êtes éliminé';
        }
        if (userMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMsg),
              backgroundColor: NeonColors.warning,
            ),
          );
          // Re-synchronise depuis le serveur (tour réel).
          _refreshFromServer();
        }
      };
      ws.onRoomUpdated = (payload) {
        final room = payload['room'] as Map<String, dynamic>? ?? payload;
        final mid = room['match_id']?.toString();
        if (mid != null && mid == widget.matchId) {}
      };
      // Rejoindre le match channel + user channel pour wallet/stats temps réel
      ws.joinGame(widget.matchId);
      try {
        ws.joinUserChannel(_myId);
      } catch (_) {}
      final isWsLive = ws.isConnected;
      if (mounted) setState(() => _useWebSocket = isWsLive);
    } catch (_) {
      _useWebSocket = false;
    }
  }

  void _startSetIntro() {
    _introCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showSetIntro = false);
      // Timing serveur uniquement : la deadline arrive via _syncFromServer
      // (WS match_state/turn_changed ou polling). Pas de deadline locale.
      if (_isCibleMode && _targetValue == null) {
        setState(() => _isVotingPhase = true);
      }
    });
  }

  // Supprimé : _startTurnCountdown local (devinait une deadline).
  // Le serveur est l'unique arbitre : deadline/remaining viennent de
  // _syncFromServer (WS turn_changed/dice_rolled ou polling REST).

  void _handleTimeout() {
    // Serveur = source unique : le turn_timeout backend émet déjà
    // player_forfeited + turn_changed/set_result via PubSub.
    // Ici on ne simule JAMAIS localement (évite divergence entre joueurs).
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
    // Fallback REST : réconciliation serveur immédiate au lieu d'évaluation locale.
    _refreshFromServer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temps écoulé — synchronisation...'),
          backgroundColor: NeonColors.warning,
        ),
      );
    }
  }

  @override
  void dispose() {
    _rollAnimTimer?.cancel();
    _rollFallbackTimer?.cancel();
    _rollRevealTimer?.cancel();
    _syncPollTimer?.cancel();
    // Sortie d'interface de fin de partie : le joueur est exclu des
    // revanches (le nombre de participants s'ajuste). Best effort, idempotent.
    if (_showMatchResult || _serverMatch?['status'] == 'match_ended') {
      _leaveFinishedMatch();
    }
    if (_wsListener != null) {
      try {
        ref.read(gameWebSocketServiceProvider).removeListener(_wsListener!);
      } catch (_) {}
    }
    _introCtrl.dispose();
    _resultCtrl.dispose();
    _boardGlowCtrl.dispose();
    super.dispose();
  }

  void _startSyncPolling() {
    _syncPollTimer?.cancel();
    // Réconciliation REST : filet de sécurité si un event WS est perdu.
    // WS = temps réel (<1s), REST = garantie (toutes les 2s).
    // On ne re-synchronise QUE si quelque chose a changé (index, status,
    // rolls, cible, votes) : sinon on garderait une deadline recréée à chaque
    // polling et les TurnTimer des zones seraient sans cesse réinitialisés.
    _syncPollTimer =
        Timer.periodic(const Duration(milliseconds: 2000), (_) async {
      if (!mounted) return;
      // Après fin de partie, le polling continue tant qu'une revanche est
      // active (filet pour clients sans WS) ; sinon il s'arrête.
      if (_showMatchResult && _rematchLobby == null) {
        // Si le WS est en vie, les broadcasts couvrent les propositions.
        try {
          if (ref.read(gameWebSocketServiceProvider).isConnected) {
            _syncPollTimer?.cancel();
            return;
          }
        } catch (_) {}
        // Sans WS : une dernière veille courte pour capter une proposition,
        // puis arrêt (évite de poller indéfiniment).
        _postMatchEmptyPolls++;
        if (_postMatchEmptyPolls > 45) {
          _syncPollTimer?.cancel();
          return;
        }
        // Vérifier une dernière fois si une revanche vient d'être proposée
        // avant de couper (évite de rater une proposition sans WS).
        try {
          final repo = ref.read(gameRepositoryProvider);
          final data = await repo.getMatchStateRest(widget.matchId);
          if (!mounted) return;
          final match = data.containsKey('match_id')
              ? data
              : data['data'] is Map
                  ? Map<String, dynamic>.from(data['data'] as Map)
                  : null;
          final rm = match?['rematch'];
          if (rm is Map && rm['status']?.toString() == 'proposed') {
            _postMatchEmptyPolls = 0;
            _syncFromServer(match!);
            return;
          }
        } catch (_) {}
        _syncPollTimer?.cancel();
        return;
      }
      try {
        final ws = ref.read(gameWebSocketServiceProvider);
        final wsLive = ws.isConnected;
        final lastWsAge = _lastWsEventAt == null
            ? null
            : DateTime.now().difference(_lastWsEventAt!);
        // Fenêtre courte (2s) : laisse le WS propager d'abord, puis vérifie.
        // Avant : 10s → UI figée 10s si un event était ignoré (filtre seq).
        if (wsLive && lastWsAge != null && lastWsAge.inSeconds < 2) {
          return;
        }
      } catch (_) {}
      try {
        final repo = ref.read(gameRepositoryProvider);
        final data = await repo.getMatchStateRest(widget.matchId);
        if (!mounted) return;
        Map<String, dynamic>? match;
        if (data.containsKey('match_id')) {
          match = data;
        } else if (data['data'] is Map) {
          match = Map<String, dynamic>.from(data['data'] as Map);
        } else if (data.isNotEmpty) {
          match = data;
        }
        if (match != null && match.containsKey('match_id')) {
          final css = match['current_set_state'] as Map<String, dynamic>?;
          final newIdx = css?['current_turn_index'] as int?;
          final oldIdx = _serverSetState?['current_turn_index'] as int?;
          final newStatus = match['status']?.toString();
          final oldStatus = _serverMatch?['status']?.toString();
          final newRollsCount =
              css?['rolls'] is Map ? (css!['rolls'] as Map).length : 0;
          final oldRollsCount = _serverSetState?['rolls'] is Map
              ? (_serverSetState!['rolls'] as Map).length
              : 0;
          final newTarget = css?['target_value'];
          final oldTarget = _serverSetState?['target_value'];
          final newVotesCount =
              css?['votes'] is Map ? (css!['votes'] as Map).length : 0;
          final oldVotesCount = _serverSetState?['votes'] is Map
              ? (_serverSetState!['votes'] as Map).length
              : 0;
          final newScores = match['set_scores'].toString();
          final oldScores = _serverMatch?['set_scores'].toString();
          final newRematch = match['rematch']?.toString() ?? '';
          final oldRematch = _serverMatch?['rematch']?.toString() ?? '';
          final shouldSync = newIdx != oldIdx ||
              newStatus != oldStatus ||
              newRollsCount != oldRollsCount ||
              newTarget != oldTarget ||
              newVotesCount != oldVotesCount ||
              newScores != oldScores ||
              newRematch != oldRematch;
          // Sans changement : ne rien faire (préserve deadline + timers zones).
          if (!shouldSync) return;
          _syncFromServer(match);
          if (newStatus == 'match_ended' && !_showMatchResult) {
            setState(() => _showMatchResult = true);
          }
        }
      } catch (_) {}
    });
  }

  int get _displaySetsCount =>
      (_serverMatch?['sets_count'] as int?) ?? widget.setsCount;
  int get _displayDiceCount =>
      (_serverMatch?['dice_count'] as int?) ?? widget.diceCount;
  int get _setsToWin => (_displaySetsCount ~/ 2) + 1;
  bool get _isCibleMode => widget.ruleType == 'cible';
  String get _myId {
    // Source unique : auth. Le cache est mis à jour dès que l'auth est prête
    // (voir build). Fallback 1er joueur UNIQUEMENT si aucun serveur/auth :
    // évite que 2 appareils se prennent pour le même joueur → tours figés.
    if (_resolvedMyId.isNotEmpty) return _resolvedMyId;
    try {
      final uid = ref.read(authProvider).user?.id.toString();
      if (uid != null && uid.isNotEmpty) {
        _resolvedMyId = uid;
        return uid;
      }
    } catch (_) {}
    // Si le serveur connaît déjà les joueurs, ne devine pas : utilise le
    // premier SEULEMENT en dernier recours (mode démo local).
    if (_serverMatch == null) {
      return widget.players.isNotEmpty
          ? widget.players.first['id'].toString()
          : 'me';
    }
    return _resolvedMyId.isNotEmpty ? _resolvedMyId : 'me';
  }

  /// Recharge l'état serveur via REST (fallback + réconciliation).
  Future<void> _refreshFromServer() async {
    if (!mounted) return;
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data = await repo.getMatchStateRest(widget.matchId);
      if (!mounted) return;
      if (data.containsKey('match_id')) {
        _syncFromServer(data);
      } else if (data['data'] is Map) {
        _syncFromServer(Map<String, dynamic>.from(data['data'] as Map));
      }
    } catch (_) {}
  }

  // === Revanche opt-out : synchronisation lobby ===

  /// Applique un payload revanche (lobby + match éventuel).
  void _syncRematchPayload(
    Map<String, dynamic> payload, {
    required String fallbackEvent,
  }) {
    final lobby = payload['lobby'];
    final match = payload['match'];
    if (match is Map) {
      _syncFromServer(
        Map<String, dynamic>.from(match),
        seq: payload['seq'] as int?,
      );
    }
    if (lobby is Map) {
      final lobbyMap = Map<String, dynamic>.from(lobby);
      setState(() {
        _rematchLobby = lobbyMap['status'] == 'none' ? null : lobbyMap;
        _confirmRematch = false;
      });
      if (fallbackEvent == 'propose' && mounted) {
        final proposer = lobbyMap['proposed_by']?.toString();
        if (proposer != null && proposer != _myId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_findPlayerName(proposer) ?? 'Un joueur'} propose une revanche !',
              ),
              backgroundColor: NeonColors.secondary,
            ),
          );
        }
      }
    } else if (mounted) {
      setState(() => _rematchLobby = null);
    }
  }

  /// Navigue vers le nouveau match si je fais partie des acceptants.
  void _openRematchIfAccepted(Map<String, dynamic> payload) {
    final lobby = payload['lobby'];
    final accepted = lobby is Map && lobby['accepted'] is List
        ? (lobby['accepted'] as List).map((e) => e.toString()).toSet()
        : <String>{};
    final newId = payload['new_match_id']?.toString();
    if (newId == null || newId.isEmpty) return;
    if (_rematchNavDone.contains(newId)) return;
    if (!accepted.contains(_myId)) {
      // Démarrée sans moi (refus/départ) : retour à l'état résultat.
      setState(() {
        _rematchLobby = null;
        _confirmRematch = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La revanche a démarré sans vous'),
            backgroundColor: NeonColors.textSecondary,
          ),
        );
      }
      return;
    }
    _rematchNavDone.add(newId);
    final match = payload['match'];
    if (match is Map) {
      _openRematchMatch(newId, Map<String, dynamic>.from(match));
    } else {
      _fetchAndOpenRematch(newId);
    }
  }

  /// Ouvre le nouveau match de revanche (remplace l'écran actuel).
  void _openRematchMatch(String newId, Map<String, dynamic> match) {
    if (!mounted) return;
    final players = (match['players'] as List? ?? [])
        .map(
          (p) => p is Map<String, dynamic>
              ? p
              : p is Map
                  ? Map<String, dynamic>.from(p)
                  : {'id': p.toString(), 'name': 'Joueur $p'},
        )
        .toList();
    final gameType = match['game_type']?.toString() ?? 'dice';
    context.go(
      '/games/$gameType/match/$newId',
      extra: {
        'rule_type': match['rule_type']?.toString() ?? widget.ruleType,
        'sets_count':
            (match['sets_count'] as num?)?.toInt() ?? widget.setsCount,
        'dice_count':
            (match['dice_count'] as num?)?.toInt() ?? widget.diceCount,
        'bet_amount': (match['bet_amount'] as num?)?.toInt() ?? 0,
        'players': players,
      },
    );
  }

  /// Secours polling : récupère le nouveau match puis navigue.
  Future<void> _fetchAndOpenRematch(String newId) async {
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data = await repo.getMatchStateRest(newId);
      if (!mounted) return;
      if (data.containsKey('match_id')) {
        _openRematchMatch(newId, data);
      } else if (data['data'] is Map) {
        _openRematchMatch(
            newId, Map<String, dynamic>.from(data['data'] as Map));
      }
    } catch (_) {}
  }

  // === Lancer synchronisé (tous les joueurs voient la même chose) ===
  // Protocole : `dice_rolling` (démarre l'anim partout) puis `dice_rolled`
  // (résultat final identique). Révélation après durée min commune pour que
  // l'animation soit visible même si le réseau est très rapide.

  /// Démarre l'animation de lancer pour [rollerId] sur TOUS les appareils.
  void _handleDiceRolling(String rollerId, {int? diceCount}) {
    if (!mounted) return;
    // Si un autre joueur avait un reveal en attente, le révéler d'abord
    // instantanément (ne jamais perdre un résultat lors de tours rapides).
    final pending = _pendingReveal;
    if (pending != null && pending['playerId']?.toString() != rollerId) {
      _flushPendingReveal();
    } else {
      _rollRevealTimer?.cancel();
      if (pending != null && pending['playerId']?.toString() == rollerId) {
        // Doublon (écho local + broadcast serveur) : on garde le final,
        // on relance juste l'anim.
      } else {
        _pendingReveal = null;
      }
    }
    _rollingPlayerId = rollerId;
    _rollAnimStartedAt = DateTime.now();
    if (!_isRolling && mounted) setState(() => _isRolling = true);
    _startRollFlicker(diceCount ?? _displayDiceCount);
  }

  /// Révèle immédiatement un final en attente (sans attendre le timer).
  /// Utilisé quand un nouveau lancer démarre ou que le joueur suivant joue
  /// pendant l'animation précédente : aucun résultat n'est perdu.
  void _flushPendingReveal() {
    _rollRevealTimer?.cancel();
    _revealPendingRoll();
  }

  /// Reçoit le résultat final : planifie la révélation synchronisée.
  void _handleDiceRolledEvent({
    required String playerId,
    required List<int> dice,
    required int sum,
    Map<String, dynamic>? match,
    int? seq,
  }) {
    if (!mounted || dice.isEmpty) return;
    if (match != null) _syncFromServer(match, seq: seq);
    // Si l'anim n'a pas démarré (event rolling perdu), la démarrer maintenant
    if (!_isRolling || _rollingPlayerId == null) {
      _rollingPlayerId = playerId;
      _rollAnimStartedAt = DateTime.now();
      if (!_isRolling) setState(() => _isRolling = true);
      _startRollFlicker(dice.length);
    }
    // Un final d'un AUTRE joueur encore en attente : le révéler d'abord
    // pour ne pas l'écraser (tours rapides consécutifs).
    final prev = _pendingReveal;
    if (prev != null && prev['playerId']?.toString() != playerId) {
      _flushPendingReveal();
      // _flush a coupé l'anim : relancer pour le nouveau final
      _rollingPlayerId = playerId;
      _rollAnimStartedAt = DateTime.now();
      if (mounted) setState(() => _isRolling = true);
      _startRollFlicker(dice.length);
    }
    _pendingReveal = {'playerId': playerId, 'dice': dice, 'sum': sum};
    final elapsed = _rollAnimStartedAt == null
        ? _minRollAnim
        : DateTime.now().difference(_rollAnimStartedAt!);
    final wait = elapsed >= _minRollAnim
        ? const Duration(milliseconds: 120)
        : _minRollAnim - elapsed;
    _rollRevealTimer?.cancel();
    _rollRevealTimer = Timer(wait, _revealPendingRoll);
  }

  /// Animation commune : dés qui fluctuent (même visuel partout).
  void _startRollFlicker(int diceCount) {
    _rollAnimTimer?.cancel();
    final random = Random();
    final count = diceCount.clamp(1, 6);
    _rollAnimTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || !_isRolling) {
        _rollAnimTimer?.cancel();
        return;
      }
      setState(() {
        _currentDice = List.generate(count, (_) => random.nextInt(6) + 1);
      });
    });
  }

  /// Révélation commune : tout le monde affiche le même final au même moment.
  void _revealPendingRoll() {
    if (!mounted) return;
    final pending = _pendingReveal;
    _pendingReveal = null;
    _rollAnimTimer?.cancel();
    _rollFallbackTimer?.cancel();
    if (pending == null) {
      if (_isRolling) setState(() => _isRolling = false);
      return;
    }
    final dice = List<int>.from(pending['dice'] as List);
    final sum = pending['sum'] as int;
    final pid = pending['playerId'].toString();
    final isMine = pid == _myId;
    setState(() {
      _currentDice = dice;
      _playerDice[pid] = dice;
      _playerSums[pid] = sum;
      _lastRollerId = pid;
      _lastRollSum = sum;
      _isRolling = false;
      _rollingPlayerId = null;
      // Ma demande est traitée : réactiver mon bouton (anti-double-tap levé).
      // On ne touche au flag que pour mon propre final : le reveal d'un autre
      // joueur ne doit pas réactiver un envoi que je n'ai pas fait.
      if (isMine) _isSendingRoll = false;
    });
  }

  // Source de vérité: serveur si disponible, sinon local
  List<Map<String, dynamic>> get _displayPlayers {
    final srvPlayers = _serverMatch?['players'] as List?;
    if (srvPlayers != null && srvPlayers.isNotEmpty) {
      return srvPlayers.map((p) {
        if (p is Map<String, dynamic>) return p;
        if (p is Map) return Map<String, dynamic>.from(p);
        if (p is String) return {'id': p, 'name': 'Joueur $p'};
        return {'id': p.toString(), 'name': 'Joueur'};
      }).toList();
    }
    return widget.players;
  }

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
    return _displayPlayers
        .where((p) => !elim.contains(p['id'].toString()))
        .toList();
  }

  List<String> get _turnOrder {
    final serverOrder = _serverSetState?['turn_order'] as List?;
    if (serverOrder != null && serverOrder.isNotEmpty) {
      return serverOrder.map((e) => e.toString()).toList();
    }
    final ids = _displayPlayers.map((p) => p['id'].toString()).toList();
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
    final p = _displayPlayers.firstWhere(
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
    // Résout l'identité dès que l'auth est prête (évite fallback 1er joueur).
    // Si l'auth arrive après le 1er build, on re-join le user channel.
    final authUid = ref.watch(authProvider).user?.id.toString();
    if (authUid != null && authUid.isNotEmpty && authUid != _resolvedMyId) {
      _resolvedMyId = authUid;
      try {
        ref.read(gameWebSocketServiceProvider).joinUserChannel(authUid);
      } catch (_) {}
      // Re-synchronise avec la bonne identité (tour "Moi" correct pour tous).
      Future.microtask(() {
        if (mounted) {
          setState(() {});
          _refreshFromServer();
        }
      });
    }
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
              'SET $_displaySet/$_displaySetsCount',
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
                    '$_displaySet/$_displaySetsCount',
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
    // Header SANS timer : le décompte vit uniquement dans la PlayerZone du
    // joueur actif (TurnTimer piloté par deadline serveur). Évite double
    // ticker + désynchro entre header et zones.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        border: Border(
          bottom: BorderSide(color: NeonColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          _headerChip(
            Icons.layers_outlined,
            'Sets $_displaySet/$_displaySetsCount • $_displayDiceCount dé${_displayDiceCount > 1 ? 's' : ''}',
          ),
          const SizedBox(width: 6),
          _headerChip(Icons.emoji_events_outlined, 'Premier à $_setsToWin'),
          const Spacer(),
          if (_isVotingPhase)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        _displayPlayers.where((p) => p['id'].toString() != _myId).toList();
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
        _displayPlayers.where((p) => p['id'].toString() != _myId).toList();
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
    // Tatami = dernier lancer (tous les joueurs voient la même chose).
    // Pendant l'animation : dés qui fluctuent + nom du lanceur.
    // Après reveal : dés finaux + somme du lanceur (pas du joueur courant).
    final rollingName = _rollingPlayerId != null
        ? (_rollingPlayerId == _myId
            ? 'Vous lancez…'
            : '${_findPlayerName(_rollingPlayerId) ?? 'Joueur'} lance…')
        : null;
    final lastName = _lastRollerId != null
        ? (_lastRollerId == _myId
            ? 'Votre lancer'
            : 'Lancer de ${_findPlayerName(_lastRollerId) ?? 'Joueur'}')
        : null;
    final showSum = !_isRolling &&
        !_isVotingPhase &&
        _lastRollSum != null &&
        _currentDice.isNotEmpty;
    final dice = _currentDice.isEmpty ? null : _currentDice;
    final displayDice =
        _isRolling ? List<int>.filled(_displayDiceCount, 3) : (dice ?? []);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge lanceur : visible par TOUS → synchro visuelle du tour de lancer
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isRolling && rollingName != null
              ? Container(
                  key: ValueKey('rolling_$_rollingPlayerId'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeonColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: NeonColors.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NeonColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rollingName,
                        style: const TextStyle(
                          color: NeonColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              : (!(_isRolling) && lastName != null
                  ? Container(
                      key: ValueKey('last_$_lastRollerId'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NeonColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NeonColors.border),
                      ),
                      child: Text(
                        lastName,
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_badge'))),
        ),
        DiceTatami(
          diceValues: displayDice,
          diceCount: _displayDiceCount,
          isRolling: _isRolling,
          lastSum: showSum ? _lastRollSum : null,
          targetLabel: _isCibleMode && _targetValue != null
              ? 'CIBLE $_targetValue'
              : null,
          maxWidth: 360,
        ),
      ],
    );
  }

  Widget _buildTurnHint() {
    // AnimatedSwitcher keyed par joueur courant : le changement de tour est
    // visible/instantané chez TOUS les joueurs (pas de texte figé).
    final turnKey = _isEliminatedMe
        ? 'elim'
        : (_isMyTurn ? 'me' : 'wait_$_currentPlayerId');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeInOut,
      child: KeyedSubtree(
        key: ValueKey(turnKey),
        child: _buildTurnHintContent(),
      ),
    );
  }

  Widget _buildTurnHintContent() {
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
    final raw = _displayPlayers.firstWhere(
      (p) => p['id'].toString() == playerId,
      orElse: () => {'id': playerId, 'name': 'Joueur'},
    );
    final name = raw['name']?.toString() ?? 'Joueur';
    final displayName = isMe ? 'Moi' : name;
    final pid = playerId;
    final isActive = pid == _currentPlayerId &&
        !_displayEliminated.contains(pid) &&
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
    final useServerTimer = _serverMatch != null;
    // Arrêt immédiat du timer du lanceur : dès _isRolling, showTimer passe à
    // faux → TurnTimer détruit sur TOUS les écrans. Après broadcast serveur,
    // le nouveau joueur actif reçoit showTimer vrai + nouvelle deadline.
    // Key incluant l'index de tour : garantit la reconstruction synchrone des
    // deux zones (ancien actif → idle, nouveau → actif) chez tous les joueurs.
    final showTimerForZone = isActive && !_isRolling;
    return PlayerZone(
      key: ValueKey(
          'pz_${pid}_${isActive ? 'active' : 'idle'}_${isEliminated ? 'out' : 'in'}_t${_displayTurnIndex}_s$_displaySet'),
      data: data,
      isMe: isMyZone,
      compact: !isMe,
      showTimer: showTimerForZone,
      turnSeconds: _turnSeconds,
      turnDeadline: useServerTimer ? _turnDeadline : null,
      turnRemaining: useServerTimer ? _turnRemaining : null,
      onTapDice:
          (isMyZone && isActive && !_isSendingRoll) ? () => _rollDice() : null,
      // Serveur = arbitre timeout : pas de forfait local quand match connu.
      // onTimeout uniquement en mode dégradé (jamais de serveur).
      onTimeout: (isActive && !useServerTimer) ? _handleTimeout : null,
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
              'sur $_displaySetsCount',
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
                children: _displayPlayers.map((p) {
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
              'Score: ${_displayPlayers.map((p) => '${p['id'].toString() == _myId ? 'Moi' : p['name']}: ${_displayWins[p['id'].toString()] ?? 0}').join('  •  ')}',
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

  // === Fin de partie : fenêtre de résultat sur l'interface ===

  /// Vainqueur du match (serveur en priorité, calcul local sinon).
  /// null = match nul (égalité au sommet).
  String? get _matchWinnerId {
    if (_serverMatch != null && (_serverMatch!.containsKey('winner_id'))) {
      return _serverMatch!['winner_id']?.toString();
    }
    final wins = _displayWins;
    if (wins.isEmpty) return null;
    final top = wins.values.reduce((a, b) => a > b ? a : b);
    final leaders = wins.entries.where((e) => e.value == top).toList();
    if (leaders.length != 1) return null;
    return leaders.first.key;
  }

  /// Manches du match (serveur en priorité, état local sinon).
  List<Map<String, dynamic>> get _matchSets {
    final srv = _serverMatch?['sets'];
    if (srv is List && srv.isNotEmpty) {
      return srv
          .map(
            (e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map),
          )
          .toList();
    }
    return _setResults
        .map(
          (r) => {
            'set_number': r['set_number'],
            'winner_id': r['winner_id']?.toString(),
            'result': r['result'],
            'sums': (r['sums'] is Map)
                ? (r['sums'] as Map).map(
                    (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                  )
                : <String, int>{},
          },
        )
        .toList();
  }

  /// Gains nets du vainqueur (serveur) — jamais de brut affiché.
  Map<String, dynamic>? get _matchPayout {
    final p = _serverMatch?['payout'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  int get _displayBet =>
      (_serverMatch?['bet_amount'] as num?)?.toInt() ?? widget.betAmount;

  /// Fenêtre de fin de partie affichée SUR le plateau (inerte derrière).
  /// Compacte et responsive : carte centrée (max 430px, max 88% hauteur).
  Widget _buildMatchResult() {
    final narrow = MediaQuery.of(context).size.width < 620;
    return Stack(
      children: [
        // Plateau final derrière (contraintes strictes pour les Expanded internes)
        Positioned.fill(
          child: IgnorePointer(
            child: narrow ? _buildCompactBoard() : _buildWideBoard(),
          ),
        ),
        _buildMatchResultOverlay(),
      ],
    );
  }

  Widget _buildMatchResultOverlay() {
    final winnerId = _matchWinnerId;
    final isMeWinner = winnerId == _myId;
    final isTie = winnerId == null;
    final winnerName = isTie
        ? 'Match nul'
        : (isMeWinner ? 'Moi' : _findPlayerName(winnerId) ?? 'Joueur');
    final outcomeColor = isMeWinner
        ? NeonColors.success
        : (isTie ? NeonColors.warning : NeonColors.error);
    final outcomeIcon = isMeWinner
        ? Icons.emoji_events_rounded
        : (isTie
            ? Icons.handshake_rounded
            : Icons.sentiment_dissatisfied_rounded);
    final forfeitDecided = _displayEliminated.isNotEmpty;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 430,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: outcomeColor.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: outcomeColor.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête compact : trophée + titre + sous-titre
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: outcomeColor.withValues(alpha: 0.14),
                            border: Border.all(color: outcomeColor, width: 1.5),
                          ),
                          child: Icon(
                            outcomeIcon,
                            size: 26,
                            color: outcomeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMeWinner
                                    ? 'VICTOIRE !'
                                    : (isTie ? 'MATCH NUL' : 'DÉFAITE'),
                                style: TextStyle(
                                  color: outcomeColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                forfeitDecided
                                    ? (isMeWinner
                                        ? 'Adversaire forfait — tu gagnes !'
                                        : (_isEliminatedMe
                                            ? 'Forfait — temps écoulé'
                                            : '$winnerName gagne par forfait'))
                                    : (isTie
                                        ? 'Égalité parfaite'
                                        : '$winnerName gagne !'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NeonColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _resultSectionLabel('Manches'),
                    const SizedBox(height: 6),
                    ..._matchSets.map(_buildSetRow),
                    const SizedBox(height: 10),
                    _resultSectionLabel('Score global'),
                    const SizedBox(height: 6),
                    _buildGlobalScoreRow(),
                    if (_displayBet > 0) ...[
                      const SizedBox(height: 10),
                      _resultSectionLabel('Gains'),
                      const SizedBox(height: 6),
                      _buildNetPayoutCard(
                        winnerId: winnerId,
                        isMeWinner: isMeWinner,
                        isTie: isTie,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildRematchZone(),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _rematchBusy ? null : _sendFriendRequest,
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text(
                        'Ajouter comme ami',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: NeonColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: NeonColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }

  /// Ligne manche compacte : `S1 · Moi 9 · 7 Bob · 🏆` (toujours visible).
  Widget _buildSetRow(Map<String, dynamic> set) {
    final num = set['set_number']?.toString() ?? '–';
    final winner = set['winner_id']?.toString();
    final sums = set['sums'] is Map
        ? Map<String, dynamic>.from(set['sums'] as Map)
        : <String, dynamic>{};
    final isTie = set['result']?.toString() == 'tie' || winner == null;
    final sumsText = _displayPlayers.map((p) {
      final pid = p['id'].toString();
      final label = pid == _myId ? 'Moi' : (p['name']?.toString() ?? 'J');
      final sum = sums[pid]?.toString() ?? '–';
      return '$label $sum';
    }).join('  ·  ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: NeonColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: NeonColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'S$num',
              style: const TextStyle(
                color: NeonColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sumsText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            isTie ? Icons.horizontal_rule_rounded : Icons.emoji_events_rounded,
            size: 14,
            color: isTie ? NeonColors.warning : NeonColors.success,
          ),
        ],
      ),
    );
  }

  /// Score global : `Moi 2 — 1 Bob · Premier à 2`.
  Widget _buildGlobalScoreRow() {
    final parts = _displayPlayers
        .map(
          (p) =>
              '${p['id'].toString() == _myId ? 'Moi' : p['name']}: ${_displayWins[p['id'].toString()] ?? 0}',
        )
        .join('  —  ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: NeonColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 14,
            color: NeonColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '1er à $_setsToWin',
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

  /// Carte gain NET du vainqueur (brut jamais affiché).
  Widget _buildNetPayoutCard({
    required String? winnerId,
    required bool isMeWinner,
    required bool isTie,
  }) {
    final payout = _matchPayout;
    final net = payout?['net'] as num?;
    final commission = payout?['commission'] as num?;
    final hasNet = !isTie && winnerId != null && net != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            (hasNet && isMeWinner ? NeonColors.success : NeonColors.background)
                .withValues(alpha: hasNet && isMeWinner ? 0.12 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (hasNet && isMeWinner ? NeonColors.success : NeonColors.border)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const TokenCoin(
            size: 22,
            metal: TokenMetal.gold,
            lod: TokenLod.bevel,
            showShadow: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNet
                      ? (isMeWinner
                          ? 'Votre gain net'
                          : 'Gain net du vainqueur')
                      : 'Aucun gain',
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasNet ? '+$net jetons' : '—',
                  style: TextStyle(
                    color: hasNet && isMeWinner
                        ? NeonColors.success
                        : NeonColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  ),
                ),
                if (hasNet && commission != null)
                  Text(
                    'Commission $commission déduite',
                    style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === Revanche opt-out : états + actions ===

  Set<String> _lobbyIds(String key) {
    final lobby = _rematchLobby;
    if (lobby == null || lobby[key] is! List) return <String>{};
    return (lobby[key] as List).map((e) => e.toString()).toSet();
  }

  bool get _isRematchProposer =>
      _rematchLobby?['proposed_by']?.toString() == _myId;

  /// Mon vote : accepted | declined | pending | null (pas de lobby)
  String? get _myRematchVote {
    if (_rematchLobby == null) return null;
    if (_lobbyIds('accepted').contains(_myId)) return 'accepted';
    if (_lobbyIds('declined').contains(_myId)) return 'declined';
    return 'pending';
  }

  int get _rematchAcceptedCount {
    final lobby = _rematchLobby;
    if (lobby == null) return 0;
    final raw = lobby['accepted_count'];
    if (raw is num) return raw.toInt();
    return _lobbyIds('accepted').length;
  }

  /// Zone revanche : confirmation → lobby (invitation / attente / démarrage).
  Widget _buildRematchZone() {
    final lobby = _rematchLobby;
    // Proposition démarrée : navigation imminente
    if (lobby != null && lobby['status']?.toString() == 'started') {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'La revanche commence…',
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    // Lobby actif : invitation ou suivi
    if (lobby != null && lobby['status']?.toString() == 'proposed') {
      return _buildRematchLobby(lobby);
    }
    // Confirmation avant proposition (explicite, évite les taps accidentels)
    if (_confirmRematch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: NeonColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: NeonColors.secondary.withValues(alpha: 0.35),
              ),
            ),
            child: const Text(
              'Proposer une revanche aux mêmes joueurs, mêmes mises ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeonColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'Annuler',
                  onPressed: _rematchBusy
                      ? null
                      : () => setState(() => _confirmRematch = false),
                  variant: NeonButtonVariant.outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'Confirmer',
                  onPressed: _rematchBusy ? null : _proposeRematch,
                  variant: NeonButtonVariant.primary,
                  icon: Icons.check_rounded,
                  isLoading: _rematchBusy,
                ),
              ),
            ],
          ),
        ],
      );
    }
    // État initial : une action primaire + sortie explicite
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeonButton(
          text: 'Revanche',
          onPressed: _rematchBusy
              ? null
              : () => setState(() => _confirmRematch = true),
          variant: NeonButtonVariant.primary,
          icon: Icons.replay_rounded,
          width: double.infinity,
        ),
        const SizedBox(height: 8),
        NeonButton(
          text: 'Quitter',
          onPressed: _rematchBusy ? null : _quitMatch,
          variant: NeonButtonVariant.outline,
          icon: Icons.home_rounded,
          width: double.infinity,
        ),
      ],
    );
  }

  /// Suivi de proposition : acceptations en temps réel + démarrage.
  Widget _buildRematchLobby(Map<String, dynamic> lobby) {
    final invited = lobby['invited'] is List
        ? (lobby['invited'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final accepted = _lobbyIds('accepted');
    final declined = _lobbyIds('declined');
    final left = _lobbyIds('left');
    final proposer = lobby['proposed_by']?.toString();
    final vote = _myRematchVote;
    final isProposer = _isRematchProposer;
    final count = _rematchAcceptedCount;
    final canStart = isProposer && count >= 2 && !_rematchBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.replay_rounded,
              size: 14,
              color: NeonColors.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isProposer
                    ? 'Votre proposition — $count/${invited.length} acceptés'
                    : '${_findPlayerName(proposer) ?? 'Un joueur'} propose — $count/${invited.length}',
                style: const TextStyle(
                  color: NeonColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_rematchBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...invited.map((pid) {
          final name = pid == _myId ? 'Moi' : _findPlayerName(pid) ?? 'Joueur';
          final isProposerRow = pid == proposer;
          final stateIcon = accepted.contains(pid)
              ? const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: NeonColors.success,
                )
              : (declined.contains(pid)
                  ? const Icon(
                      Icons.cancel_rounded,
                      size: 16,
                      color: NeonColors.error,
                    )
                  : const Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 16,
                      color: NeonColors.textSecondary,
                    ));
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                stateIcon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name + (isProposerRow ? ' (proposant)' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (left.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${left.length} joueur${left.length > 1 ? 's' : ''} parti${left.length > 1 ? 's' : ''} — effectif ajusté',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (!isProposer && vote == 'pending') ...[
          // Invitation : deux grandes cibles (anti-misclick, c.f. Lichess)
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'Refuser',
                  onPressed: _rematchBusy ? null : () => _respondRematch(false),
                  variant: NeonButtonVariant.outline,
                  isLoading: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'Accepter',
                  onPressed: _rematchBusy ? null : () => _respondRematch(true),
                  variant: NeonButtonVariant.primary,
                  icon: Icons.check_rounded,
                  isLoading: _rematchBusy,
                ),
              ),
            ],
          ),
        ] else if (isProposer) ...[
          NeonButton(
            text: canStart
                ? 'Démarrer ($count joueurs)'
                : 'En attente (min. 2 joueurs)',
            onPressed: canStart ? _startRematch : null,
            variant: NeonButtonVariant.primary,
            icon: Icons.play_arrow_rounded,
            isLoading: _rematchBusy,
            width: double.infinity,
          ),
          const SizedBox(height: 8),
          NeonButton(
            text: 'Annuler',
            onPressed: _rematchBusy ? null : _cancelRematch,
            variant: NeonButtonVariant.outline,
            width: double.infinity,
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vote == 'accepted'
                    ? 'Acceptée — en attente des autres…'
                    : 'Vous avez décliné',
                style: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          if (vote == 'accepted') ...[
            const SizedBox(height: 8),
            NeonButton(
              text: 'Se retirer',
              onPressed: _rematchBusy ? null : () => _respondRematch(false),
              variant: NeonButtonVariant.outline,
              width: double.infinity,
            ),
          ] else ...[
            const SizedBox(height: 8),
            NeonButton(
              text: 'Quitter',
              onPressed: _rematchBusy ? null : _quitMatch,
              variant: NeonButtonVariant.outline,
              icon: Icons.home_rounded,
              width: double.infinity,
            ),
          ],
        ],
      ],
    );
  }

  void _snackRematchError(Object e) {
    final msg = e is ApiException
        ? e.userMessage
        : 'Action impossible — vérifiez votre connexion';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: NeonColors.error),
    );
  }

  /// Propose une revanche (REST : réponse autoritaire + broadcast serveur).
  Future<void> _proposeRematch() async {
    if (_rematchBusy) return;
    setState(() => _rematchBusy = true);
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data = await repo.proposeRematch(matchId: widget.matchId);
      if (!mounted) return;
      final lobby = data['lobby'];
      if (lobby is Map) {
        setState(() {
          _rematchLobby = Map<String, dynamic>.from(lobby);
          _confirmRematch = false;
        });
      }
      final match = data['match'];
      if (match is Map) {
        _syncFromServer(Map<String, dynamic>.from(match));
      }
    } catch (e) {
      if (mounted) _snackRematchError(e);
    } finally {
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  /// Répond à la proposition (accepter / refuser).
  Future<void> _respondRematch(bool accept) async {
    if (_rematchBusy) return;
    setState(() => _rematchBusy = true);
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data =
          await repo.respondRematch(matchId: widget.matchId, accept: accept);
      if (!mounted) return;
      final lobby = data['lobby'];
      if (lobby is Map) {
        setState(() {
          final map = Map<String, dynamic>.from(lobby);
          _rematchLobby = map['status'] == 'none' ? null : map;
        });
      }
      final match = data['match'];
      if (match is Map) {
        _syncFromServer(Map<String, dynamic>.from(match));
      }
    } catch (e) {
      if (mounted) _snackRematchError(e);
    } finally {
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  /// Démarre la revanche (proposant) puis ouvre le nouveau match.
  Future<void> _startRematch() async {
    if (_rematchBusy) return;
    setState(() => _rematchBusy = true);
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data = await repo.startRematch(matchId: widget.matchId);
      if (!mounted) return;
      final newId = data['new_match_id']?.toString();
      final excluded = data['excluded'] is List
          ? (data['excluded'] as List).map((e) => e.toString()).toList()
          : <String>[];
      if (excluded.isNotEmpty) {
        final names = excluded
            .map((id) => id == _myId ? 'Moi' : _findPlayerName(id) ?? id)
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sans fonds suffisants : $names'),
            backgroundColor: NeonColors.warning,
          ),
        );
      }
      if (newId != null && newId.isNotEmpty) {
        _rematchNavDone.add(newId);
        final match = data['match'];
        if (match is Map) {
          _openRematchMatch(newId, Map<String, dynamic>.from(match));
        } else {
          await _fetchAndOpenRematch(newId);
        }
      }
    } catch (e) {
      if (mounted) _snackRematchError(e);
    } finally {
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  /// Annule la proposition (proposant).
  Future<void> _cancelRematch() async {
    if (_rematchBusy) return;
    setState(() => _rematchBusy = true);
    try {
      final repo = ref.read(gameRepositoryProvider);
      await repo.cancelRematch(matchId: widget.matchId);
      if (!mounted) return;
      setState(() => _rematchLobby = null);
      await _refreshFromServer();
    } catch (e) {
      if (mounted) _snackRematchError(e);
    } finally {
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  /// Quitter : signale la sortie (exclu des revanches) puis retour au jeu.
  void _quitMatch() {
    _leaveFinishedMatch();
    if (mounted) context.go('/games/dice');
  }

  /// Sortie d'interface de fin de partie (best effort, idempotent).
  void _leaveFinishedMatch() {
    try {
      ref.read(gameWebSocketServiceProvider).leaveMatch(widget.matchId);
    } catch (_) {}
    try {
      ref.read(gameRepositoryProvider).leaveMatch(matchId: widget.matchId);
    } catch (_) {}
  }

  /// Demande d'ami vers le premier adversaire (conservée, version sobre).
  Future<void> _sendFriendRequest() async {
    if (_rematchBusy) return;
    final currentUserId = ref.read(authProvider).user?.id.toString() ?? '';
    final opponent = _displayPlayers.firstWhere(
      (p) => p['id'].toString() != currentUserId && p['id'].toString() != _myId,
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi'),
            backgroundColor: NeonColors.error,
          ),
        );
      }
    }
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
              'Cible entre $_displayDiceCount et ${_displayDiceCount * 6}',
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
                              _displayDiceCount.toDouble(),
                              (_displayDiceCount * 6).toDouble(),
                            ),
                        min: _displayDiceCount.toDouble(),
                        max: (_displayDiceCount * 6).toDouble(),
                        divisions: (_displayDiceCount * 6) - _displayDiceCount,
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
                      '${_targetVotes.length}/${_displayPlayers.length} votes',
                      style: const TextStyle(
                        color: NeonColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_displayEliminated.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Éliminés: ${_displayEliminated.join(', ')}',
                  style: const TextStyle(color: NeonColors.error, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // === Actions ===

  Future<void> _rollDice() async {
    // Garde anti-double-tap : ma demande en vol, pas l'animation globale.
    // L'animation d'un AUTRE joueur ne verrouille plus mon bouton : un tap
    // pendant son reveal révèle son final instantanément puis lance mon tour.
    if (_isSendingRoll || _isEliminatedMe || !_isMyTurn) return;
    // Si le final précédent n'est pas encore révélé, le révéler d'abord
    // pour libérer le tatami (aucun résultat perdu).
    if (_pendingReveal != null) _flushPendingReveal();
    _isSendingRoll = true;
    final rollerId = _myId;
    _handleDiceRolling(rollerId, diceCount: _displayDiceCount);
    _rollFallbackTimer?.cancel();

    final ws = ref.read(gameWebSocketServiceProvider);
    final isWsLive = ws.isConnected;
    if (isWsLive) {
      try {
        ws.rollDice(widget.matchId);
        _rollFallbackTimer =
            Timer(const Duration(milliseconds: 3000), () async {
          if (mounted && _isSendingRoll && _pendingReveal == null) {
            await _rollDiceRestFallback();
          }
        });
        return;
      } catch (_) {
        if (mounted) setState(() => _isSendingRoll = false);
      }
    }

    await _rollDiceRestFallback();
  }

  Future<void> _rollDiceRestFallback() async {
    _rollFallbackTimer?.cancel();
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data = await repo.rollDice(matchId: widget.matchId);
      if (!mounted) return;
      final roll = data['roll'] as Map<String, dynamic>?;
      final match = data['match'] as Map<String, dynamic>?;
      if (roll != null) {
        final dice = List<int>.from(roll['dice'] as List? ?? []);
        final sum = roll['sum'] as int? ?? dice.fold<int>(0, (a, b) => a + b);
        final pid = roll['player_id']?.toString() ?? _myId;
        if (dice.isNotEmpty) {
          // Même chemin synchronisé que le WS (reveal après anim min)
          _handleDiceRolledEvent(
            playerId: pid,
            dice: dice,
            sum: sum,
            match: match,
          );
        } else {
          if (match != null) _syncFromServer(match);
          _rollRevealTimer?.cancel();
          _pendingReveal = null;
          _isSendingRoll = false;
          setState(() => _isRolling = false);
        }
      } else {
        if (match != null) _syncFromServer(match);
        _isSendingRoll = false;
        setState(() => _isRolling = false);
      }
      if (match != null &&
          (match['status'] == 'set_ended' ||
              match['status'] == 'match_ended')) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_showSetResult && !_showMatchResult) {
            _syncFromServer(match);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      _rollAnimTimer?.cancel();
      _rollRevealTimer?.cancel();
      _pendingReveal = null;
      // N'interrompre l'animation que si c'était la mienne : une erreur sur
      // mon tap ne doit pas couper l'anim du joueur en cours chez les autres.
      final rollingMine = _rollingPlayerId == null || _rollingPlayerId == _myId;
      _isSendingRoll = false;
      if (rollingMine) {
        _rollingPlayerId = null;
        setState(() => _isRolling = false);
      }
      final msg = e.toString().toLowerCase();
      String userMsg;
      if (e is ApiException) {
        userMsg = e.userMessage;
      } else if (msg.contains('not_your_turn') ||
          msg.contains('pas votre tour')) {
        userMsg = "Ce n'est pas votre tour";
      } else if (msg.contains('already_rolled') || msg.contains('déjà lancé')) {
        userMsg = 'Vous avez déjà lancé ce tour';
      } else if (msg.contains('voting_phase')) {
        userMsg = 'Phase de vote en cours';
      } else if (msg.contains('player_eliminated') || msg.contains('éliminé')) {
        userMsg = 'Vous êtes éliminé';
      } else {
        userMsg = 'Erreur réseau — vérifiez votre connexion';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMsg),
          backgroundColor: userMsg.contains('tour') || userMsg.contains('déjà')
              ? NeonColors.warning
              : NeonColors.error,
        ),
      );
      if (userMsg.contains('réseau')) {
        try {
          final repo = ref.read(gameRepositoryProvider);
          final state = await repo.getMatchStateRest(widget.matchId);
          if (state.isNotEmpty && mounted) _syncFromServer(state);
        } catch (_) {}
      }
    }
  }

  // NOTE : plus aucune simulation locale (lancers/évaluations/avance tour).
  // Le serveur est l'unique arbitre : dés via :crypto, évaluation, timeouts
  // et broadcasts PubSub. Le client ne fait que transporter (WS/REST) et
  // afficher.

  void _nextSet() {
    // Serveur = source unique : start_set via WS ou REST, puis broadcast
    // set_started pour TOUS. Pas d'incrément local (évite désynchro).
    if (_useWebSocket) {
      try {
        ref.read(gameWebSocketServiceProvider).startSet(widget.matchId);
      } catch (_) {}
      setState(() {
        _showSetResult = false;
        _showSetIntro = true;
        _currentDice = [];
        _lastRollerId = null;
        _lastRollSum = null;
        _rollingPlayerId = null;
        _pendingReveal = null;
        _playerDice.clear();
        _playerSums.clear();
      });
      _introCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _showSetIntro) {
          setState(() => _showSetIntro = false);
          // Deadline serveur via broadcast set_started (pas de timer local).
        }
      });
      // Réconciliation : si le broadcast tarde (>2s), forcer un refresh REST.
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted &&
            _showSetIntro &&
            _serverMatch?['status'] == 'set_ended') {
          _refreshFromServer();
        }
      });
      return;
    }
    // Fallback REST : demande serveur, pas d'état local deviné.
    () async {
      setState(() {
        _showSetResult = false;
        _showSetIntro = true;
      });
      _introCtrl.forward(from: 0);
      try {
        final repo = ref.read(gameRepositoryProvider);
        final data = await repo.startSet(matchId: widget.matchId);
        if (!mounted) return;
        final match = data['match'] as Map<String, dynamic>? ?? data;
        if (match.containsKey('match_id')) {
          _syncFromServer(match);
          setState(() {
            _currentDice = [];
            _lastRollerId = null;
            _lastRollSum = null;
            _rollingPlayerId = null;
            _pendingReveal = null;
            _playerDice.clear();
            _playerSums.clear();
          });
        }
      } catch (_) {
        await _refreshFromServer();
      }
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showSetIntro = false);
        // Deadline serveur via _syncFromServer (pas de timer local).
      });
    }();
  }

  Future<void> _submitVote() async {
    final myVote = _targetVotes[_myId] ?? 7;
    setState(() => _targetVotes[_myId] = myVote);
    // Transport WS si live, TOUJOURS complété par REST pour garantie serveur.
    // Pas de calcul local ni de votes adverses simulés : le serveur calcule
    // la cible et diffuse target_calculated à tous (synchrone).
    if (_useWebSocket) {
      try {
        ref
            .read(gameWebSocketServiceProvider)
            .voteTarget(widget.matchId, myVote);
      } catch (_) {}
    }
    try {
      final repo = ref.read(gameRepositoryProvider);
      final data =
          await repo.voteTarget(matchId: widget.matchId, targetValue: myVote);
      if (!mounted) return;
      if (data.containsKey('match_id')) {
        _syncFromServer(data);
      } else if (data['match'] is Map) {
        _syncFromServer(Map<String, dynamic>.from(data['match'] as Map));
      } else {
        await _refreshFromServer();
      }
    } catch (_) {
      // Erreur (déjà voté, etc.) : réconciliation silencieuse
      await _refreshFromServer();
    }
  }

  String? _findPlayerName(String? playerId) {
    if (playerId == null) return null;
    if (playerId == _myId) return 'Moi';
    // Source serveur d'abord (synchrone pour tous), fallback widget.
    final p = _displayPlayers.firstWhere((e) => e['id'].toString() == playerId,
        orElse: () => {});
    return p.isNotEmpty ? p['name']?.toString() : 'Joueur';
  }

  bool _checkMatchOver() {
    return _displayWins.values.any((v) => v >= _setsToWin) ||
        _displayEliminated.length >= _displayPlayers.length - 1;
  }
}

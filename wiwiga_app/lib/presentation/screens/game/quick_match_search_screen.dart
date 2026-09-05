// ============================================================
// Fichier: quick_match_search_screen.dart
// Description: Page bloquante Partie Rapide — V3.1 lobby synchronisé
//              Sobre, fluide, responsive, sans redondance
// Auteur: Franck Arlos CHENDJOU — Refactor 2026-09-01
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../widgets/neon/neon_widgets.dart';

class QuickMatchSearchScreen extends ConsumerStatefulWidget {
  final String gameType;
  final int betAmount;
  final String ruleType;

  const QuickMatchSearchScreen({
    super.key,
    required this.gameType,
    required this.betAmount,
    required this.ruleType,
  });

  @override
  ConsumerState<QuickMatchSearchScreen> createState() =>
      _QuickMatchSearchScreenState();
}

class _QuickMatchSearchScreenState extends ConsumerState<QuickMatchSearchScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _searchController;

  Timer? _elapsedTimer;
  Timer? _lobbyTimer;
  int _elapsedSeconds = 0;
  bool _isCancelling = false;
  bool _isToggling = false;
  bool _hasMatched = false;
  String? _error;
  Object? _errorObj;

  // Lobby synchronisé depuis serveur
  Map<String, dynamic>? _lobby;
  // Pour header nom du jeu
  String? _cachedGameName;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat(reverse: true);
    _searchController =
        AnimationController(duration: const Duration(seconds: 3), vsync: this)
          ..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    try {
      final ws = ref.read(gameWebSocketServiceProvider);
      ws.leaveQuickLobby(
        gameType: widget.gameType,
        ruleType: widget.ruleType,
        betAmount: widget.betAmount,
      );
    } catch (_) {}
    _pulseController.dispose();
    _searchController.dispose();
    _elapsedTimer?.cancel();
    _lobbyTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSearch() async {
    final ws = ref.read(gameWebSocketServiceProvider);
    if (!ws.isConnected && !ws.isFallbackMode) {
      try {
        await ws.connect();
      } catch (_) {}
    }
    // Rejoindre le lobby rapide en temps réel (qm:lobby + matchmaking) pour synchro instantanée chez tous
    try {
      ws.joinQuickLobby(
        gameType: widget.gameType,
        ruleType: widget.ruleType,
        betAmount: widget.betAmount,
      );
      ws.joinMatchmakingChannel(widget.gameType);
    } catch (_) {}

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });

    // Poll lobby toutes les 1.2s (synchro chez tous les joueurs) + fallback activeGame
    _lobbyTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _fetchLobby(),
    );

    ws.onGameMatched = (payload) {
      if (!mounted || _hasMatched) return;
      _onMatched(payload);
    };
    ws.onLobbyUpdate = (payload) {
      if (!mounted) return;
      // Gère à la fois {lobby: {...}} et lobby direct
      final lobby = (payload['lobby'] as Map<String, dynamic>?) ?? payload;
      if (lobby.isNotEmpty && lobby.containsKey('status')) {
        setState(() => _lobby = Map<String, dynamic>.from(lobby));
        if (lobby['status'] == 'matched' && lobby['game_id'] != null) {
          _onMatched(
            {'game_id': lobby['game_id'], 'players': lobby['players']},
          );
        } else if (lobby['status'] == 'matched' && payload['game_id'] != null) {
          _onMatched(
            {'game_id': payload['game_id'], 'players': lobby['players']},
          );
        }
      } else if (payload['game_id'] != null) {
        _onMatched(payload);
      }
    };

    try {
      final repo = ref.read(gameRepositoryProvider);
      final result = await repo.joinGame(
        gameId: widget.gameType,
        betAmount: widget.betAmount,
        ruleType: widget.ruleType,
      );
      if (!mounted || _hasMatched) return;
      if (result['status'] == 'matched') {
        _onMatched(result);
      } else {
        // waiting -> lobby va se remplir via poll
        if (result['lobby'] != null) {
          setState(
            () => _lobby = Map<String, dynamic>.from(result['lobby'] as Map),
          );
        }
        await _fetchLobby();
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'QuickMatchSearch._startSearch');
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.userMessage(e);
        _errorObj = e;
      });
    }
  }

  Future<void> _fetchLobby() async {
    if (_hasMatched || _isCancelling || !mounted) return;
    try {
      final repo = ref.read(gameRepositoryProvider);
      final lobby = await repo.getQuickLobby(
        gameId: widget.gameType,
        ruleType: widget.ruleType,
        betAmount: widget.betAmount,
      );
      if (!mounted) return;
      if (lobby['status'] == 'matched' && lobby['game_id'] != null) {
        _onMatched({'game_id': lobby['game_id'], 'players': lobby['players']});
        return;
      }
      // Fallback actif: si lobby vide mais partie déjà créée (ex: après cleanup), vérifier via /me/active
      if ((lobby.isEmpty || lobby['players_count'] == 0) &&
          _elapsedSeconds > 2) {
        try {
          final active = await repo.getActiveGame();
          if (active['has_active'] == true &&
              active['type'] == 'match' &&
              active['match_id'] != null) {
            _onMatched({'game_id': active['match_id'], 'players': []});
            return;
          }
          if (active['has_active'] == true &&
              active['type'] == 'quick_lobby' &&
              active['lobby']?['status'] == 'matched') {
            final alobby = active['lobby'] as Map<String, dynamic>;
            if (alobby['game_id'] != null) {
              _onMatched(
                {'game_id': alobby['game_id'], 'players': alobby['players']},
              );
              return;
            }
          }
        } catch (_) {}
      }
      if (lobby.isNotEmpty) {
        setState(() => _lobby = lobby);
        if (lobby['elapsed_seconds'] is int) {
          final srvElapsed = lobby['elapsed_seconds'] as int;
          if ((srvElapsed - _elapsedSeconds).abs() > 3) {
            setState(() => _elapsedSeconds = srvElapsed);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleReady() async {
    if (_isToggling || _hasMatched) return;
    setState(() => _isToggling = true);
    try {
      final repo = ref.read(gameRepositoryProvider);
      final result = await repo.toggleQuickReady(
        gameId: widget.gameType,
        ruleType: widget.ruleType,
        betAmount: widget.betAmount,
      );
      if (!mounted) return;
      if (result['status'] == 'matched' && result['game_id'] != null) {
        _onMatched(result);
      } else if (result['players'] != null) {
        setState(() => _lobby = result);
      } else if (result['lobby'] != null) {
        setState(
          () => _lobby = Map<String, dynamic>.from(result['lobby'] as Map),
        );
      }
      // Sinon refetch
      await _fetchLobby();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.userMessage(e)),
            backgroundColor: NeonColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  /// Libellé sets depuis l'aperçu serveur du lobby (jamais deviné) :
  /// "BO3" en mode fixe, "Aléatoire (1–5)" en mode aléatoire.
  String _setsLabel() {
    final sets = _lobby?['sets'];
    if (sets is Map) {
      final mode = sets['mode']?.toString() ?? 'fixed';
      if (mode == 'random') {
        final min = (sets['random_min'] as num?)?.toInt() ?? 1;
        final max = (sets['random_max'] as num?)?.toInt() ?? 5;
        if (min == max) return 'BO$min';
        return 'Aléatoire ($min–$max)';
      }
      final fixed = (sets['fixed'] as num?)?.toInt() ??
          (sets['default_sets'] as num?)?.toInt() ??
          3;
      return 'BO$fixed';
    }
    return 'BO3';
  }

  void _onMatched(Map<String, dynamic> payload) {
    if (_hasMatched) return;
    _hasMatched = true;
    _elapsedTimer?.cancel();
    _lobbyTimer?.cancel();
    final gameId = payload['game_id'] as String? ??
        payload['room_id'] as String? ??
        payload['match_id'] as String? ??
        '';
    final roomId = payload['room_id'] as String?;
    final matchId = payload['match_id'] as String? ??
        (gameId.contains('_match_') ? gameId : null);
    if (!mounted) return;
    if (roomId != null && roomId.isNotEmpty) {
      context.go('/games/${widget.gameType}/room/$roomId');
    } else if (matchId != null && matchId.isNotEmpty) {
      // Partie rapide multi-joueurs -> DiceMatch (multi-sets) — démarrage direct, pas d'autre attente
      final lobbyPlayers =
          _lobby?['players'] as List? ?? payload['players'] as List? ?? [];
      // Récupérer sets/dice depuis rules si possible via lobby, sinon défauts
      final isMatchId =
          gameId.contains('_match_') || matchId.contains('_match_');
      final targetId = isMatchId ? gameId : matchId;
      context.go(
        '/games/${widget.gameType}/match/$targetId',
        extra: {
          'rule_type': widget.ruleType,
          'bet_amount': widget.betAmount,
          'players': lobbyPlayers,
          // sets/dice : source serveur (match state via WS/REST).
          // Les défauts router ne sont qu'un repli avant la synchro.
        },
      );
    } else if (gameId.isNotEmpty) {
      // Fallback simple Redis -> session (2 joueurs legacy)
      context.go(
        '/games/${widget.gameType}/session/$gameId',
        extra: {
          'bet_amount': widget.betAmount,
          'rule_type': widget.ruleType,
        },
      );
    } else {
      context.go('/games/${widget.gameType}/lobby');
    }
  }

  Future<void> _cancelSearch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Annuler ?',
          style: TextStyle(
            color: NeonColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Mise ${_formatTokens(widget.betAmount)} wiga remboursée.',
          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Continuer',
              style: TextStyle(color: NeonColors.primary),
            ),
          ),
          NeonButton(
            text: 'Annuler',
            variant: NeonButtonVariant.danger,
            height: 36,
            fontSize: 12,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isCancelling = true);
    _elapsedTimer?.cancel();
    _lobbyTimer?.cancel();
    try {
      final ws = ref.read(gameWebSocketServiceProvider);
      ws.leaveQuickLobby(
        gameType: widget.gameType,
        ruleType: widget.ruleType,
        betAmount: widget.betAmount,
      );
      await ws.leaveMatchmaking(
        gameType: widget.gameType,
        ruleType: widget.ruleType,
        betAmount: widget.betAmount,
      );
    } catch (_) {}
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games/${widget.gameType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _cancelSearch();
      },
      child: Scaffold(
        backgroundColor: NeonColors.background,
        body: SafeArea(child: _error != null ? _buildError() : _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    final gameName = ref.watch(gameDetailProvider(widget.gameType)).maybeWhen(
          data: (g) => g.name,
          orElse: () => _cachedGameName ?? _fallbackName(widget.gameType),
        );
    // Cache pour éviter scintillement
    if (gameName != _cachedGameName && gameName != widget.gameType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _cachedGameName = gameName);
      });
    }
    final displayName = _cachedGameName ?? gameName;

    return Column(
      children: [
        _buildHeader(displayName),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 20),
                  child: Column(
                    children: [
                      // Animation compacte
                      _buildCompactAnimation(),
                      const SizedBox(height: 14),
                      _buildStatusLine(),
                      const SizedBox(height: 16),
                      _buildLobbyCard(),
                      const SizedBox(height: 12),
                      if (_shouldShowFallback()) _buildFallbackHint(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader(String gameName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(bottom: BorderSide(color: NeonColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: NeonGradients.cta,
              boxShadow: [
                BoxShadow(
                  color: NeonColors.primary.withValues(alpha: 0.24),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.casino_outlined,
              size: 18,
              color: NeonColors.background,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    color: NeonColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.betAmount} wiga • ${widget.ruleType == 'cible' ? 'Cible' : 'Normal'} • ${_setsLabel()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Seul endroit où le temps est affiché (pas de redondance corps)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: NeonColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: NeonColors.primary.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: NeonColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatElapsed(_elapsedSeconds),
                  style: const TextStyle(
                    color: NeonColors.primary,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAnimation() {
    return AnimatedBuilder(
      animation: _searchController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: NeonColors.primary.withValues(
                    alpha: 0.16 + _searchController.value * 0.24,
                  ),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NeonColors.primary.withValues(alpha: 0.10),
                    blurRadius: 14 + _searchController.value * 6,
                  ),
                ],
              ),
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: NeonColors.secondary.withValues(
                    alpha: 0.18 + (1 - _searchController.value) * 0.22,
                  ),
                  width: 1.5,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: NeonColors.primary
                          .withValues(alpha: _pulseController.value * 0.28),
                      blurRadius: 16 + _pulseController.value * 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: NeonColors.primary
                      .withValues(alpha: 0.09 + _pulseController.value * 0.07),
                  child: Icon(
                    Icons.search,
                    size: 24,
                    color: NeonColors.primary.withValues(alpha: 0.90),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusLine() {
    final lobby = _lobby;
    final count = lobby?['players_count'] as int? ?? 0;
    final max = lobby?['max_players'] as int? ?? 5;
    final ready = lobby?['ready_count'] as int? ?? 0;
    String text;
    Color color;
    if (count == 0) {
      text = 'Recherche d\'adversaires…';
      color = NeonColors.textSecondary;
    } else if (count < max) {
      text = '$count/$max joueurs • $ready prêt${ready > 1 ? 's' : ''}';
      color = NeonColors.textPrimary;
    } else {
      text = 'Partie complète';
      color = NeonColors.success;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        if (count == 0) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            height: 6,
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Opacity(
                        opacity: 0.3 +
                            (_pulseController.value * 0.7 * ((i + 1) / 3)),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: NeonColors.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLobbyCard() {
    final lobby = _lobby;
    final rawPlayers = lobby?['players'] as List? ?? [];
    final players = rawPlayers.map((e) {
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return Map<String, dynamic>.from(e);
      if (e is String) return {'id': e, 'name': 'Joueur $e', 'ready': false, 'is_self': false};
      return {'id': e.toString(), 'name': 'Joueur', 'ready': false, 'is_self': false};
    }).toList();
    final max = lobby?['max_players'] as int? ?? 5;
    final readyCount = lobby?['ready_count'] as int? ?? 0;
    final canStart = lobby?['can_start'] as bool? ?? false;

    // Déterminer mon état prêt
    Map<String, dynamic>? me;
    for (final p in players) {
      if (p['is_self'] == true) me = p;
    }
    final amReady = me?['ready'] == true;
    final allReady = players.isNotEmpty &&
        readyCount == players.length &&
        players.length >= 2;

    return NeonCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 16,
                color: NeonColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Joueurs',
                style: TextStyle(
                  color: NeonColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NeonColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: NeonColors.border),
                ),
                child: Text(
                  '${players.length}/$max',
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (players.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: allReady
                        ? NeonColors.success.withValues(alpha: 0.14)
                        : NeonColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$readyCount prêt${readyCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: allReady ? NeonColors.success : NeonColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, cons) {
              final w = cons.maxWidth;
              int cols;
              if (w < 340) {
                cols = 2;
              } else if (w < 520)
                cols = 3;
              else
                cols = 4;
              const spacing = 8.0;
              final tileW = (w - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(max, (i) {
                  if (i < players.length) {
                    final p = players[i];
                    final isSelf = p['is_self'] == true;
                    final ready = p['ready'] == true;
                    final name = (p['name'] as String?) ?? 'Joueur';
                    return SizedBox(
                      width: tileW,
                      child: _playerTile(
                        name: name,
                        isSelf: isSelf,
                        ready: ready,
                      ),
                    );
                  } else {
                    return SizedBox(width: tileW, child: _emptySlot());
                  }
                }),
              );
            },
          ),
          if (players.length >= 2 && !(_lobby?['is_full'] == true)) ...[
            const SizedBox(height: 14),
            const Divider(color: NeonColors.border, height: 1),
            const SizedBox(height: 12),
            if (canStart)
              const Row(
                children: [
                  SizedBox(
                    width: 4,
                    height: 4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NeonColors.success,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tous prêts — lancement…',
                      style: TextStyle(
                        color: NeonColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      amReady ? 'En attente des autres…' : 'Prêt à commencer ?',
                      style: TextStyle(
                        color: amReady
                            ? NeonColors.warning
                            : NeonColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeonButton(
                    text: amReady ? 'Annuler' : 'Prêt',
                    icon: amReady ? Icons.close : Icons.check,
                    variant: amReady
                        ? NeonButtonVariant.outline
                        : NeonButtonVariant.primary,
                    height: 36,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    isLoading: _isToggling,
                    onPressed: _isToggling ? () {} : _toggleReady,
                  ),
                ],
              ),
            const SizedBox(height: 4),
            const Text(
              'Tous les joueurs doivent valider pour démarrer avant que la salle soit complète.',
              style: TextStyle(
                color: NeonColors.textMuted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playerTile({
    required String name,
    required bool isSelf,
    required bool ready,
  }) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: isSelf
            ? NeonColors.primary.withValues(alpha: 0.06)
            : NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelf
              ? NeonColors.primary
              : (ready ? NeonColors.success : NeonColors.border),
          width: isSelf || ready ? 1.4 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ready
                    ? NeonColors.success.withValues(alpha: 0.14)
                    : NeonColors.primary.withValues(alpha: 0.10),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: ready ? NeonColors.success : NeonColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (ready)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: NeonColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: NeonColors.surface, width: 1.5),
                    ),
                    child:
                        const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
                ),
              if (!ready && !isSelf)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: NeonColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NeonColors.surface,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelf ? NeonColors.primary : NeonColors.textPrimary,
                fontSize: 11,
                fontWeight: isSelf ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          Text(
            isSelf
                ? 'Vous • ${ready ? 'Prêt' : 'Pas prêt'}'
                : (ready ? 'Prêt' : 'En attente'),
            style: TextStyle(
              color: ready ? NeonColors.success : NeonColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySlot() {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonColors.border,
          style: BorderStyle.solid,
          width: 1,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, color: NeonColors.textMuted, size: 22),
          SizedBox(height: 4),
          Text(
            'Place libre',
            style: TextStyle(color: NeonColors.textMuted, fontSize: 10),
          ),
          SizedBox(height: 2),
          Text(
            'En attente…',
            style: TextStyle(
              color: NeonColors.textMuted,
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowFallback() {
    final lobby = _lobby;
    final count = lobby?['players_count'] as int? ?? 0;
    return _elapsedSeconds >= 28 && count < 2;
  }

  Widget _buildFallbackHint() {
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: NeonColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hourglass_top,
              color: NeonColors.warning,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Peu de joueurs — élargissement auto en cours.',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          NeonButton(
            text: 'Salles',
            variant: NeonButtonVariant.outline,
            height: 32,
            fontSize: 11,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: () => context.go('/games/${widget.gameType}/lobby'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: NeonButton(
          text: _isCancelling ? 'Annulation…' : 'Annuler',
          variant: NeonButtonVariant.danger,
          icon: Icons.close,
          isLoading: _isCancelling,
          height: 42,
          fontSize: 13,
          onPressed: _isCancelling ? () {} : _cancelSearch,
        ),
      ),
    );
  }

  /// Motif de blocage jeu responsable (code stable `details.reason`,
  /// repli sur le texte si absent).
  String? _responsibleGamingReason() {
    if (_errorObj is! ApiException) return null;
    final apiError = _errorObj as ApiException;
    if (apiError.statusCode != 403) return null;
    if (apiError.errorCode != null &&
        apiError.errorCode != 'RESPONSIBLE_GAMING_BLOCK' &&
        apiError.errorCode != 'FORBIDDEN') {
      return null;
    }
    final reason = apiError.details?['reason']?.toString();
    if (reason != null && reason.isNotEmpty) return reason;
    // Repli texte (anciens messages) — à terme, seul `reason` compte.
    final text = (_error ?? '').toLowerCase();
    if (text.contains('auto-exclusion') || text.contains('self_excluded')) {
      return 'self_excluded';
    }
    if (text.contains('quotidienne') || text.contains('daily')) {
      return 'daily_limit_reached';
    }
    if (apiError.errorCode == 'RESPONSIBLE_GAMING_BLOCK' ||
        text.contains('jeu responsable')) {
      return 'unknown';
    }
    return null;
  }

  Widget _buildError() {
    final rgReason = _responsibleGamingReason();
    final isResponsibleGaming = rgReason != null;
    final isSelfExcluded = rgReason == 'self_excluded' || rgReason == 'cooling_off';
    final isDailyLimit = rgReason != null &&
        (rgReason.contains('daily') ||
            rgReason.contains('wager') ||
            rgReason.contains('matches') ||
            rgReason.contains('deposit'));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isResponsibleGaming ? Icons.shield_outlined : Icons.error_outline,
              color: isResponsibleGaming ? NeonColors.warning : NeonColors.error,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              isSelfExcluded
                  ? 'Compte en pause'
                  : isDailyLimit
                      ? 'Limite atteinte'
                      : isResponsibleGaming
                          ? 'Jeu responsable'
                          : 'Impossible de rejoindre',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isResponsibleGaming ? NeonColors.warning : NeonColors.error,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NeonColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (isResponsibleGaming) ...[
              NeonButton(
                text: 'Voir mes limites',
                icon: Icons.settings_outlined,
                onPressed: () => context.go('/responsible-gaming/limits'),
                width: 200,
              ),
              const SizedBox(height: 10),
              NeonButton(
                text: 'Retour',
                variant: NeonButtonVariant.outline,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/games/${widget.gameType}');
                  }
                },
                width: 200,
              ),
            ] else ...[
              NeonButton(
                text: 'Réessayer',
                onPressed: () {
                  setState(() {
                    _error = null;
                    _errorObj = null;
                    _elapsedSeconds = 0;
                  });
                  _startSearch();
                },
                width: 200,
              ),
              const SizedBox(height: 10),
              NeonButton(
                text: 'Retour',
                variant: NeonButtonVariant.outline,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/games/${widget.gameType}');
                  }
                },
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTokens(int amount) => amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fallbackName(String type) {
    switch (type) {
      case 'dice':
        return 'Jeu de Dés';
      case 'ludo':
        return 'Ludo';
      case 'cards':
        return 'Cartes';
      default:
        return type;
    }
  }
}

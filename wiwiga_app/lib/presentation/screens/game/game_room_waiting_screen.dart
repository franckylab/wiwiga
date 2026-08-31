// ============================================================
// Fichier: game_room_waiting_screen.dart
// Description: Écran d'attente salon — animations modernes, auto-start quand complet,
//              WebSocket temps réel, redirection si déjà en partie, délai forfait
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import '../../widgets/neon/token_coin.dart';
import '../../widgets/game/friend_invite_sheet.dart';

class GameRoomWaitingScreen extends ConsumerStatefulWidget {
  final GameRoomModel room;

  const GameRoomWaitingScreen({super.key, required this.room});

  @override
  ConsumerState<GameRoomWaitingScreen> createState() => _GameRoomWaitingScreenState();
}

class _GameRoomWaitingScreenState extends ConsumerState<GameRoomWaitingScreen> with TickerProviderStateMixin {
  late GameRoomModel _room;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _elapsedSeconds = 0;
  bool _isStarting = false;
  String? _error;
  bool _isFullAnimating = false;
  final Set<String> _newlyJoined = {};
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _progressCtrl;
  bool _wsListening = false;
  int _autoStartCountdown = 0;
  Timer? _autoStartTimer;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _pulseCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _shimmerCtrl = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _progressCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _startRefreshTimer();
    _startCountdown();
    _initWebSocket();
    _checkAutoStart();
  }

  void _initWebSocket() {
    try {
      final ws = ref.read(gameWebSocketServiceProvider);
      ws.joinRoom(_room.roomId);
      // Écoute temps réel des updates
      ws.onRoomUpdated = (payload) {
        if (!mounted) return;
        // Payload contient soit {room: {...}} soit directement la room
        final roomData = payload['room'] as Map<String, dynamic>? ?? payload;
        try {
          final updated = GameRoomModel.fromJson(_normalizeRoomJson(roomData, payload));
          if (updated.roomId != _room.roomId) return;
          final oldCount = _room.playersCount;
          final newCount = updated.playersCount;
          setState(() {
            // Détecter nouveaux joueurs pour animation
            for (var p in updated.players) {
              if (!_room.players.any((e) => e.id == p.id)) {
                _newlyJoined.add(p.id);
                Future.delayed(const Duration(milliseconds: 1600), () {
                  if (mounted) setState(() => _newlyJoined.remove(p.id));
                });
              }
            }
            _room = updated;
            if (newCount > oldCount) {
              _shimmerCtrl.forward(from: 0);
              _progressCtrl.forward(from: 0);
            }
          });
          _checkAutoStart();
          if (updated.matchId != null && (updated.status == 'starting' || updated.status == 'in_progress')) {
            _goToMatch(updated.matchId!);
          }
        } catch (_) {}
      };
      ws.onMatchStarted = (payload) {
        final matchId = payload['match_id'] as String? ?? payload['matchId'] as String? ?? _room.matchId;
        if (matchId != null && mounted) _goToMatch(matchId);
      };
      ws.onPlayerJoined = (payload) {
        // Joueur a rejoint — trigger animation
        if (mounted) {
          _shimmerCtrl.forward(from: 0);
          _refreshRoom(silent: true);
        }
      };
      _wsListening = true;
    } catch (_) {
      _wsListening = false;
    }
  }

  Map<String, dynamic> _normalizeRoomJson(Map<String, dynamic> data, Map<String, dynamic> full) {
    // Gère différents formats de broadcast
    if (data.containsKey('room_id')) return data;
    if (full.containsKey('room') && full['room'] is Map) return Map<String, dynamic>.from(full['room'] as Map);
    return data;
  }

  void _checkAutoStart() {
    if (_room.playersCount >= _room.maxPlayers && _room.status == 'waiting') {
      if (!_isFullAnimating) {
        setState(() {
          _isFullAnimating = true;
          _autoStartCountdown = 3;
        });
        _autoStartTimer?.cancel();
        _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          if (_autoStartCountdown <= 1) {
            t.cancel();
            // Essayer de démarrer automatiquement si créateur, sinon attendre broadcast match_started
            if (_isCreator) {
              _startMatch();
            } else {
              // Non-créateur : afficher "Lancement imminent..."
              setState(() => _autoStartCountdown = 0);
            }
          } else {
            setState(() => _autoStartCountdown--);
          }
        });
      }
    } else {
      if (_isFullAnimating && _room.playersCount < _room.maxPlayers) {
        setState(() => _isFullAnimating = false);
        _autoStartTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _autoStartTimer?.cancel();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _progressCtrl.dispose();
    try {
      final ws = ref.read(gameWebSocketServiceProvider);
      ws.leaveRoom(_room.roomId);
    } catch (_) {}
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshRoom());
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _refreshRoom({bool silent = false}) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final updatedRoom = await roomRepo.getRoom(_room.roomId);
      if (!mounted) return;
      final oldCount = _room.playersCount;
      setState(() {
        // Animer si nouveau joueur
        for (var p in updatedRoom.players) {
          if (!_room.players.any((e) => e.id == p.id)) {
            _newlyJoined.add(p.id);
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) setState(() => _newlyJoined.remove(p.id));
            });
          }
        }
        _room = updatedRoom;
        if (updatedRoom.playersCount != oldCount) {
          _shimmerCtrl.forward(from: 0);
          _progressCtrl.forward(from: 0);
        }
      });
      _checkAutoStart();
      if (updatedRoom.matchId != null && (updatedRoom.status == 'starting' || updatedRoom.status == 'in_progress')) {
        _goToMatch(updatedRoom.matchId!);
      }
    } catch (_) {
      if (!silent && mounted) {
        // ignore
      }
    }
  }

  void _goToMatch(String matchId) {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _autoStartTimer?.cancel();
    if (!mounted) return;
    // Petite animation de transition
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.pushReplacement(
        '/games/${_room.gameType}/match/$matchId',
        extra: {
          'rule_type': _room.ruleType,
          'sets_count': _room.setsCount,
          'dice_count': _room.diceCount,
          'bet_amount': _room.isStaked ? _room.betAmount : 0,
          'players': _room.players.map((p) => {'id': p.id, 'name': p.name}).toList(),
        },
      );
    });
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _isCreator {
    final userId = ref.read(authProvider).user?.id ?? '';
    return _room.creatorId == userId;
  }

  bool get _isFull => _room.playersCount >= _room.maxPlayers;

  @override
  Widget build(BuildContext context) {
    final progress = (_room.playersCount / _room.maxPlayers).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Salle d\'attente'),
            const SizedBox(width: 8),
            if (_wsListening)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: NeonColors.success, boxShadow: [BoxShadow(color: NeonColors.success.withValues(alpha: 0.6), blurRadius: 6)]),
              ),
          ],
        ),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), color: NeonColors.error, tooltip: 'Quitter la salle', onPressed: _leaveRoom),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRoomCode(progress),
            const SizedBox(height: 12),
            _buildStatusBanner(),
            const SizedBox(height: 12),
            _buildTimerProgress(progress),
            const SizedBox(height: 12),
            _buildPlayersListAnimated(),
            const SizedBox(height: 12),
            _buildGameSettings(),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: NeonColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: NeonColors.error.withValues(alpha: 0.4))),
                  child: Text(_error!, style: const TextStyle(color: NeonColors.error, fontSize: 12), textAlign: TextAlign.center),
                ),
              ),
            _buildActionButtons(),
            const SizedBox(height: 8),
            if (_isFull)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: NeonColors.success.withValues(alpha: 0.12 + _pulseCtrl.value * 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: NeonColors.success.withValues(alpha: 0.5))),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: NeonColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(_autoStartCountdown > 0 ? 'Lancement dans $_autoStartCountdown s...' : 'Lancement imminent...', style: const TextStyle(color: NeonColors.success, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6)),
                    const SizedBox(width: 8),
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeonColors.success, value: _autoStartCountdown > 0 ? (3 - _autoStartCountdown) / 3 : null)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCode(double progress) {
    return NeonCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Code de la salle', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: NeonColors.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                child: Text('${_room.playersCount}/${_room.maxPlayers} joueurs', style: const TextStyle(color: NeonColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _room.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié !'), backgroundColor: NeonColors.success));
            },
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (context, child) {
                final shimmer = _shimmerCtrl.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: NeonColors.primary.withValues(alpha: 0.1 + shimmer * 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NeonColors.primary.withValues(alpha: 0.3 + shimmer * 0.2), width: 1.2),
                    boxShadow: [BoxShadow(color: NeonColors.primary.withValues(alpha: 0.18 + shimmer * 0.12), blurRadius: 12)],
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag_rounded, color: NeonColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(_room.roomCode, style: const TextStyle(color: NeonColors.primary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, fontFamily: 'Orbitron')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: NeonColors.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.copy_rounded, color: NeonColors.primary, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Appuyez pour copier • Partagez ce code à vos amis', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedBuilder(
              animation: _progressCtrl,
              builder: (context, _) => LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: NeonColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(_isFull ? NeonColors.success : NeonColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isFull = _isFull;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFull ? NeonColors.success.withValues(alpha: 0.12) : NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFull ? NeonColors.success.withValues(alpha: 0.5) : NeonColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isFull ? NeonColors.success.withValues(alpha: 0.18) : NeonColors.primary.withValues(alpha: 0.12), border: Border.all(color: isFull ? NeonColors.success : NeonColors.primary)),
            child: Icon(isFull ? Icons.celebration_rounded : Icons.hourglass_top_rounded, size: 18, color: isFull ? NeonColors.success : NeonColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isFull ? 'Salle complète !' : 'En attente de joueurs...', style: TextStyle(color: isFull ? NeonColors.success : NeonColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text(isFull ? 'La partie va démarrer automatiquement' : '${_room.maxPlayers - _room.playersCount} place(s) restante(s) • Démarrage auto quand complet', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          if (_wsListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: NeonColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 12, color: NeonColors.success),
                  SizedBox(width: 4),
                  Text('Temps réel', style: TextStyle(color: NeonColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerProgress(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: NeonColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: NeonColors.border)),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: NeonColors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text('Attente: $_formattedTime', style: const TextStyle(color: NeonColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${(progress * 100).toInt()}% rempli', style: TextStyle(color: _isFull ? NeonColors.success : NeonColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: NeonColors.border, valueColor: AlwaysStoppedAnimation<Color>(_isFull ? NeonColors.success : NeonColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersListAnimated() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_rounded, size: 16, color: NeonColors.primary),
                  SizedBox(width: 6),
                  Text('Joueurs', style: TextStyle(color: NeonColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _isFull ? NeonColors.success.withValues(alpha: 0.14) : NeonColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: _isFull ? NeonColors.success : NeonColors.primary.withValues(alpha: 0.3))),
                child: Text('${_room.playersCount}/${_room.maxPlayers}', style: TextStyle(color: _isFull ? NeonColors.success : NeonColors.primary, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Orbitron')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Joueurs avec animation join
          ..._room.players.asMap().entries.map((entry) {
            final player = entry.value;
            final isNew = _newlyJoined.contains(player.id);
            final isCreator = player.id == _room.creatorId;
            final isMe = player.id == (ref.read(authProvider).user?.id ?? '');
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isNew ? NeonColors.success.withValues(alpha: 0.12) : (isMe ? NeonColors.primary.withValues(alpha: 0.08) : NeonColors.surface),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isNew ? NeonColors.success : (isMe ? NeonColors.primary.withValues(alpha: 0.4) : NeonColors.border)),
                boxShadow: isNew ? [BoxShadow(color: NeonColors.success.withValues(alpha: 0.25), blurRadius: 10)] : null,
              ),
              child: Row(
                children: [
                  // Avatar animé
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: isNew ? 0.0 : 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isCreator ? NeonColors.primary.withValues(alpha: 0.25) : (isMe ? NeonColors.primary.withValues(alpha: 0.18) : NeonColors.card),
                          child: Text(
                            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                            style: TextStyle(color: isCreator ? NeonColors.primary : (isMe ? NeonColors.primary : NeonColors.textPrimary), fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        if (isNew)
                          Positioned(
                            right: -2, top: -2,
                            child: Container(
                              width: 14, height: 14,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: NeonColors.success),
                              child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(isMe ? 'Moi' : player.name, style: TextStyle(color: isMe ? NeonColors.primary : NeonColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13))),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: NeonColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: NeonColors.primary.withValues(alpha: 0.3))),
                                child: const Text('MOI', style: TextStyle(color: NeonColors.primary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                              ),
                            ],
                            if (isCreator) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: NeonColors.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: const Text('CRÉATEUR', style: TextStyle(color: NeonColors.secondary, fontSize: 8, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                        if (!isMe)
                          Text(player.name, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (isMe) const Text('Toi', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isNew
                        ? Container(
                            key: const ValueKey('new'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: NeonColors.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Nouveau !', style: TextStyle(color: NeonColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
                          )
                        : const Icon(Icons.check_circle_rounded, key: ValueKey('ok'), color: NeonColors.success, size: 20),
                  ),
                ],
              ),
            );
          }),
          // Slots vides animés
          if (_room.playersCount < _room.maxPlayers)
            ...List.generate(_room.maxPlayers - _room.playersCount, (i) {
              final delay = i * 100;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + delay),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: NeonColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NeonColors.border, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: NeonColors.surface, border: Border.all(color: NeonColors.border, style: BorderStyle.solid)),
                        child: const Icon(Icons.person_add_outlined, color: NeonColors.textSecondary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('En attente...', style: TextStyle(color: NeonColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13)),
                            Text('Slot libre', style: TextStyle(color: NeonColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) => Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: NeonColors.textSecondary.withValues(alpha: 0.4 + _pulseCtrl.value * 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGameSettings() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_rounded, size: 16, color: NeonColors.primary),
              SizedBox(width: 6),
              Text('Paramètres', style: TextStyle(color: NeonColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _settingRow('Mode', _room.modeLabel, Icons.style_rounded),
          _settingRow('Règles', _room.ruleType == 'normal' ? 'Normal — Plus haut gagne' : 'Cible — Plus proche gagne', Icons.rule_rounded),
          _settingRow('Sets', '${_room.setsCount} (premier à ${(_room.setsCount ~/ 2) + 1})', Icons.layers_rounded),
          _settingRow('Dés', '${_room.diceCount} dé${_room.diceCount > 1 ? 's' : ''}', Icons.casino_rounded),
          if (_room.isStaked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: NeonColors.tokenGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: NeonColors.tokenGold.withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    TokenCoin(size: 20, metal: TokenMetal.gold, lod: TokenLod.bevel, showShadow: false),
                    const SizedBox(width: 8),
                    const Text('Mise', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    Text('${_room.betAmount} wiga', style: const TextStyle(color: NeonColors.tokenGold, fontWeight: FontWeight.w900, fontFamily: 'Orbitron')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: NeonColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canStart = _isCreator && _room.playersCount >= 2 && !_isFull;
    return Column(
      children: [
        NeonButton(
          text: 'Inviter un ami',
          onPressed: _inviteFriend,
          variant: NeonButtonVariant.secondary,
          icon: Icons.person_add_rounded,
        ),
        const SizedBox(height: 10),
        if (canStart)
          NeonButton(
            text: 'Démarrer la partie (${_room.playersCount}/${_room.maxPlayers})',
            onPressed: _isStarting ? () {} : _startMatch,
            isLoading: _isStarting,
            variant: NeonButtonVariant.success,
            icon: Icons.play_arrow_rounded,
          ),
        if (_isFull && _isCreator)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: NeonButton(
              text: _isStarting ? 'Lancement...' : 'Lancer maintenant',
              onPressed: _isStarting ? () {} : _startMatch,
              isLoading: _isStarting,
              variant: NeonButtonVariant.primary,
              icon: Icons.rocket_launch_rounded,
            ),
          ),
        if (!_isCreator && !_isFull)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: NeonColors.textSecondary)),
                SizedBox(width: 8),
                Text('En attente de l\'hôte...', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _inviteFriend() async {
    FriendInviteSheet.show(
      context,
      roomCode: _room.roomCode,
      roomId: _room.roomId,
      excludePlayerIds: _room.players.map((p) => p.id).toList(),
    );
  }

  Future<void> _startMatch() async {
    if (_isStarting) return;
    setState(() { _isStarting = true; _error = null; });
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final result = await roomRepo.startMatch(_room.roomId);
      if (!mounted) return;
      final matchId = result['match_id'] as String? ?? result['matchId'] as String? ?? _room.matchId;
      if (matchId != null) {
        _goToMatch(matchId);
      } else {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match créé, en attente...'), backgroundColor: NeonColors.primary));
        _refreshRoom();
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'GameRoomWaiting.startMatch');
      if (mounted) setState(() { _isStarting = false; _error = ErrorHandler.userMessage(e); });
    }
  }

  Future<void> _leaveRoom() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      await roomRepo.leaveRoom(_room.roomId);
    } catch (_) {}
    if (!mounted) return;
    try { ref.read(gameWebSocketServiceProvider).leaveRoom(_room.roomId); } catch (_) {}
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games/${_room.gameType}');
    }
  }
}

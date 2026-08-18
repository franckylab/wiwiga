// ============================================================
// Fichier: game_room_waiting_screen.dart
// Description: Écran d'attente dans une salle de jeu
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import '../../widgets/game/friend_invite_sheet.dart';

/// Écran d'attente dans une salle de jeu
class GameRoomWaitingScreen extends ConsumerStatefulWidget {
  final GameRoomModel room;

  const GameRoomWaitingScreen({super.key, required this.room});

  @override
  ConsumerState<GameRoomWaitingScreen> createState() => _GameRoomWaitingScreenState();
}

class _GameRoomWaitingScreenState extends ConsumerState<GameRoomWaitingScreen> {
  late GameRoomModel _room;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _elapsedSeconds = 0;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _startRefreshTimer();
    _startCountdown();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshRoom());
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _refreshRoom() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final updatedRoom = await roomRepo.getRoom(_room.roomId);
      if (!mounted) return;
      setState(() => _room = updatedRoom);

      // Le match a démarré (par le créateur) : rejoindre l'écran de match
      if (updatedRoom.matchId != null &&
          (updatedRoom.status == 'starting' || updatedRoom.status == 'in_progress')) {
        _goToMatch(updatedRoom.matchId!);
      }
    } catch (_) {
      // Silent refresh failure
    }
  }

  void _goToMatch(String matchId) {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    context.pushReplacement(
      '/games/${_room.gameType}/match/$matchId',
      extra: {
        'rule_type': _room.ruleType,
        'sets_count': _room.setsCount,
        'dice_count': _room.diceCount,
        'bet_amount': _room.isBetting ? _room.betAmount : 0,
        'players': _room.players.map((p) => {'id': p.id, 'name': p.name}).toList(),
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Salle d\'attente'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: NeonColors.error,
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRoomCode(),
            const SizedBox(height: 16),
            _buildTimer(),
            const SizedBox(height: 16),
            _buildPlayersList(),
            const SizedBox(height: 16),
            _buildGameSettings(),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: NeonColors.error), textAlign: TextAlign.center),
              ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCode() {
    return NeonCard(
      child: Column(
        children: [
          const Text('Code de la salle', style: TextStyle(color: NeonColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _room.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copié !', style: TextStyle(color: NeonColors.primary))),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: NeonColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NeonColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _room.roomCode,
                    style: const TextStyle(
                      color: NeonColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, color: NeonColors.primary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Appuyez pour copier', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: NeonColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Attente: $_formattedTime',
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Joueurs', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '${_room.playersCount}/${_room.maxPlayers}',
                style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Liste des joueurs
          ..._room.players.map((player) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: player.id == _room.creatorId ? NeonColors.primary.withValues(alpha: 0.3) : NeonColors.surface,
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      if (player.id == _room.creatorId)
                        const Text('Créateur', style: TextStyle(color: NeonColors.primary, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: NeonColors.success, size: 20),
              ],
            ),
          ),),
          // Slots vides
          if (_room.playersCount < _room.maxPlayers)
            ...List.generate(_room.maxPlayers - _room.playersCount, (_) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: NeonColors.surface,
                    child: Icon(Icons.person_add_outlined, color: NeonColors.textSecondary, size: 18),
                  ),
                  SizedBox(width: 12),
                  Text('En attente...', style: TextStyle(color: NeonColors.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ),
            ),),
        ],
      ),
    );
  }

  Widget _buildGameSettings() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paramètres', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _settingRow('Mode', _room.isFree ? 'Gratuit' : 'Pari'),
          _settingRow('Règles', _room.ruleType == 'normal' ? 'Normal' : 'Cible'),
          _settingRow('Sets', '${_room.setsCount}'),
          _settingRow('Dés', '${_room.diceCount}'),
          if (_room.isBetting) _settingRow('Mise', '${_room.betAmount} jetons'),
        ],
      ),
    );
  }

  Widget _settingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Bouton Inviter
        NeonButton(
          text: 'Inviter un ami',
          onPressed: _inviteFriend,
          variant: NeonButtonVariant.secondary,
          icon: Icons.person_add_outlined,
        ),
        const SizedBox(height: 12),
        // Bouton Démarrer (visible si créateur + assez de joueurs + mode betting)
        if (_isCreator && _room.playersCount >= 2)
          NeonButton(
            text: 'Démarrer la partie',
            onPressed: _isStarting ? () {} : _startMatch,
            isLoading: _isStarting,
            variant: NeonButtonVariant.success,
            icon: Icons.play_arrow,
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
    setState(() { _isStarting = true; _error = null; });

    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final result = await roomRepo.startMatch(_room.roomId);

      if (!mounted) return;

      final matchId = result['match_id'] as String? ?? _room.matchId;
      if (matchId != null) {
        _goToMatch(matchId);
      } else {
        setState(() => _isStarting = false);
      }
    } catch (e) {
      setState(() { _isStarting = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _leaveRoom() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      await roomRepo.leaveRoom(_room.roomId);
    } catch (_) {}

    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games/${_room.gameType}');
    }
  }
}

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
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import 'create_game_screen.dart';

/// Écran d'attente dans une salle de jeu
class GameRoomWaitingScreen extends ConsumerStatefulWidget {
  final GameRoomModel room;

  const GameRoomWaitingScreen({Key? key, required this.room}) : super(key: key);

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
      if (mounted) setState(() => _room = updatedRoom);
    } catch (_) {
      // Silent refresh failure
    }
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _isCreator {
    // TODO: Comparer avec l'ID utilisateur connecté
    return true;
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
                child: Text(_error!, style: TextStyle(color: NeonColors.error), textAlign: TextAlign.center),
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
          Text('Code de la salle', style: TextStyle(color: NeonColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _room.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Code copié !', style: TextStyle(color: NeonColors.primary))),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: NeonColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NeonColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _room.roomCode,
                    style: TextStyle(
                      color: NeonColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.copy, color: NeonColors.primary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Appuyez pour copier', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
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
          Icon(Icons.timer_outlined, color: NeonColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Attente: $_formattedTime',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 16),
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
              Text('Joueurs', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '${_room.playersCount}/${_room.maxPlayers}',
                style: TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
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
                  backgroundColor: player.id == _room.creatorId ? NeonColors.primary.withOpacity(0.3) : NeonColors.surface,
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      if (player.id == _room.creatorId)
                        Text('Créateur', style: TextStyle(color: NeonColors.primary, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: NeonColors.success, size: 20),
              ],
            ),
          )),
          // Slots vides
          if (_room.playersCount < _room.maxPlayers)
            ...List.generate(_room.maxPlayers - _room.playersCount, (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: NeonColors.surface,
                    child: Icon(Icons.person_add_outlined, color: NeonColors.textSecondary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('En attente...', style: TextStyle(color: NeonColors.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildGameSettings() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paramètres', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _settingRow('Mode', _room.isFree ? 'Gratuit' : 'Pari'),
          _settingRow('Règles', _room.ruleType == 'normal' ? 'Normal' : 'Cible'),
          _settingRow('Sets', '${_room.setsCount}'),
          _settingRow('Dés', '${_room.diceCount}'),
          if (_room.isBetting) _settingRow('Mise', '${_room.betAmount} FCFA'),
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
          Text(label, style: TextStyle(color: NeonColors.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600)),
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
    // TODO: Ouvrir FriendInviteSheet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partagez le code: ${_room.roomCode}', style: TextStyle(color: NeonColors.primary)),
        backgroundColor: NeonColors.surface,
      ),
    );
  }

  Future<void> _startMatch() async {
    setState(() { _isStarting = true; _error = null; });

    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      await roomRepo.startMatch(_room.roomId);

      if (!mounted) return;

      // TODO: Naviguer vers DiceMatchScreen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partie démarrée !', style: TextStyle(color: NeonColors.success))),
      );
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

    if (mounted) Navigator.pop(context);
  }
}

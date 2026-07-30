// ============================================================
// Fichier: game_lobby_enhanced_screen.dart
// Description: Lobby améliorée avec données réelles API
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import '../game/create_game_screen.dart';
import '../game/game_room_waiting_screen.dart';
import '../dice_game/dice_match_screen.dart';

/// Lobby améliorée avec 4 sections:
/// 1. Parties en attente (depuis API)
/// 2. Créer une partie
/// 3. Rejoindre par code
/// 4. Auto-match (matchmaking avec fallback)
class GameLobbyEnhancedScreen extends ConsumerStatefulWidget {
  const GameLobbyEnhancedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GameLobbyEnhancedScreen> createState() => _GameLobbyEnhancedScreenState();
}

class _GameLobbyEnhancedScreenState extends ConsumerState<GameLobbyEnhancedScreen> {
  final _codeController = TextEditingController();
  Timer? _refreshTimer;
  List<GameRoomModel> _rooms = [];
  bool _isLoading = true;
  String? _error;
  String _filterMode = 'all'; // 'all' | 'free' | 'betting'

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadRooms());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final mode = _filterMode == 'all' ? null : _filterMode;
      final rooms = await roomRepo.listWaitingRooms(gameType: 'dice', mode: mode);
      if (mounted) setState(() { _rooms = rooms; _isLoading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: NeonColors.primary,
      backgroundColor: NeonColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildJoinByCode(),
            const SizedBox(height: 16),
            _buildFilterTabs(),
            const SizedBox(height: 12),
            _buildRoomsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parties disponibles',
                style: TextStyle(color: NeonColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_rooms.length} salle${_rooms.length > 1 ? 's' : ''} en attente',
                style: TextStyle(color: NeonColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: NeonColors.primary))
        else
          IconButton(
            icon: Icon(Icons.refresh, color: NeonColors.primary),
            onPressed: _loadRooms,
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: NeonButton(
            text: 'Créer',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGameScreen()));
            },
            icon: Icons.add_circle_outline,
            height: 48,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NeonButton(
            text: 'Auto-match',
            onPressed: _startAutoMatch,
            variant: NeonButtonVariant.secondary,
            icon: Icons.shuffle,
            height: 48,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildJoinByCode() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rejoindre par code', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: TextStyle(color: NeonColors.textPrimary, letterSpacing: 2, fontWeight: FontWeight.bold),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'WIWIGA-XXXX',
                    hintStyle: TextStyle(color: NeonColors.textSecondary, letterSpacing: 1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: NeonColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              NeonButton(
                text: 'Go',
                onPressed: _joinByCode,
                height: 40,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        _filterChip('all', 'Toutes'),
        const SizedBox(width: 8),
        _filterChip('free', 'Gratuit'),
        const SizedBox(width: 8),
        _filterChip('betting', 'Pari'),
      ],
    );
  }

  Widget _filterChip(String mode, String label) {
    final isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _filterMode = mode);
        _loadRooms();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withOpacity(0.2) : NeonColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? NeonColors.primary : NeonColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_isLoading && _rooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: NeonColors.primary),
        ),
      );
    }

    if (_error != null && _rooms.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: NeonColors.error, size: 48),
            const SizedBox(height: 8),
            Text('Erreur de chargement', style: TextStyle(color: NeonColors.error)),
            const SizedBox(height: 8),
            NeonButton(text: 'Réessayer', onPressed: _loadRooms, height: 40, fontSize: 13),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.sports_esports_outlined, color: NeonColors.textSecondary, size: 64),
            const SizedBox(height: 12),
            Text('Aucune partie en attente', style: TextStyle(color: NeonColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Créez une partie ou lancez un auto-match !', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: _rooms.map((room) => _buildRoomCard(room)).toList(),
    );
  }

  Widget _buildRoomCard(GameRoomModel room) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _joinRoom(room),
        child: NeonCard(
          child: Row(
            children: [
              // Type badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: room.isBetting ? NeonColors.success.withOpacity(0.2) : NeonColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  room.isBetting ? Icons.account_balance_wallet : Icons.people_outline,
                  color: room.isBetting ? NeonColors.success : NeonColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          room.ruleType == 'normal' ? 'Normal' : 'Cible',
                          style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NeonColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${room.setsCount} sets',
                            style: TextStyle(color: NeonColors.textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${room.playersCount}/${room.maxPlayers} joueurs',
                          style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                        ),
                        if (room.isBetting) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${room.betAmount} FCFA',
                            style: TextStyle(color: NeonColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Join button
              Icon(Icons.arrow_forward_ios, color: NeonColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinRoom(GameRoomModel room) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final updatedRoom = await roomRepo.joinRoom(room.roomId);

      if (!mounted) return;

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GameRoomWaitingScreen(room: updatedRoom),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final room = await roomRepo.joinByCode(code);

      if (!mounted) return;

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GameRoomWaitingScreen(room: room),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code invalide ou erreur: $e')),
      );
    }
  }

  void _startAutoMatch() {
    // TODO: Naviguer vers MatchmakingSearchingScreen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Matchmaking en cours de développement', style: TextStyle(color: NeonColors.primary))),
    );
  }
}

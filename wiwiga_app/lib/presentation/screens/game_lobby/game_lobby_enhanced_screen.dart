// ============================================================
// Fichier: game_lobby_enhanced_screen.dart
// Description: Lobby améliorée avec données réelles API
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/errors/api_exception.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/config_provider.dart';
import '../../../data/repositories/room_repository.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';

/// Lobby améliorée avec 4 sections:
/// 1. Parties en attente (depuis API)
/// 2. Créer une partie
/// 3. Rejoindre par code
/// 4. Auto-match (matchmaking avec fallback)
class GameLobbyEnhancedScreen extends ConsumerStatefulWidget {
  final String gameType;

  const GameLobbyEnhancedScreen({super.key, this.gameType = 'dice'});

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
      final rooms = await roomRepo.listWaitingRooms(gameType: widget.gameType, mode: mode);
      if (mounted) setState(() { _rooms = rooms; _isLoading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Lobby'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour au jeu',
          onPressed: () => context.go('/games/${widget.gameType}'),
        ),
      ),
      body: RefreshIndicator(
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
      ),
    );
  }

  Widget _buildHeader() {
    final gamesConfig = ref.watch(gamesConfigProvider);
    final gameConfig = gamesConfig.when(
      data: (config) => config.gameTypes[widget.gameType],
      loading: () => null,
      error: (_, __) => null,
    );

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parties disponibles',
                style: TextStyle(color: NeonColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_rooms.length} salle${_rooms.length > 1 ? 's' : ''} en attente',
                style: const TextStyle(color: NeonColors.textSecondary, fontSize: 14),
              ),
              if (gameConfig != null) ...[                const SizedBox(height: 2),
                Text(
                  'Mise: ${gameConfig.minBet} - ${gameConfig.maxBet} jetons | Commission: ${gameConfig.commissionPercent.toInt()}%',
                  style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        if (_isLoading)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: NeonColors.primary))
        else
          IconButton(
            icon: const Icon(Icons.refresh, color: NeonColors.primary),
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
              context.push('/games/${widget.gameType}/create');
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
          const Text('Rejoindre par code', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(color: NeonColors.textPrimary, letterSpacing: 2, fontWeight: FontWeight.bold),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'WIWIGA-XXXX',
                    hintStyle: const TextStyle(color: NeonColors.textSecondary, letterSpacing: 1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: NeonColors.border),
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
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.2) : NeonColors.surface,
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
            const Icon(Icons.error_outline, color: NeonColors.error, size: 48),
            const SizedBox(height: 8),
            const Text('Erreur de chargement', style: TextStyle(color: NeonColors.error)),
            const SizedBox(height: 8),
            NeonButton(text: 'Réessayer', onPressed: _loadRooms, height: 40, fontSize: 13),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return const Center(
        child: Column(
          children: [
            Icon(Icons.sports_esports_outlined, color: NeonColors.textSecondary, size: 64),
            SizedBox(height: 12),
            Text('Aucune partie en attente', style: TextStyle(color: NeonColors.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
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
                  color: room.isBetting ? NeonColors.success.withValues(alpha: 0.2) : NeonColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  room.isBetting ? Icons.monetization_on : Icons.people_outline,
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
                          style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold),
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
                            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${room.playersCount}/${room.maxPlayers} joueurs',
                          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                        ),
                        if (room.isBetting) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${room.betAmount} jetons',
                            style: const TextStyle(color: NeonColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Join button
              const Icon(Icons.arrow_forward_ios, color: NeonColors.textSecondary, size: 16),
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

      context.push('/games/${widget.gameType}/room/${updatedRoom.roomId}', extra: updatedRoom);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_joinErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Erreur inattendue. Réessayez.');
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showErrorSnackBar('Veuillez saisir un code de partie.');
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final roomRepo = RoomRepository(apiService);
      final room = await roomRepo.joinByCode(code);

      if (!mounted) return;

      context.push('/games/${widget.gameType}/room/${room.roomId}', extra: room);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_joinErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Erreur inattendue. Réessayez.');
    }
  }

  /// Message d'erreur utilisateur pour les conflits de salle (409)
  String _joinErrorMessage(ApiException e) {
    if (e.isConflict) {
      switch (e.errorCode) {
        case 'ROOM_FULL':
          return 'Cette salle est pleine. Choisissez une autre partie.';
        case 'ROOM_NOT_WAITING':
          return 'Cette partie a déjà commencé ou n\'est plus disponible.';
        case 'ALREADY_IN_ROOM':
          return 'Vous êtes déjà dans une partie. Quittez-la d\'abord.';
        default:
          return e.message;
      }
    }
    if (e.isNetworkError) {
      return 'Problème de connexion. Vérifiez votre réseau.';
    }
    if (e.isNotFound) {
      return 'Code de partie invalide. Vérifiez et réessayez.';
    }
    return e.userMessage;
  }

  /// Affiche un SnackBar d'erreur stylisé
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: NeonColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _startAutoMatch() async {
    // Récupérer la mise minimale depuis la config admin
    final gamesConfig = ref.read(gamesConfigProvider);
    final betAmount = gamesConfig.when(
      data: (config) {
        final gameConfig = config.gameTypes[widget.gameType];
        return gameConfig?.minBet ?? 500;
      },
      loading: () => 500,
      error: (_, __) => 500,
    );

    try {
      final repo = ref.read(gameRepositoryProvider);
      final result = await repo.joinGame(gameId: widget.gameType, betAmount: betAmount);

      if (!mounted) return;

      if (result['status'] == 'matched') {
        final gameId = result['game_id'] as String? ?? '';
        context.push('/games/${widget.gameType}/session/$gameId', extra: {'bet_amount': betAmount});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('En file d\'attente... un adversaire arrive bientôt !', style: TextStyle(color: NeonColors.primary)),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.userMessage);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Erreur inattendue. Réessayez.');
    }
  }
}

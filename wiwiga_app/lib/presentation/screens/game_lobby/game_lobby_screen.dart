import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../dice_game/dice_game_screen.dart';

// === Providers ===

enum MatchmakingMode { create, join, autoMatch }

enum GameRoomStatus { waiting, starting, inProgress, ended }

class GameRoom {
  final String id;
  final String gameType;
  final String creatorName;
  final int betAmount;
  final int currentPlayers;
  final int maxPlayers;
  final int minPlayers;
  final GameRoomStatus status;
  final DateTime createdAt;

  GameRoom({
    required this.id,
    required this.gameType,
    required this.creatorName,
    required this.betAmount,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.minPlayers,
    required this.status,
    required this.createdAt,
  });
}

final matchmakingModeProvider =
    StateProvider<MatchmakingMode>((ref) => MatchmakingMode.autoMatch);

final betAmountProvider = StateProvider<int>((ref) => 500);

final maxPlayersProvider = StateProvider<int>((ref) => 2);

final availableRoomsProvider = StateProvider<List<GameRoom>>((ref) => [
      GameRoom(
        id: 'room_1',
        gameType: 'dice',
        creatorName: 'Joueur_X',
        betAmount: 500,
        currentPlayers: 1,
        maxPlayers: 4,
        minPlayers: 2,
        status: GameRoomStatus.waiting,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      GameRoom(
        id: 'room_2',
        gameType: 'dice',
        creatorName: 'ProGamer',
        betAmount: 1000,
        currentPlayers: 3,
        maxPlayers: 5,
        minPlayers: 2,
        status: GameRoomStatus.waiting,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      GameRoom(
        id: 'room_3',
        gameType: 'dice',
        creatorName: 'Chanceux',
        betAmount: 200,
        currentPlayers: 1,
        maxPlayers: 2,
        minPlayers: 2,
        status: GameRoomStatus.waiting,
        createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
      ),
    ],);

final isSearchingProvider = StateProvider<bool>((ref) => false);

// === Écran GameLobby ===

class GameLobbyScreen extends ConsumerStatefulWidget {
  final String gameType;

  const GameLobbyScreen({super.key, this.gameType = 'dice'});

  @override
  ConsumerState<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends ConsumerState<GameLobbyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _searchController;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _searchController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(matchmakingModeProvider);
    final isSearching = ref.watch(isSearchingProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Mode Selector
            _buildModeSelector(),
            // Content based on mode
            Expanded(
              child: isSearching
                  ? _buildSearchingView()
                  : _buildModeContent(mode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: NeonGradients.cta,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.casino, color: NeonColors.primary, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JEU DE DÉS',
                  style: AppTypography.heading3.copyWith(
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Prédis la somme des 2 dés',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const GlowBadge(
            text: 'EN LIGNE',
            color: NeonColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final mode = ref.watch(matchmakingModeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _ModeChip(
            icon: Icons.add_circle_outline,
            label: 'Créer',
            isSelected: mode == MatchmakingMode.create,
            onTap: () => ref.read(matchmakingModeProvider.notifier).state =
                MatchmakingMode.create,
          ),
          const SizedBox(width: 8),
          _ModeChip(
            icon: Icons.list_alt,
            label: 'Rejoindre',
            isSelected: mode == MatchmakingMode.join,
            onTap: () => ref.read(matchmakingModeProvider.notifier).state =
                MatchmakingMode.join,
          ),
          const SizedBox(width: 8),
          _ModeChip(
            icon: Icons.flash_on,
            label: 'Auto',
            isSelected: mode == MatchmakingMode.autoMatch,
            onTap: () => ref.read(matchmakingModeProvider.notifier).state =
                MatchmakingMode.autoMatch,
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(MatchmakingMode mode) {
    switch (mode) {
      case MatchmakingMode.create:
        return _buildCreateView();
      case MatchmakingMode.join:
        return _buildJoinView();
      case MatchmakingMode.autoMatch:
        return _buildAutoMatchView();
    }
  }

  // === CREATE VIEW ===

  Widget _buildCreateView() {
    final betAmount = ref.watch(betAmountProvider);
    final maxPlayers = ref.watch(maxPlayersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CRÉER UNE PARTIE', style: AppTypography.heading3),
          const SizedBox(height: 20),

          // Mise
          NeonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: NeonColors.primary),
                    const SizedBox(width: 8),
                    Text('MISE PAR JOUEUR',
                        style: AppTypography.subtitle,),
                  ],
                ),
                const SizedBox(height: 16),
                // Presets
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 250, 500, 1000, 2500, 5000].map((amount) {
                    final isSelected = betAmount == amount;
                    return GestureDetector(
                      onTap: () => ref.read(betAmountProvider.notifier).state =
                          amount,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10,),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? NeonColors.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? NeonColors.primary
                                : NeonColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: NeonColors.primary
                                        .withValues(alpha: NeonGlow.opacityLow),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '${_formatTokens(amount)} jetons',
                          style: TextStyle(
                            color: isSelected
                                ? NeonColors.primary
                                : NeonColors.textSecondary,
                            fontFamily: 'Orbitron',
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Custom amount
                NeonInput(
                  label: 'Montant personnalisé',
                  hint: 'Entrez un montant',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final amount = int.tryParse(value);
                    if (amount != null && amount >= 100) {
                      ref.read(betAmountProvider.notifier).state = amount;
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Nombre de joueurs
          NeonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: NeonColors.secondary),
                    const SizedBox(width: 8),
                    Text('JOUEURS MAX', style: AppTypography.subtitle),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Minimum 2 joueurs pour démarrer',
                  style: TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [2, 3, 4, 5].map((num) {
                    final isSelected = maxPlayers == num;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(maxPlayersProvider.notifier).state = num,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? NeonColors.secondary.withValues(alpha: 0.2)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? NeonColors.secondary
                                  : NeonColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: NeonColors.secondary
                                          .withValues(alpha: NeonGlow.opacityLow),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$num',
                            style: TextStyle(
                              color: isSelected
                                  ? NeonColors.secondary
                                  : NeonColors.textSecondary,
                              fontFamily: 'Orbitron',
                              fontSize: 18,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Résumé + bouton créer
          NeonCard(
            child: Column(
              children: [
                _SummaryRow(
                    label: 'Mise', value: '${_formatTokens(betAmount)} jetons',),
                _SummaryRow(
                    label: 'Joueurs max', value: '$maxPlayers',),
                const _SummaryRow(
                    label: 'Min. pour démarrer', value: '2',),
                const SizedBox(height: 16),
                NeonButton(
                  text: 'CRÉER LA PARTIE',
                  onPressed: _startCreateGame,
                  variant: NeonButtonVariant.primary,
                  icon: Icons.play_arrow,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === JOIN VIEW ===

  Widget _buildJoinView() {
    final rooms = ref.watch(availableRoomsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('PARTIES EN ATTENTE', style: AppTypography.heading3),
              const Spacer(),
              GlowBadge(
                text: '${rooms.length} disponibles',
                color: NeonColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_empty,
                          color: NeonColors.textSecondary, size: 48,),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune partie en attente',
                        style: TextStyle(
                          color: NeonColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 16),
                      NeonButton(
                        text: 'CRÉER UNE PARTIE',
                        onPressed: () => ref
                            .read(matchmakingModeProvider.notifier)
                            .state = MatchmakingMode.create,
                        variant: NeonButtonVariant.outline,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _RoomCard(
                      room: room,
                      onJoin: () => _joinRoom(room),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // === AUTO MATCH VIEW ===

  Widget _buildAutoMatchView() {
    final betAmount = ref.watch(betAmountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Animated icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: NeonColors.primary
                          .withValues(alpha: _pulseController.value * 0.5),
                      blurRadius: 30 + _pulseController.value * 20,
                      spreadRadius: 5 + _pulseController.value * 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor:
                      NeonColors.primary.withValues(alpha: 0.1 + _pulseController.value * 0.1),
                  child: const Icon(
                    Icons.casino,
                    size: 60,
                    color: NeonColors.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'AUTO-MATCHING',
            style: AppTypography.heading2,
          ),
          const SizedBox(height: 8),
          const Text(
            'Trouve automatiquement un adversaire\navec la même mise que vous',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Mise
          NeonCard(
            child: Column(
              children: [
                Text('VOTRE MISE', style: AppTypography.subtitle),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 500, 1000, 5000].map((amount) {
                    final isSelected = betAmount == amount;
                    return GestureDetector(
                      onTap: () =>
                          ref.read(betAmountProvider.notifier).state = amount,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12,),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? NeonColors.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? NeonColors.primary
                                : NeonColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          _formatTokens(amount),
                          style: TextStyle(
                            color: isSelected
                                ? NeonColors.primary
                                : NeonColors.textSecondary,
                            fontFamily: 'Orbitron',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          NeonButton(
            text: 'TROUVER UN ADVERSAIRE',
            onPressed: _startAutoMatch,
            variant: NeonButtonVariant.primary,
            icon: Icons.flash_on,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  // === SEARCHING VIEW ===

  Widget _buildSearchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated search indicator
          AnimatedBuilder(
            animation: _searchController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NeonColors.primary
                            .withValues(alpha: 0.3 + _searchController.value * 0.4),
                        width: 3,
                      ),
                    ),
                  ),
                  // Inner ring
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NeonColors.secondary
                            .withValues(alpha: 0.3 + (1 - _searchController.value) * 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                  // Center icon
                  const Icon(
                    Icons.search,
                    size: 40,
                    color: NeonColors.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'RECHERCHE EN COURS...',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 8),
          Text(
            'Mise: ${_formatTokens(ref.watch(betAmountProvider))} jetons',
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(height: 32),
          NeonButton(
            text: 'ANNULER',
            onPressed: _cancelSearch,
            variant: NeonButtonVariant.danger,
          ),
        ],
      ),
    );
  }

  // === Actions ===

  void _startCreateGame() async {
    final gameWs = ref.read(gameWebSocketServiceProvider);
    final betAmount = ref.read(betAmountProvider);
    final maxPlayers = ref.read(maxPlayersProvider);
    
    // Connecter WebSocket si nécessaire
    if (!gameWs.isConnected && !gameWs.isFallbackMode) {
      await gameWs.connect();
    }
    
    try {
      final result = await gameWs.joinMatchmaking(
        gameType: widget.gameType,
        betAmount: betAmount,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partie créée ! En attente de joueurs...'),
            backgroundColor: NeonColors.success,
          ),
        );
        
        // Écouter le match
        gameWs.onGameMatched = (payload) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProviderScope(
                  child: DiceGameScreen(
                    gameId: payload['game_id'] as String? ?? '',
                    betAmount: betAmount,
                  ),
                ),
              ),
            );
          }
        };
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: NeonColors.danger,
          ),
        );
      }
    }
  }

  void _joinRoom(GameRoom room) async {
    final gameWs = ref.read(gameWebSocketServiceProvider);
    
    // Connecter WebSocket si nécessaire
    if (!gameWs.isConnected && !gameWs.isFallbackMode) {
      await gameWs.connect();
    }
    
    try {
      gameWs.joinGame(room.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partie rejointe ! Mise: ${room.betAmount} jetons'),
            backgroundColor: NeonColors.primary,
          ),
        );
        
        // Naviger vers le jeu
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProviderScope(
              child: DiceGameScreen(
                gameId: room.id,
                betAmount: room.betAmount,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: NeonColors.danger,
          ),
        );
      }
    }
  }

  void _startAutoMatch() async {
    final gameWs = ref.read(gameWebSocketServiceProvider);
    final betAmount = ref.read(betAmountProvider);
    
    // Connecter WebSocket si nécessaire
    if (!gameWs.isConnected && !gameWs.isFallbackMode) {
      await gameWs.connect();
    }
    
    ref.read(isSearchingProvider.notifier).state = true;
    
    try {
      await gameWs.joinMatchmaking(
        gameType: widget.gameType,
        betAmount: betAmount,
      );
      
      // Écouter le match
      gameWs.onGameMatched = (payload) {
        if (mounted) {
          ref.read(isSearchingProvider.notifier).state = false;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ProviderScope(
                child: DiceGameScreen(
                  gameId: payload['game_id'] as String? ?? '',
                  betAmount: betAmount,
                ),
              ),
            ),
          );
        }
      };
    } catch (e) {
      if (mounted) {
        ref.read(isSearchingProvider.notifier).state = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur matchmaking: $e'),
            backgroundColor: NeonColors.danger,
          ),
        );
      }
    }
  }

  void _cancelSearch() {
    _searchTimer?.cancel();
    ref.read(isSearchingProvider.notifier).state = false;
    final gameWs = ref.read(gameWebSocketServiceProvider);
    gameWs.leaveMatchmaking();
  }

  String _formatTokens(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ',);
  }
}

// === Widgets ===

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? NeonColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? NeonColors.primary : NeonColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: NeonColors.primary
                          .withValues(alpha: NeonGlow.opacityLow),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final GameRoom room;
  final VoidCallback onJoin;

  const _RoomCard({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonCard(
        onTap: onJoin,
        child: Row(
          children: [
            // Game icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: NeonColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.casino, color: NeonColors.primary),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.creatorName,
                    style: AppTypography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          color: NeonColors.primary, size: 14,),
                      const SizedBox(width: 4),
                      Text(
                        '${room.betAmount} jetons',
                        style: const TextStyle(
                          color: NeonColors.primary,
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.people,
                          color: NeonColors.textSecondary, size: 14,),
                      const SizedBox(width: 4),
                      Text(
                        '${room.currentPlayers}/${room.maxPlayers}',
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Join button
            NeonButton(
              text: 'REJOINDRE',
              onPressed: onJoin,
              variant: NeonButtonVariant.success,
              height: 40,
              fontSize: 11,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: NeonColors.primary,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

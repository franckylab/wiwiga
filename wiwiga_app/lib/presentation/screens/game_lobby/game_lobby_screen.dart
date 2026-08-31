import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../dice_game/dice_game_screen.dart';

// === Providers ===

enum MatchmakingMode { create, join, autoMatch }

final matchmakingModeProvider =
    StateProvider<MatchmakingMode>((ref) => MatchmakingMode.autoMatch);

final betAmountProvider = StateProvider<int>((ref) => 500);

final maxPlayersProvider = StateProvider<int>((ref) => 2);

final isSearchingProvider = StateProvider<bool>((ref) => false);

/// Config de jeu dynamique depuis les règles admin
final lobbyRulesConfigProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, gameType) async {
    final rulesAsync = ref.watch(gameRulesProvider(gameType));
    return rulesAsync.when(
      data: (rules) {
        if (rules.isEmpty) return _defaultLobbyConfig();
        final rule = rules.firstWhere(
          (r) => r.ruleType == 'normal',
          orElse: () => rules.first,
        );
        return {
          'min_bet': (rule.config['min_bet'] as num?)?.toInt() ?? 100,
          'max_bet': (rule.config['max_bet'] as num?)?.toInt() ?? 5000,
          'min_players': (rule.config['min_players'] as num?)?.toInt() ?? 2,
          'max_players': (rule.config['max_players'] as num?)?.toInt() ?? 5,
          'default_dice': (rule.config['default_dice'] as num?)?.toInt() ?? 2,
          'commission_rate': (rule.config['commission_rate'] as num?)?.toDouble() ?? 0.05,
        };
      },
      loading: () => _defaultLobbyConfig(),
      error: (_, __) => _defaultLobbyConfig(),
    );
  },
);

Map<String, dynamic> _defaultLobbyConfig() => {
  'min_bet': 1, 'max_bet': 5000,
  'min_players': 2, 'max_players': 5,
  'default_dice': 2, 'commission_rate': 0.05,
};

/// Génère les presets de mise basés sur la config admin
List<int> _generateBetPresets(int minBet, int maxBet) {
  final presets = <int>[];
  final steps = [100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000];
  for (final step in steps) {
    if (step >= minBet && step <= maxBet) presets.add(step);
  }
  if (presets.isEmpty) presets.addAll([minBet, maxBet]);
  return presets.take(6).toList();
}

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
    final rulesConfig = ref.watch(lobbyRulesConfigProvider(widget.gameType));

    final cfg = rulesConfig.when(
      data: (c) => c,
      loading: () => _defaultLobbyConfig(),
      error: (_, __) => _defaultLobbyConfig(),
    );

    final minBet = cfg['min_bet'] as int;
    final maxBet = cfg['max_bet'] as int;
    final minPlayers = cfg['min_players'] as int;
    final maxPlayersCfg = cfg['max_players'] as int;
    final betPresets = _generateBetPresets(minBet, maxBet);
    final playerOptions = List.generate(
      maxPlayersCfg - minPlayers + 1,
      (i) => minPlayers + i,
    );

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
                    TokenCoin(size: 18, metal: TokenMetal.emerald, lod: TokenLod.bevel),
                    const SizedBox(width: 8),
                    Text('MISE PAR JOUEUR', style: AppTypography.subtitle),
                    const Spacer(),
                    Text(
                      'min $minBet',
                      style: const TextStyle(
                        color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Presets dynamiques depuis config admin
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: betPresets.map((amount) {
                    final isSelected = betAmount == amount;
                    return GestureDetector(
                      onTap: () => ref.read(betAmountProvider.notifier).state = amount,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? NeonColors.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? NeonColors.primary : NeonColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: NeonColors.primary.withValues(alpha: NeonGlow.opacityLow),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '${_formatTokens(amount)} wiga',
                          style: TextStyle(
                            color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                            fontFamily: 'Orbitron',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                    if (amount != null && amount >= minBet && amount <= maxBet) {
                      ref.read(betAmountProvider.notifier).state = amount;
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Nombre de joueurs (dynamique depuis config)
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
                Text(
                  'Minimum $minPlayers joueurs pour démarrer',
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: playerOptions.map((playerNum) {
                    final isSelected = maxPlayers == playerNum;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(maxPlayersProvider.notifier).state = playerNum,
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
                            '$playerNum',
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
                    label: 'Mise', value: '${_formatTokens(betAmount)} wiga',),
                _SummaryRow(
                    label: 'Joueurs max', value: '$maxPlayers',),
                _SummaryRow(
                    label: 'Min. pour démarrer', value: '$minPlayers',),
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
    final roomsAsync = ref.watch(waitingRoomsProvider(widget.gameType));

    return roomsAsync.when(
      data: (rooms) => _buildJoinContent(rooms),
      loading: () => const Center(
        child: CircularProgressIndicator(color: NeonColors.primary),
      ),
      error: (e, _) => WiwigaErrorView(error: e, onRetry: () => ref.invalidate(waitingRoomsProvider(widget.gameType))),
    );
  }

  Widget _buildJoinContent(List<GameRoomModel> rooms) {
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
              : RefreshIndicator(
                  color: NeonColors.primary,
                  onRefresh: () async => ref.invalidate(waitingRoomsProvider(widget.gameType)),
                  child: ListView.builder(
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
        ),
      ],
    );
  }

  // === AUTO MATCH VIEW ===

  Widget _buildAutoMatchView() {
    final betAmount = ref.watch(betAmountProvider);
    final rulesConfig = ref.watch(lobbyRulesConfigProvider(widget.gameType));

    final cfg = rulesConfig.when(
      data: (c) => c,
      loading: () => _defaultLobbyConfig(),
      error: (_, __) => _defaultLobbyConfig(),
    );

    final minBet = cfg['min_bet'] as int;
    final maxBet = cfg['max_bet'] as int;
    final betPresets = _generateBetPresets(minBet, maxBet);

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

          // Mise (presets dynamiques)
          NeonCard(
            child: Column(
              children: [
                Text('VOTRE MISE', style: AppTypography.subtitle),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: betPresets.map((amount) {
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
            'Mise: ${_formatTokens(ref.watch(betAmountProvider))} wiga',
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
    
    // Connecter WebSocket si nécessaire
    if (!gameWs.isConnected && !gameWs.isFallbackMode) {
      await gameWs.connect();
    }
    
    try {
      await gameWs.joinMatchmaking(
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
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'GameLobby');
      if (mounted) {
        WiwigaSnack.showError(context, e);
      }
    }
  }

  void _joinRoom(GameRoomModel room) async {
    final gameWs = ref.read(gameWebSocketServiceProvider);
    
    // Connecter WebSocket si nécessaire
    if (!gameWs.isConnected && !gameWs.isFallbackMode) {
      await gameWs.connect();
    }
    
    try {
      gameWs.joinGame(room.roomId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partie rejointe ! Mise: ${room.betAmount} wiga'),
            backgroundColor: NeonColors.primary,
          ),
        );
        
        // Naviger vers le jeu
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProviderScope(
              child: DiceGameScreen(
                gameId: room.roomId,
                betAmount: room.betAmount,
              ),
            ),
          ),
        );
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'GameLobby');
      if (mounted) {
        WiwigaSnack.showError(context, e);
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
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'GameLobby');
      if (mounted) {
        ref.read(isSearchingProvider.notifier).state = false;
        WiwigaSnack.showError(context, e);
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
  final GameRoomModel room;
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
                    room.creatorId.isNotEmpty ? 'Salle ${room.roomCode}' : 'Salle ${room.roomCode}',
                    style: AppTypography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (room.isStaked) ...[
                        TokenCoin(size: 14, metal: TokenMetal.emerald, lod: TokenLod.flat, showShadow: false),
                        const SizedBox(width: 4),
                        Text(
                          '${room.betAmount} wiga',
                          style: const TextStyle(
                            color: NeonColors.primary,
                            fontFamily: 'Orbitron',
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.people_outline, color: NeonColors.success, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          room.modeShortLabel,
                          style: const TextStyle(
                            color: NeonColors.success,
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      const Icon(Icons.people,
                          color: NeonColors.textSecondary, size: 14,),
                      const SizedBox(width: 4),
                      Text(
                        '${room.playersCount}/${room.maxPlayers}',
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (room.setsCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${room.setsCount} sets',
                          style: const TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/services/game_websocket_service.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Game State ===

enum DiceGamePhase {
  waitingPlayers,   // En attente d'adversaires
  betting,          // Phase de prédiction
  rolling,          // Dés en cours de lancement
  showingResult,    // Résultat affiché
  finished,         // Partie terminée
}

class DiceGameState {
  final String gameId;
  final DiceGamePhase phase;
  final int? myPrediction;
  final int? opponentPrediction;
  final List<int> diceResults;
  final int? totalSum;
  final int betAmount;
  final String? opponentName;
  final String? winnerId;
  final int? netWinnings;

  DiceGameState({
    this.gameId = '',
    this.phase = DiceGamePhase.waitingPlayers,
    this.myPrediction,
    this.opponentPrediction,
    this.diceResults = const [],
    this.totalSum,
    this.betAmount = 0,
    this.opponentName,
    this.winnerId,
    this.netWinnings,
  });

  DiceGameState copyWith({
    String? gameId,
    DiceGamePhase? phase,
    int? myPrediction,
    int? opponentPrediction,
    List<int>? diceResults,
    int? totalSum,
    int? betAmount,
    String? opponentName,
    String? winnerId,
    int? netWinnings,
  }) {
    return DiceGameState(
      gameId: gameId ?? this.gameId,
      phase: phase ?? this.phase,
      myPrediction: myPrediction ?? this.myPrediction,
      opponentPrediction: opponentPrediction ?? this.opponentPrediction,
      diceResults: diceResults ?? this.diceResults,
      totalSum: totalSum ?? this.totalSum,
      betAmount: betAmount ?? this.betAmount,
      opponentName: opponentName ?? this.opponentName,
      winnerId: winnerId ?? this.winnerId,
      netWinnings: netWinnings ?? this.netWinnings,
    );
  }
}

final diceGameStateProvider =
    StateProvider<DiceGameState>((ref) => DiceGameState());

// === Écran principal ===

class DiceGameScreen extends ConsumerStatefulWidget {
  final String? gameId;
  final int betAmount;

  const DiceGameScreen({
    super.key,
    this.gameId,
    this.betAmount = 500,
  });

  @override
  ConsumerState<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends ConsumerState<DiceGameScreen>
    with TickerProviderStateMixin {
  late AnimationController _diceAnimController;
  late AnimationController _resultController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _diceAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    // Rejoindre la partie via WebSocket
    _initGameConnection();
  }
  
  void _initGameConnection() {
    final gameWs = ref.read(gameWebSocketServiceProvider);
    
    if ((widget.gameId ?? '').isNotEmpty) {
      gameWs.joinGame(widget.gameId!);
    }
    
    // Écouter les événements
    gameWs.onPlayerJoined = (payload) {
      if (mounted) {
        final state = ref.read(diceGameStateProvider);
        ref.read(diceGameStateProvider.notifier).state = state.copyWith(
          phase: DiceGamePhase.betting,
          opponentName: payload['player_name'] as String?,
        );
      }
    };
    
    gameWs.onBetPlaced = (payload) {
      if (mounted) {
        final state = ref.read(diceGameStateProvider);
        ref.read(diceGameStateProvider.notifier).state = state.copyWith(
          opponentPrediction: payload['predicted_sum'] as int?,
        );
      }
    };
    
    gameWs.onTurnExecuted = (payload) {
      if (mounted) {
        _showRollResult(payload);
      }
    };
    
    gameWs.onGameResult = (payload) {
      if (mounted) {
        _showGameResult(payload);
      }
    };
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    _resultController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(diceGameStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(gameState),
            Expanded(
              child: _buildPhaseContent(gameState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DiceGameState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeonColors.primary.withValues(alpha: 0.3),
            NeonColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/games/dice'),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.casino, color: NeonColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JEU DE DÉS',
                    style: AppTypography.heading4
                        .copyWith(color: Colors.white),),
                Text(
                  _phaseLabel(state.phase),
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          // Mise
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: NeonColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NeonColors.primary, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    color: NeonColors.primary, size: 16,),
                const SizedBox(width: 4),
                Text(
                  '${widget.betAmount} jetons',
                  style: const TextStyle(
                    color: NeonColors.primary,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(DiceGameState state) {
    switch (state.phase) {
      case DiceGamePhase.waitingPlayers:
        return _buildWaitingView();
      case DiceGamePhase.betting:
        return _buildBettingView(state);
      case DiceGamePhase.rolling:
        return _buildRollingView(state);
      case DiceGamePhase.showingResult:
        return _buildResultView(state);
      case DiceGamePhase.finished:
        return _buildFinishedView(state);
    }
  }

  // === WAITING FOR PLAYERS ===

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: NeonColors.primary.withValues(
                          alpha: NeonGlow.opacityLow + _glowController.value * 0.3,),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      NeonColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.people,
                      size: 50, color: NeonColors.primary,),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('EN ATTENTE DE JOUEURS...',
              style: AppTypography.heading3,),
          const SizedBox(height: 8),
          const Text(
            'La partie commence quand au moins 2 joueurs sont prêts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 32),
          // Player slots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _PlayerSlot(
                  filled: index == 0,
                  isYou: index == 0,
                  label: index == 0 ? 'Vous' : '?',
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // === BETTING (PREDICTION) ===

  Widget _buildBettingView(DiceGameState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Opponent info
          if (state.opponentName != null)
            NeonCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        NeonColors.secondary.withValues(alpha: 0.2),
                    child: const Icon(Icons.person,
                        color: NeonColors.secondary,),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Adversaire',
                          style: TextStyle(
                              color: NeonColors.textSecondary,
                              fontSize: 12,
                              fontFamily: 'Inter',),),
                      Text(state.opponentName!,
                          style: AppTypography.subtitle,),
                    ],
                  ),
                  const Spacer(),
                  const GlowBadge(
                    text: 'PRÊT',
                    color: NeonColors.success,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          Text('CHOISIS TA PRÉDICTION',
              style: AppTypography.heading3,),
          const SizedBox(height: 8),
          const Text(
            'Quelle sera la somme des 2 dés ?',
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 20),

          // Prediction grid (2-12)
          _PredictionGrid(
            selectedPrediction: state.myPrediction,
            onSelect: (sum) {
              ref.read(diceGameStateProvider.notifier).state =
                  state.copyWith(myPrediction: sum);
            },
          ),

          const SizedBox(height: 24),

          // Dice preview
          _DicePreview(
            prediction: state.myPrediction,
            animationController: _diceAnimController,
          ),

          const SizedBox(height: 24),

          // Confirm button
          NeonButton(
            text: state.myPrediction != null
                ? 'CONFIRMER : SOMME ${state.myPrediction}'
                : 'SÉLECTIONNE UNE PRÉDICTION',
            onPressed: state.myPrediction != null
                ? () => _confirmPrediction(state.myPrediction!)
                : () {},
            variant: NeonButtonVariant.primary,
            isEnabled: state.myPrediction != null,
            icon: Icons.check_circle,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  // === ROLLING ===

  Widget _buildRollingView(DiceGameState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('LANCEMENT DES DÉS...',
              style: AppTypography.heading3,),
          const SizedBox(height: 40),
          // Animated dice
          AnimatedBuilder(
            animation: _diceAnimController,
            builder: (context, child) {
              final random = Random();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DiceWidget(
                    value: _diceAnimController.isAnimating
                        ? random.nextInt(6) + 1
                        : (state.diceResults.isNotEmpty
                            ? state.diceResults[0]
                            : 1),
                    isAnimating: _diceAnimController.isAnimating,
                    size: 80,
                  ),
                  const SizedBox(width: 24),
                  _DiceWidget(
                    value: _diceAnimController.isAnimating
                        ? random.nextInt(6) + 1
                        : (state.diceResults.length > 1
                            ? state.diceResults[1]
                            : 1),
                    isAnimating: _diceAnimController.isAnimating,
                    size: 80,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          if (state.totalSum != null) ...[
            Text(
              'SUM = ${state.totalSum}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: NeonColors.primary,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // === RESULT ===

  Widget _buildResultView(DiceGameState state) {
    final isWinner = state.winnerId == 'me';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Result icon
          AnimatedBuilder(
            animation: _resultController,
            builder: (context, child) {
              return ScaleTransition(
                scale: Tween(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _resultController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isWinner
                                ? NeonColors.success
                                : NeonColors.danger)
                            .withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: (isWinner
                            ? NeonColors.success
                            : NeonColors.danger)
                        .withValues(alpha: 0.2),
                    child: Icon(
                      isWinner ? Icons.emoji_events : Icons.close,
                      size: 60,
                      color: isWinner
                          ? NeonColors.success
                          : NeonColors.danger,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            isWinner ? 'VICTOIRE !' : 'DÉFAITE',
            style: AppTypography.heading2.copyWith(
              color: isWinner ? NeonColors.success : NeonColors.danger,
            ),
          ),
          const SizedBox(height: 16),

          // Dice results
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: state.diceResults.map((value) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _DiceWidget(value: value, size: 60),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Somme: ${state.totalSum}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NeonColors.primary,
              fontFamily: 'Orbitron',
            ),
          ),

          const SizedBox(height: 20),

          // Predictions comparison
          NeonCard(
            child: Column(
              children: [
                _PredictionRow(
                  label: 'Vous',
                  prediction: state.myPrediction,
                  isWinner: isWinner,
                  isCorrect: state.myPrediction == state.totalSum,
                ),
                const Divider(color: NeonColors.border, height: 24),
                _PredictionRow(
                  label: state.opponentName ?? 'Adversaire',
                  prediction: state.opponentPrediction,
                  isWinner: !isWinner,
                  isCorrect:
                      state.opponentPrediction == state.totalSum,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Winnings
          if (isWinner && state.netWinnings != null)
            NeonCard(
              child: Column(
                children: [
                  const Icon(Icons.monetization_on,
                      color: NeonColors.success, size: 32,),
                  const SizedBox(height: 8),
                  Text(
                    '+${state.netWinnings} jetons',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.success,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gains nets crédités',
                    style: TextStyle(
                      color: NeonColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'REJOUER',
                  onPressed: _playAgain,
                  variant: NeonButtonVariant.primary,
                  icon: Icons.refresh,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonButton(
                  text: 'LOBBY',
                  onPressed: () => context.go('/games/dice/lobby'),
                  variant: NeonButtonVariant.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === FINISHED ===

  Widget _buildFinishedView(DiceGameState state) {
    return _buildResultView(state);
  }

  // === Actions ===

  void _confirmPrediction(int prediction) async {
    final state = ref.read(diceGameStateProvider);
    final gameWs = ref.read(gameWebSocketServiceProvider);
    
    // Envoyer le pari au serveur
    try {
      await gameWs.placeBet(
        gameId: widget.gameId ?? '',
        betAmount: widget.betAmount,
        predictedSum: prediction,
      );
      
      // Mettre à jour l'état local
      ref.read(diceGameStateProvider.notifier).state =
          state.copyWith(myPrediction: prediction);
      
      // Si en mode fallback ou solo, simuler le résultat
      if (gameWs.isFallbackMode || (widget.gameId?.isEmpty ?? true)) {
        _simulateLocalGame(prediction);
      }
      // Sinon, attendre les événements WebSocket
    } catch (e) {
      // Fallback: simulation locale
      _simulateLocalGame(prediction);
    }
  }
  
  void _simulateLocalGame(int prediction) {
    final state = ref.read(diceGameStateProvider);
    ref.read(diceGameStateProvider.notifier).state =
        state.copyWith(phase: DiceGamePhase.rolling);
    
    _diceAnimController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      final random = Random();
      final dice1 = random.nextInt(6) + 1;
      final dice2 = random.nextInt(6) + 1;
      final sum = dice1 + dice2;
      final isWin = prediction == sum;
      
      ref.read(diceGameStateProvider.notifier).state =
          state.copyWith(
        phase: DiceGamePhase.showingResult,
        diceResults: [dice1, dice2],
        totalSum: sum,
        winnerId: isWin ? 'me' : 'opponent',
        netWinnings: isWin ? widget.betAmount * 2 - (widget.betAmount * 0.05).toInt() : 0,
        opponentPrediction: random.nextInt(11) + 2,
        opponentName: 'Adversaire',
      );
      
      _resultController.forward(from: 0);
    });
  }
  
  void _showRollResult(Map<String, dynamic> payload) {
    final state = ref.read(diceGameStateProvider);
    final diceResults = List<int>.from(payload['dice_results'] ?? []);
    final totalSum = payload['total_sum'] as int?;
    
    ref.read(diceGameStateProvider.notifier).state = state.copyWith(
      phase: DiceGamePhase.rolling,
      diceResults: diceResults,
      totalSum: totalSum,
    );
    
    _diceAnimController.forward(from: 0);
  }
  
  void _showGameResult(Map<String, dynamic> payload) {
    final state = ref.read(diceGameStateProvider);
    final isWin = payload['winner'] == 'me';
    
    ref.read(diceGameStateProvider.notifier).state = state.copyWith(
      phase: DiceGamePhase.showingResult,
      winnerId: isWin ? 'me' : 'opponent',
      netWinnings: payload['net_winnings'] as int? ?? 0,
    );
    
    _resultController.forward(from: 0);
  }

  void _playAgain() {
    ref.read(diceGameStateProvider.notifier).state = DiceGameState(
      betAmount: widget.betAmount,
      phase: DiceGamePhase.betting,
    );
  }

  String _phaseLabel(DiceGamePhase phase) {
    switch (phase) {
      case DiceGamePhase.waitingPlayers:
        return 'En attente';
      case DiceGamePhase.betting:
        return 'Phase de prédiction';
      case DiceGamePhase.rolling:
        return 'Lancement...';
      case DiceGamePhase.showingResult:
        return 'Résultat';
      case DiceGamePhase.finished:
        return 'Terminé';
    }
  }
}

// === Widgets ===

class _PlayerSlot extends StatelessWidget {
  final bool filled;
  final bool isYou;
  final String label;

  const _PlayerSlot({
    required this.filled,
    required this.isYou,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (isYou
                    ? NeonColors.primary.withValues(alpha: 0.2)
                    : NeonColors.secondary.withValues(alpha: 0.2))
                : Colors.transparent,
            border: Border.all(
              color: filled
                  ? (isYou ? NeonColors.primary : NeonColors.secondary)
                  : NeonColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              filled ? Icons.person : Icons.person_outline,
              color: filled
                  ? (isYou ? NeonColors.primary : NeonColors.secondary)
                  : NeonColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: filled ? NeonColors.primary : NeonColors.textSecondary,
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _PredictionGrid extends StatelessWidget {
  final int? selectedPrediction;
  final ValueChanged<int> onSelect;

  const _PredictionGrid({
    required this.selectedPrediction,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: 11, // 2 to 12
      itemBuilder: (context, index) {
        final sum = index + 2;
        final isSelected = selectedPrediction == sum;
        final probability = _getProbabilityLabel(sum);

        return GestureDetector(
          onTap: () => onSelect(sum),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? NeonColors.primary.withValues(alpha: 0.2)
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
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$sum',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? NeonColors.primary
                        : Colors.white,
                    fontFamily: 'Orbitron',
                  ),
                ),
                Text(
                  probability,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected
                        ? NeonColors.primary
                        : NeonColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getProbabilityLabel(int sum) {
    // Probability distribution for 2 dice
    final probs = {
      2: '2.8%', 3: '5.6%', 4: '8.3%', 5: '11.1%',
      6: '13.9%', 7: '16.7%', 8: '13.9%', 9: '11.1%',
      10: '8.3%', 11: '5.6%', 12: '2.8%',
    };
    return probs[sum] ?? '';
  }
}

class _DicePreview extends StatelessWidget {
  final int? prediction;
  final AnimationController animationController;

  const _DicePreview({
    required this.prediction,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DiceWidget(
          value: prediction ?? 1,
          size: 50,
          isGhost: prediction == null,
        ),
        const SizedBox(width: 12),
        const Text(
          '+',
          style: TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 24,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(width: 12),
        _DiceWidget(
          value: prediction ?? 1,
          size: 50,
          isGhost: prediction == null,
        ),
        const SizedBox(width: 16),
        if (prediction != null)
          const Text(
            '?',
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 24,
              fontFamily: 'Orbitron',
            ),
          ),
      ],
    );
  }
}

class _DiceWidget extends StatelessWidget {
  final int value;
  final bool isAnimating;
  final bool isGhost;
  final double size;

  const _DiceWidget({
    required this.value,
    this.isAnimating = false,
    this.isGhost = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: isAnimating ? 100 : 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isGhost
            ? Colors.transparent
            : NeonColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGhost ? NeonColors.border : NeonColors.primary,
          width: 2,
        ),
        boxShadow: isGhost
            ? null
            : [
                BoxShadow(
                  color: NeonColors.primary.withValues(alpha: NeonGlow.opacityLow),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Center(
        child: Text(
          isGhost ? '?' : '$value',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: isGhost
                ? NeonColors.textSecondary
                : NeonColors.primary,
            fontFamily: 'Orbitron',
          ),
        ),
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  final String label;
  final int? prediction;
  final bool isWinner;
  final bool isCorrect;

  const _PredictionRow({
    required this.label,
    required this.prediction,
    required this.isWinner,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: isWinner ? NeonColors.success : Colors.white,
          ),
        ),
        const Spacer(),
        if (prediction != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Prédiction: $prediction',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: isCorrect
                      ? NeonColors.success
                      : NeonColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? NeonColors.success : NeonColors.danger,
                size: 20,
              ),
            ],
          ),
        if (isWinner) ...[
          const SizedBox(width: 8),
          const Icon(Icons.emoji_events, color: NeonColors.success, size: 20),
        ],
      ],
    );
  }
}

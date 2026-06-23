// ============================================================
// Fichier: dice_game_screen.dart
// Description: Écran de jeu de dés avec animations et WebSocket temps réel
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/web_socket_provider.dart';
import '../../data/models/game_model.dart';
import '../widgets/responsive_button.dart';
import '../widgets/responsive_input.dart';

/// Écran de jeu de dés
class DiceGameScreen extends ConsumerStatefulWidget {
  const DiceGameScreen({super.key});
  
  @override
  ConsumerState<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends ConsumerState<DiceGameScreen>
    with SingleTickerProviderStateMixin {
  final _betController = TextEditingController();
  late AnimationController _diceAnimationController;
  
  int _currentDice = 1;
  int _opponentDice = 1;
  bool _isRolling = false;
  String? _gameResult;
  bool _isInGame = false;
  
  @override
  void initState() {
    super.initState();
    _diceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Connecte WebSocket
    Future.microtask(() {
      ref.read(Provider((ref) => WebSocketProvider())).connect();
    });
  }
  
  @override
  void dispose() {
    _betController.dispose();
    _diceAnimationController.dispose();
    super.dispose();
  }
  
  /// Rejoint une partie
  Future<void> _joinGame() async {
    final betAmount = double.tryParse(_betController.text);
    
    if (betAmount == null || betAmount <= 0) {
      _showError('Veuillez entrer une mise valide');
      return;
    }
    
    // Rejoint le matchmaking
    await ref.read(gameProvider.notifier).joinQueue('dice', betAmount);
    
    final error = ref.read(gameProvider).error;
    if (error == null) {
      setState(() => _isInGame = true);
      _showSuccess('En attente d\'un adversaire...');
    }
  }
  
  /// Lance les dés
  Future<void> _rollDice() async {
    if (_isRolling) return;
    
    setState(() {
      _isRolling = true;
      _gameResult = null;
    });
    
    // Animation du lancer
    _diceAnimationController.reset();
    _diceAnimationController.forward();
    
    // Simule le temps de jeu (à remplacer par WebSocket)
    await Future.delayed(const Duration(seconds: 2));
    
    // Génère les résultats (côté serveur en production)
    final random = Random.secure();
    final myDice = random.nextInt(6) + 1;
    final opponentDice = random.nextInt(6) + 1;
    
    setState(() {
      _currentDice = myDice;
      _opponentDice = opponentDice;
      _isRolling = false;
      
      // Détermine le résultat
      if (myDice > opponentDice) {
        _gameResult = 'win';
      } else if (myDice < opponentDice) {
        _gameResult = 'lose';
      } else {
        _gameResult = 'draw';
      }
    });
    
    // Envoie le résultat via WebSocket (à implémenter)
    _sendResultToServer(myDice, opponentDice);
  }
  
  /// Envoie le résultat au serveur via WebSocket
  void _sendResultToServer(int myDice, int opponentDice) {
    final wsProvider = ref.read(Provider((ref) => WebSocketProvider()));
    wsProvider.send(
      topic: 'game:room',
      event: 'dice_roll',
      payload: {
        'my_dice': myDice,
        'opponent_dice': opponentDice,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Quitte la partie
  void _leaveGame() {
    setState(() {
      _isInGame = false;
      _gameResult = null;
      _currentDice = 1;
      _opponentDice = 1;
    });
    
    _showInfo('Vous avez quitté la partie');
  }
  
  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
  
  /// Affiche un message de succès
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
  
  /// Affiche un message d'information
  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    
    return ResponsiveBuilder(
      builder: (context, config) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Jeu de Dés',
              style: TextStyle(fontSize: config.fontSizeLarge),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _isInGame ? null : () => Navigator.pop(context),
            ),
            actions: [
              // Affichage du solde
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: config.spacing,
                  vertical: config.spacingSmall,
                ),
                margin: EdgeInsets.only(right: config.spacing),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(config.borderRadius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 20),
                    SizedBox(width: config.spacingSmall),
                    Text(
                      '${walletState.balance.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: config.fontSizeSmall,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: _isInGame
                ? _buildGameView(config)
                : _buildLobbyView(config),
          ),
        );
      },
    );
  }
  
  /// Construit la vue de matchmaking (avant la partie)
  Widget _buildLobbyView(ResponsiveConfig config) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(config.padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône de dés
            Icon(
              Icons.casino,
              size: config.iconSize * 6,
              color: AppTheme.primaryColor,
            ).animate().shake(),
            
            SizedBox(height: config.spacingLarge),
            
            // Titre
            Text(
              'Jeu de Dés',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: config.fontSizeLarge * 1.2,
                  ),
            ),
            
            SizedBox(height: config.spacing),
            
            Text(
              'Affrontez un adversaire et tentez de gagner !',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: config.fontSize,
                  ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: config.spacingLarge * 2),
            
            // Champ de mise
            ResponsiveInput(
              controller: _betController,
              label: 'Votre mise (FCFA)',
              hint: '1000',
              icon: Icons.monetization_on,
              keyboardType: TextInputType.number,
            ),
            
            SizedBox(height: config.spacingLarge),
            
            // Bouton rejoindre
            ResponsiveButton(
              onPressed: _joinGame,
              height: config.buttonHeight * 1.2,
              child: Text(
                'Rechercher un adversaire',
                style: TextStyle(
                  fontSize: config.fontSizeLarge * 0.9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Construit la vue de jeu (pendant la partie)
  Widget _buildGameView(ResponsiveConfig config) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(config.padding),
      child: Column(
        children: [
          // Zone de jeu
          _buildGameArena(config),
          
          SizedBox(height: config.spacingLarge),
          
          // Résultat
          if (_gameResult != null)
            _buildResultDisplay(config)
          else if (!_isRolling)
            // Bouton lancer
            ResponsiveButton(
              onPressed: _rollDice,
              height: config.buttonHeight * 1.3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.casino, size: config.iconSize * 1.5),
                  SizedBox(width: config.spacing),
                  Text(
                    'Lancer les dés !',
                    style: TextStyle(
                      fontSize: config.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          SizedBox(height: config.spacing),
          
          // Bouton quitter
          if (!_isRolling)
            ResponsiveButton(
              onPressed: _leaveGame,
              backgroundColor: AppTheme.secondaryColor,
              height: config.buttonHeight,
              child: Text(
                'Quitter la partie',
                style: TextStyle(
                  fontSize: config.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Construit l'arène de jeu
  Widget _buildGameArena(ResponsiveConfig config) {
    return Container(
      padding: EdgeInsets.all(config.cardPadding * 1.5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(config.borderRadius),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Dés du joueur
          Text(
            'Votre dé',
            style: TextStyle(
              fontSize: config.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: config.spacing),
          _buildDice(config, _currentDice, isPlayer: true),
          
          SizedBox(height: config.spacingLarge * 2),
          
          // VS
          Text(
            'VS',
            style: TextStyle(
              fontSize: config.fontSizeLarge * 1.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryColor,
            ),
          ),
          
          SizedBox(height: config.spacingLarge * 2),
          
          // Dés de l'adversaire
          _buildDice(config, _opponentDice, isPlayer: false),
          SizedBox(height: config.spacing),
          Text(
            'Dé adversaire',
            style: TextStyle(
              fontSize: config.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit un dé
  Widget _buildDice(
    ResponsiveConfig config,
    int value, {
    required bool isPlayer,
  }) {
    final diceSize = config.iconSize * 5;
    
    return AnimatedBuilder(
      animation: _diceAnimationController,
      builder: (context, child) {
        final scale = _isRolling
            ? 1.0 + 0.2 * sin(_diceAnimationController.value * 3.14159 * 4)
            : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: diceSize,
            height: diceSize,
            decoration: BoxDecoration(
              color: isPlayer ? AppTheme.primaryColor : AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(config.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: (isPlayer ? AppTheme.primaryColor : AppTheme.secondaryColor)
                      .withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getDiceEmoji(value),
                fontSize: diceSize * 0.6,
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// Construit l'affichage du résultat
  Widget _buildResultDisplay(ResponsiveConfig config) {
    Color resultColor;
    String resultText;
    IconData resultIcon;
    
    switch (_gameResult) {
      case 'win':
        resultColor = AppTheme.successColor;
        resultText = 'Victoire !';
        resultIcon = Icons.emoji_events;
        break;
      case 'lose':
        resultColor = AppTheme.errorColor;
        resultText = 'Défaite';
        resultIcon = Icons.sentiment_dissatisfied;
        break;
      default:
        resultColor = AppTheme.warningColor;
        resultText = 'Match nul';
        resultIcon = Icons.handshake;
    }
    
    return Container(
      padding: EdgeInsets.all(config.cardPadding),
      decoration: BoxDecoration(
        color: resultColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(config.borderRadius),
        border: Border.all(color: resultColor, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            resultIcon,
            size: config.iconSize * 3,
            color: resultColor,
          ).animate().scale(),
          SizedBox(height: config.spacing),
          Text(
            resultText,
            style: TextStyle(
              fontSize: config.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: resultColor,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Retourne l'emoji du dé
  String _getDiceEmoji(int value) {
    switch (value) {
      case 1:
        return '⚀';
      case 2:
        return '⚁';
      case 3:
        return '⚂';
      case 4:
        return '⚃';
      case 5:
        return '⚄';
      case 6:
        return '⚅';
      default:
        return '⚀';
    }
  }
}

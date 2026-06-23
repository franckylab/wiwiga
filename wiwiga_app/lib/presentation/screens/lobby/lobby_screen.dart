// ============================================================
// Fichier: lobby_screen.dart
// Description: Écran principal avec liste des jeux et navigation
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../data/models/game_model.dart';
import '../widgets/responsive_button.dart';

/// Écran principal (Lobby) avec liste des jeux
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});
  
  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(gameProvider.notifier).loadGames();
      ref.read(walletProvider.notifier).loadBalance();
    });
  }
  
  /// Navigation vers le jeu de dés
  void _navigateToDiceGame(GameModel game) {
    // TODO: Navigation vers DiceGameScreen
    Navigator.pushNamed(
      context,
      '/dice-game',
      arguments: game,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final walletState = ref.watch(walletProvider);
    
    return ResponsiveBuilder(
      builder: (context, config) {
        return Scaffold(
          body: _currentIndex == 0
              ? _buildGamesView(config, gameState)
              : _buildWalletView(config, walletState),
          bottomNavigationBar: _buildBottomNav(config),
        );
      },
    );
  }
  
  /// Construit la vue des jeux
  Widget _buildGamesView(ResponsiveConfig config, dynamic gameState) {
    return SafeArea(
      child: Column(
        children: [
          // En-tête
          _buildHeader(config),
          
          // Contenu principal
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(gameProvider.notifier).loadGames();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(config.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      'Jeux disponibles',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: config.fontSizeLarge,
                          ),
                    ).animate().fadeIn(),
                    
                    SizedBox(height: config.spacing),
                    
                    // Liste des jeux
                    if (gameState.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (gameState.games.isEmpty)
                      _buildEmptyGames(config)
                    else
                      _buildGameGrid(config, gameState.games),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit la vue portefeuille (simplifiée)
  Widget _buildWalletView(ResponsiveConfig config, dynamic walletState) {
    return SafeArea(
      child: Column(
        children: [
          // En-tête
          _buildHeader(config),
          
          // Contenu portefeuille
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(config.padding),
              child: Column(
                children: [
                  // Carte de solde
                  _buildBalanceCard(config, walletState.balance),
                  
                  SizedBox(height: config.spacingLarge),
                  
                  // Historique simplifié
                  Text(
                    'Dernières transactions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: config.fontSizeLarge * 0.8,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit l'en-tête
  Widget _buildHeader(ResponsiveConfig config) {
    final authState = ref.watch(authProvider);
    
    return Container(
      padding: EdgeInsets.all(config.padding),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: config.iconSize * 2,
                height: config.iconSize * 2,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(config.borderRadius * 0.5),
                ),
                child: Icon(
                  Icons.casino,
                  size: config.iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: config.spacingSmall),
              Text(
                'WIWIGA',
                style: TextStyle(
                  fontSize: config.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Bouton déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
  
  /// Construit la carte de solde (version simplifiée)
  Widget _buildBalanceCard(ResponsiveConfig config, double balance) {
    return Container(
      padding: EdgeInsets.all(config.cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solde',
            style: TextStyle(
              fontSize: config.fontSize,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: config.spacingSmall),
          Text(
            '${balance.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              fontSize: config.fontSizeLarge * 1.3,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit la grille de jeux
  Widget _buildGameGrid(ResponsiveConfig config, List<GameModel> games) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: config.isDesktop ? 4 : (config.isTablet ? 3 : 2),
        crossAxisSpacing: config.spacing,
        mainAxisSpacing: config.spacing,
        childAspectRatio: 0.85,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _buildGameCard(config, game)
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 100))
            .slideY(begin: 0.2, end: 0);
      },
    );
  }
  
  /// Construit une carte de jeu
  Widget _buildGameCard(ResponsiveConfig config, GameModel game) {
    return GestureDetector(
      onTap: () => _navigateToDiceGame(game),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(config.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image/Icone du jeu
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(config.borderRadius),
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getGameIcon(game.type),
                    size: config.iconSize * 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Détails du jeu
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(config.cardPadding * 0.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      game.name,
                      style: TextStyle(
                        fontSize: config.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: config.spacingSmall * 0.5),
                    Text(
                      'Mise: ${game.minBet.toStringAsFixed(0)} - ${game.maxBet.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: config.fontSizeSmall * 0.85,
                        color: Colors.white60,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Construit le message d'absence de jeux
  Widget _buildEmptyGames(ResponsiveConfig config) {
    return Container(
      padding: EdgeInsets.all(config.padding * 2),
      child: Column(
        children: [
          Icon(
            Icons.games_outlined,
            size: config.iconSize * 3,
            color: Colors.white38,
          ),
          SizedBox(height: config.spacing),
          Text(
            'Aucun jeu disponible pour le moment',
            style: TextStyle(
              fontSize: config.fontSize,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  /// Construit la navigation inférieure
  Widget _buildBottomNav(ResponsiveConfig config) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.white38,
      iconSize: config.iconSize,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Jeux',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Portefeuille',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
  
  /// Retourne l'icône selon le type de jeu
  IconData _getGameIcon(String type) {
    switch (type) {
      case 'dice':
        return Icons.casino;
      default:
        return Icons.games;
    }
  }
}

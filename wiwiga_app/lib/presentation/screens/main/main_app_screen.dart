import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/navigation/responsive_navigation.dart';
import '../lobby/lobby_screen_neon.dart';
import '../wallet/wallet_screen_neon.dart';
import '../profile/profile_screen_enhanced.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../settings/settings_screen.dart';
import '../transaction_history/transaction_history_screen.dart';
import '../friends/friends_screen.dart';
import '../game_lobby/game_lobby_enhanced_screen.dart';

/// Écran principal de l'application avec navigation responsive
/// 
/// Mobile (< 600px) : Bottom Navigation Bar
/// Tablet (600-1024px) : Navigation Rail  
/// Desktop (> 1024px) : Sidebar Navigation
class MainAppScreen extends ConsumerStatefulWidget {
  const MainAppScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends ConsumerState<MainAppScreen> {
  int _currentIndex = 0;

  final List<NavDestination> _destinations = const [
    NavDestination(
      icon: Icons.home_outlined,
      label: 'Accueil',
    ),
    NavDestination(
      icon: Icons.gamepad_outlined,
      label: 'Jeux',
    ),
    NavDestination(
      icon: Icons.people_outline,
      label: 'Amis',
    ),
    NavDestination(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Portefeuille',
    ),
    NavDestination(
      icon: Icons.emoji_events_outlined,
      label: 'Classement',
    ),
    NavDestination(
      icon: Icons.person_outline,
      label: 'Profil',
    ),
  ];

  Widget get _currentScreen {
    switch (_currentIndex) {
      case 0:
        return const GameLobbyEnhancedScreen();
      case 1:
        return const GameLobbyEnhancedScreen();
      case 2:
        return const FriendsScreen();
      case 3:
        return const WalletScreenNeon();
      case 4:
        return const LeaderboardScreen();
      case 5:
        return const ProfileScreenEnhanced();
      default:
        return const LobbyScreenNeon();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavigation(
      currentIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      destinations: _destinations,
      body: _currentScreen,
      appBarTitle: 'WIWIGA',
      appBarActions: [
        IconButton(
          icon: Icon(Icons.receipt_long_outlined, color: NeonColors.primary),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const TransactionHistoryScreen(),
            ));
          },
        ),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: NeonColors.primary),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            ));
          },
        ),
      ],
    );
  }
}

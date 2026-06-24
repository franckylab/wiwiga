import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/navigation/responsive_navigation.dart';
import '../lobby/lobby_screen_neon.dart';
import '../wallet/wallet_screen_neon.dart';
import '../profile/profile_screen_neon.dart';

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
        return const LobbyScreenNeon();
      case 1:
        return const LobbyScreenNeon(); // TODO: Games screen
      case 2:
        return const WalletScreenNeon();
      case 3:
        return const LobbyScreenNeon(); // TODO: Leaderboard screen
      case 4:
        return const ProfileScreenNeon();
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
          icon: Icon(Icons.notifications_outlined, color: NeonColors.primary),
          onPressed: () {
            // TODO: Navigation vers notifications
          },
        ),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: NeonColors.primary),
          onPressed: () {
            // TODO: Navigation vers paramètres
          },
        ),
      ],
    );
  }
}

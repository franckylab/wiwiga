// ============================================================
// Fichier: main_shell_screen.dart
// Description: Shell go_router à 5 onglets avec navigation responsive
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/navigation/responsive_navigation.dart';

/// Shell principal : 5 onglets (Accueil, Jeux, Amis, Jetons, Classement)
///
/// Mobile (< 600px) : Bottom Navigation Bar
/// Tablet (600-1024px) : Navigation Rail
/// Desktop (> 1024px) : Sidebar Navigation
class MainShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  static const List<NavDestination> _destinations = [
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
      icon: Icons.monetization_on,
      label: 'Jetons',
    ),
    NavDestination(
      icon: Icons.emoji_events_outlined,
      label: 'Classement',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveNavigation(
      currentIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: _destinations,
      body: navigationShell,
      appBarTitle: 'WIWIGA',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.receipt_long_outlined, color: NeonColors.primary),
          tooltip: 'Historique des transactions',
          onPressed: () => context.push('/transactions'),
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, color: NeonColors.primary),
          tooltip: 'Profil',
          onPressed: () => context.push('/profile'),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: NeonColors.primary),
          tooltip: 'Paramètres',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

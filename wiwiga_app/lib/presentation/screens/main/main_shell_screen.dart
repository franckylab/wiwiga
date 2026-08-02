// ============================================================
// Fichier: main_shell_screen.dart
// Description: Shell go_router à 5 onglets avec navigation responsive
//              et gestion du mode guest (actions conditionnelles)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
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
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuest || authState.isUnknown;

    return ResponsiveNavigation(
      currentIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: _destinations,
      body: navigationShell,
      appBarTitle: 'WIWIGA',
      appBarActions: isGuest
          ? [
              // Mode guest : bouton de connexion
              TextButton.icon(
                icon: const Icon(Icons.login, color: NeonColors.primary, size: 18),
                label: const Text(
                  'Connexion',
                  style: TextStyle(
                    color: NeonColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
                onPressed: () {
                  ref.read(authProvider.notifier).setRedirectTo('/home');
                  context.go('/auth');
                },
              ),
            ]
          : [
              // Bouton Admin (visible uniquement pour admins)
              if (authState.isAdmin)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFFF6600)),
                  tooltip: 'Administration',
                  onPressed: () => context.go('/admin'),
                ),
              // Mode authentifié : actions complètes
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

// ============================================================
// Fichier: main_shell_screen.dart
// Description: Shell go_router à 4 onglets avec navigation responsive
//              et gestion du mode guest (actions conditionnelles)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../../data/providers/friend_provider.dart';
import '../../widgets/navigation/responsive_navigation.dart';

/// Shell principal : 4 onglets (Accueil, Jeux, Amis, Classement)
///
/// Mobile (< 600px) : Bottom Navigation Bar
/// Tablet (600-1024px) : Navigation Rail
/// Desktop (> 1024px) : Sidebar Navigation
/// Gère le refresh global au retour premier plan et au changement d'onglet (cohérence + perf)
class MainShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVisibleProviders();
    }
  }

  void _refreshVisibleProviders() {
    // Rafraîchit uniquement les providers visibles / critiques, pas tout en même temps (éco batterie)
    // Invalide sans attendre la fin, laisse Riverpod re-fetch en arrière-plan
    ref.invalidate(gamesCatalogProvider);
    ref.invalidate(activeGameProvider);
    // Le reste sera re-fetch via timers autoDispose quand l'onglet redevient visible
  }

  void _onBranchChanged(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    // Rafraîchit les données de l'onglet cible au switch (cohérence immédiate)
    Future.microtask(() {
      switch (index) {
        case 0: // Accueil
          ref.invalidate(gamesCatalogProvider);
          break;
        case 1: // Jeux
          ref.invalidate(gamesCatalogProvider);
          ref.invalidate(activeGameProvider);
          break;
        case 2: // Amis
          ref.invalidate(friendsProvider);
          ref.invalidate(pendingRequestsProvider);
          break;
        case 3: // Classement
          // Invalide le leaderboard par défaut (le family sera re-créé au build)
          break;
      }
    });
  }

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
      icon: Icons.emoji_events_outlined,
      label: 'Classement',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuest || authState.isUnknown;

    return ResponsiveNavigation(
      currentIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: _onBranchChanged,
      destinations: _destinations,
      body: widget.navigationShell,
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

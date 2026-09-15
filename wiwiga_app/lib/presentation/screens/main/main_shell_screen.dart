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
import '../../../core/router/app_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../../data/providers/friend_provider.dart';
import '../../../data/providers/notification_provider.dart';
import '../../widgets/navigation/responsive_navigation.dart';
import '../../widgets/notifications/in_app_notification_banner.dart';

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
    // Temps réel inbox : toute notification_created rafraîchit badge + liste
    // ET affiche la bannière basse unifiée (Fermer / Supprimer / Voir).
    // Pourquoi ici plutôt que dans le provider : le shell possède le
    // ScaffoldMessenger actif de la page visible, donc le toast s'affiche
    // sur tous les onglets (la déduplication intégrée à la bannière évite
    // le doublon avec le chemin FCM foreground sur Web).
    Future.microtask(() {
      try {
        ref.read(gameWebSocketServiceProvider).onNotificationCreated =
            (payload) {
          ref.invalidate(inboxProvider);
          ref.invalidate(unreadNotificationsCountProvider);
          final context = rootNavigatorKey.currentContext;
          if (context == null || !context.mounted) return;
          final title =
              (payload['title'] as String?)?.trim() ?? 'WIWIGA';
          final body = (payload['body'] as String?)?.trim() ?? '';
          if (title == 'WIWIGA' && body.isEmpty) return;
          showInAppNotificationBanner(
            context,
            data: (
              id: parseInAppNotificationId(payload),
              title: title,
              body: body,
              category: parseInAppCategory(payload['category']),
              priority: parseInAppPriority(payload['priority']),
            ),
            onView: () {
              final ctx = rootNavigatorKey.currentContext;
              if (ctx == null || !ctx.mounted) return;
              ctx.push(_routeForWsEvent(payload));
            },
            onDelete: () => deleteInAppNotificationFromWidget(ref, payload),
          );
        };
      } catch (_) {}
    });
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
    ref.invalidate(unreadNotificationsCountProvider);
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
    final isHome = widget.navigationShell.currentIndex == 0;

    return ResponsiveNavigation(
      currentIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: _onBranchChanged,
      destinations: _destinations,
      body: widget.navigationShell,
      appBarTitle: 'WIWIGA',
      // Header principal (historique, profil, paramètres) uniquement sur /home
      appBarActions: !isHome
          ? null
          : isGuest
              ? [
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
                  if (authState.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFFF6600)),
                      tooltip: 'Administration',
                      onPressed: () => context.go('/admin'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined, color: NeonColors.primary),
                    tooltip: 'Historique des transactions',
                    onPressed: () => context.push('/transactions'),
                  ),
                  // Cloche notifications avec badge non-lues
                  const _NotificationBell(),
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

/// Destination du bouton Voir / tap bannière pour un événement WS.
///
/// Pourquoi dupliquée avec l'inbox : la bannière n'a pas accès au modèle
/// complet (pas de deep-link serveur), on route donc sur `event_type`
/// (même table que `NotificationsScreen._routeFor`, repli `/notifications`).
String _routeForWsEvent(Map<String, dynamic> payload) {
  switch (payload['event_type']?.toString()) {
    case 'friend_request':
    case 'friend_accepted':
      return '/friends';
    case 'wallet_credit':
    case 'wallet_debit':
    case 'cash_withdraw':
      return '/transactions';
    case 'match_result':
    case 'game_matched':
      return '/games';
    case 'achievement_unlocked':
      return '/profile';
    default:
      return '/notifications';
  }
}

/// Cloche notifications avec badge de non-lues — ouvre l'inbox
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: NeonColors.primary),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
        if (unread.valueOrNull != null && unread.valueOrNull! > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: NeonColors.error,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: NeonColors.error.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                unread.valueOrNull! > 99 ? '99+' : '${unread.valueOrNull}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

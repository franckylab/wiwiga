// ============================================================
// Fichier: app_router.dart
// Description: Configuration go_router (shell 5 onglets + routes jeux)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/game_room_model.dart';
import '../../data/providers/game_stats_providers.dart';
import '../../presentation/screens/auth/auth_screen_neon.dart';
import '../../presentation/screens/dice_game/dice_game_screen.dart';
import '../../presentation/screens/dice_game/dice_match_screen.dart';
import '../../presentation/screens/friends/friends_screen.dart';
import '../../presentation/screens/game/create_game_screen.dart';
import '../../presentation/screens/game/game_room_waiting_screen.dart';
import '../../presentation/screens/game_lobby/game_lobby_enhanced_screen.dart';
import '../../presentation/screens/games/game_detail_screen.dart';
import '../../presentation/screens/games/games_catalog_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../../presentation/screens/main/main_shell_screen.dart';
import '../../presentation/screens/profile/profile_screen_enhanced.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/transaction_history/transaction_history_screen.dart';
import '../../presentation/screens/wallet/wallet_screen_neon.dart';
import '../theme/neon_theme.dart';

/// Clé du navigateur racine (écrans plein écran hors shell)
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provider du routeur de l'application
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      // --- Routes hors shell (plein écran) ---
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AuthScreenNeon(),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileScreenEnhanced(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/transactions',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TransactionHistoryScreen(),
      ),

      // --- Shell à 5 onglets ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Onglet Accueil
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],),

          // Onglet Jeux : catalogue → détail → lobby/salle/match
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/games',
              builder: (context, state) => const GamesCatalogScreen(),
              routes: [
                GoRoute(
                  path: ':gameType',
                  builder: (context, state) => GameDetailScreen(
                    gameType: state.pathParameters['gameType']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'lobby',
                      builder: (context, state) => GameLobbyEnhancedScreen(
                        gameType: state.pathParameters['gameType']!,
                      ),
                    ),
                    GoRoute(
                      path: 'create',
                      builder: (context, state) => CreateGameScreen(
                        gameType: state.pathParameters['gameType']!,
                      ),
                    ),
                    GoRoute(
                      path: 'room/:roomId',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => _RoomRouteLoader(
                        roomId: state.pathParameters['roomId']!,
                        room: state.extra is GameRoomModel
                            ? state.extra as GameRoomModel
                            : null,
                      ),
                    ),
                    GoRoute(
                      path: 'match/:matchId',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final extra =
                            state.extra as Map<String, dynamic>? ?? {};
                        return DiceMatchScreen(
                          matchId: state.pathParameters['matchId']!,
                          ruleType: extra['rule_type'] ?? 'normal',
                          setsCount: extra['sets_count'] ?? 3,
                          diceCount: extra['dice_count'] ?? 2,
                          betAmount: extra['bet_amount'] ?? 0,
                          players: List<Map<String, dynamic>>.from(
                              extra['players'] as List? ?? const [],),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'session/:gameId',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final extra =
                            state.extra as Map<String, dynamic>? ?? {};
                        return DiceGameScreen(
                          gameId: state.pathParameters['gameId'],
                          betAmount: extra['bet_amount'] ?? 500,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],),

          // Onglet Amis
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/friends',
              builder: (context, state) => const FriendsScreen(),
            ),
          ],),

          // Onglet Jetons
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tokens',
              builder: (context, state) => const WalletScreenNeon(),
            ),
          ],),

          // Onglet Classement
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/leaderboard',
              builder: (context, state) => const LeaderboardScreen(),
            ),
          ],),
        ],
      ),
    ],
  );
});

/// Charge la salle depuis l'API si non fournie via `extra`
class _RoomRouteLoader extends ConsumerWidget {
  final String roomId;
  final GameRoomModel? room;

  const _RoomRouteLoader({required this.roomId, this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (room != null) {
      return GameRoomWaitingScreen(room: room!);
    }

    final roomRepo = ref.watch(roomRepositoryProvider);
    return FutureBuilder<GameRoomModel>(
      future: roomRepo.getRoom(roomId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GameRoomWaitingScreen(room: snapshot.data!);
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: NeonColors.surface,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: NeonColors.error, size: 48,),
                  const SizedBox(height: 12),
                  const Text(
                    'Salle introuvable',
                    style: TextStyle(color: NeonColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/games'),
                    child: const Text('Retour aux jeux'),
                  ),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: NeonColors.surface,
          body: Center(
            child: CircularProgressIndicator(color: NeonColors.primary),
          ),
        );
      },
    );
  }
}

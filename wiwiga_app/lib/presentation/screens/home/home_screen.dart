// ============================================================
// Fichier: home_screen.dart
// Description: Écran Accueil dashboard (onglet Accueil)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_stats_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../widgets/auth/auth_gate.dart';
import '../../widgets/neon/neon_widgets.dart';

final _homeAmountFormat = NumberFormat('#,##0', 'fr_FR');

/// Écran Accueil : dashboard avec solde, jeu vedette, raccourcis et activité
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Charger le solde uniquement si authentifié
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        ref.read(walletProvider.notifier).loadBalance();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final catalogAsync = ref.watch(gamesCatalogProvider);
    final activityAsync = ref.watch(gameActivityProvider('dice'));
    final weeklyPodiumAsync = ref.watch(gameLeaderboardProvider(
        (gameType: 'dice', metric: 'wins', period: 'week'),),);
    final myStatsAsync = ref.watch(myGameStatsProvider('dice'));

    final isGuest = authState.isGuest || authState.isUnknown;
    final username = authState.user?.username ?? 'Joueur';

    return Scaffold(
      backgroundColor: NeonColors.surface,
      body: RefreshIndicator(
        color: NeonColors.primary,
        backgroundColor: NeonColors.card,
        onRefresh: () async {
          ref.invalidate(gamesCatalogProvider);
          ref.invalidate(gameActivityProvider('dice'));
          ref.invalidate(gameLeaderboardProvider(
              (gameType: 'dice', metric: 'wins', period: 'week'),),);
          if (!isGuest) {
            ref.invalidate(myGameStatsProvider('dice'));
            await ref.read(walletProvider.notifier).loadBalance();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildGreeting(username, walletState.balance, isGuest),
            const SizedBox(height: 20),
            _buildAnnouncementBanner(),
            const SizedBox(height: 20),
            catalogAsync.when(
              data: (games) => _buildFeaturedGame(games, isGuest),
              loading: () => const ShimmerLoader(height: 150),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            _buildShortcuts(isGuest),
            const SizedBox(height: 20),
            if (!isGuest) ...[  
              _buildMyStats(myStatsAsync),
              const SizedBox(height: 20),
            ],
            _buildSectionTitle('Activité de la communauté',
                Icons.local_fire_department,),
            const SizedBox(height: 8),
            activityAsync.when(
              data: (events) => _buildCommunityFeed(events),
              loading: () => const ShimmerLoader(height: 100),
              error: (_, __) => _mutedText('Activité indisponible'),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Podium de la semaine', Icons.emoji_events),
            const SizedBox(height: 8),
            weeklyPodiumAsync.when(
              data: (board) => _buildWeeklyPodium(board),
              loading: () => const ShimmerLoader(height: 90),
              error: (_, __) => _mutedText('Podium indisponible'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(String username, double balanceFrancs, bool isGuest) {
    final walletState = ref.watch(walletProvider);
    return NeonCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGuest ? 'Bienvenue sur WIWIGA' : 'Bonjour, $username',
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: NeonColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'Connectez-vous pour jouer et gagner !'
                      : 'Prêt à défier la communauté ?',
                  style: const TextStyle(
                      fontSize: 13, color: NeonColors.textSecondary,),
                ),
                if (isGuest) ...[  
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      ref.read(authProvider.notifier).setRedirectTo('/home');
                      context.go('/auth');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: NeonGradients.cta,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SE CONNECTER',
                        style: TextStyle(
                          color: NeonColors.background,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isGuest)
            TokenBalanceDisplay(
              tokenBalance: walletState.tokenBalance,
              fontSize: 22,
              onTap: () => context.go('/tokens'),
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: NeonGradients.cta,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: NeonColors.primary.withValues(alpha: NeonGlow.opacityMedium),
            blurRadius: NeonGlow.blurSmall,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined,
              size: 32, color: NeonColors.background,),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nouveaux jeux à venir !',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: NeonColors.background,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ludo, Cartes et Roulette arrivent bientôt sur WIWIGA.',
                  style: TextStyle(
                    fontSize: 12,
                    color: NeonColors.background.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/games'),
            child: const Text(
              'Voir',
              style: TextStyle(
                color: NeonColors.background,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedGame(List<GameModel> games, bool isGuest) {
    final featured = games.where((g) => !g.comingSoon).toList();
    if (featured.isEmpty) return const SizedBox.shrink();
    final game = featured.first;

    return NeonCard(
      onTap: () => context.go('/games/${game.type}'),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: NeonGradients.cta,
            ),
            child: const Icon(Icons.casino_outlined,
                size: 32, color: NeonColors.background,),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NeonColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const GlowBadge(
                      text: 'VEDETTE',
                      color: NeonColors.secondary,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${game.playersOnline} joueurs en ligne · '
                  'Mise dès ${_homeAmountFormat.format(game.minBet ~/ 100 * 10)} jetons',
                  style: const TextStyle(
                      fontSize: 12, color: NeonColors.textSecondary,),
                ),
                const SizedBox(height: 10),
                AuthGate(
                  type: AuthGateType.softWall,
                  action: () => context.go('/games/${game.type}/lobby'),
                  child: NeonButton(
                    text: 'JOUER',
                    width: 130,
                    height: 38,
                    fontSize: 13,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    onPressed: () {}, // AuthGate gère le tap
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts(bool isGuest) {
    final shortcuts = [
      ('Acheter', Icons.shopping_cart_outlined, NeonColors.success, '/tokens', true),
      ('Amis', Icons.people_outline, NeonColors.accent, '/friends', true),
      ('Classement', Icons.emoji_events_outlined, NeonColors.secondary,
          '/leaderboard', false),
    ];

    return Row(
      children: shortcuts.map((shortcut) {
        final (label, icon, color, route, needsAuth) = shortcut;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: needsAuth && isGuest
                ? NeonCard(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onTap: () {
                      ref.read(authProvider.notifier).setRedirectTo(route);
                      context.go('/auth');
                    },
                    child: Column(
                      children: [
                        Icon(icon, color: color.withValues(alpha: 0.5), size: 26),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: NeonColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Connex.',
                          style: TextStyle(
                            fontSize: 9,
                            color: NeonColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : NeonCard(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onTap: () => context.go(route),
                    child: Column(
                      children: [
                        Icon(icon, color: color, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: NeonColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMyStats(AsyncValue<MyGameStats> myStatsAsync) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_outlined,
                  size: 18, color: NeonColors.accent,),
              SizedBox(width: 8),
              Text(
                'Mes dernières performances',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          myStatsAsync.when(
            data: (stats) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem('Parties', '${stats.matchesPlayed}'),
                _statItem('Victoires', '${stats.wins}'),
                _statItem('Win rate', '${stats.winRate.toStringAsFixed(0)}%'),
                _statItem('Série', '${stats.currentStreak} 🔥'),
              ],
            ),
            loading: () => const ShimmerLoader(height: 44),
            error: (_, __) => const Text(
              'Jouez votre première partie pour voir vos stats !',
              style: TextStyle(color: NeonColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: NeonColors.primary,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: NeonColors.textSecondary),),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: NeonColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: NeonColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _mutedText(String text) {
    return Text(text,
        style: const TextStyle(color: NeonColors.textMuted, fontSize: 13),);
  }

  Widget _buildCommunityFeed(List<GameActivityEvent> events) {
    if (events.isEmpty) {
      return _mutedText('Aucune victoire récente — lancez la première !');
    }
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: events.take(5).map((event) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                const Icon(Icons.emoji_events,
                    size: 16, color: NeonColors.secondary,),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${event.name} a gagné '
                    '${_homeAmountFormat.format((event.amount ~/ 100 * 10))} jetons',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: NeonColors.textPrimary,),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyPodium(GameLeaderboard board) {
    if (board.entries.isEmpty) {
      return _mutedText('Aucun vainqueur cette semaine — à vous de jouer !');
    }

    final colors = [NeonColors.rankGold, NeonColors.rankSilver, NeonColors.rankBronze];

    return NeonCard(
      onTap: () => context.go('/games/dice'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: board.entries.take(3).toList().asMap().entries.map((item) {
          final index = item.key;
          final entry = item.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.emoji_events, size: 20, color: colors[index]),
                const SizedBox(width: 10),
                Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: colors[index],
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NeonColors.textPrimary),
                  ),
                ),
                Text(
                  '${entry.value} victoires',
                  style: const TextStyle(
                    fontSize: 12,
                    color: NeonColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

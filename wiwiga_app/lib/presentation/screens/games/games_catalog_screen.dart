// ============================================================
// Fichier: games_catalog_screen.dart
// Description: Catalogue des jeux (onglet Jeux)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../widgets/game/wiwiga_dice_icon.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran Catalogue : grille responsive des jeux disponibles
/// Redirection auto si le joueur est déjà dans une partie en attente/en cours
class GamesCatalogScreen extends ConsumerStatefulWidget {
  const GamesCatalogScreen({super.key});

  @override
  ConsumerState<GamesCatalogScreen> createState() => _GamesCatalogScreenState();
}

class _GamesCatalogScreenState extends ConsumerState<GamesCatalogScreen> {
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkActiveAndRedirect());
  }

  Future<void> _checkActiveAndRedirect() async {
    if (_hasRedirected) return;
    try {
      final active = await ref.read(activeGameProvider.future);
      if (!mounted || active == null) return;
      final path = _activeRedirectPath(active);
      if (path != null && mounted) {
        _hasRedirected = true;
        if (mounted) context.go(path, extra: _activeExtra(active));
      }
    } catch (_) {}
  }

  String? _activeRedirectPath(Map<String, dynamic> active) {
    final type = active['type'] as String?;
    final gameType = active['game_type'] as String? ?? 'dice';
    switch (type) {
      case 'match':
        final matchId = active['match_id'] as String?;
        if (matchId != null) return '/games/$gameType/match/$matchId';
        break;
      case 'room_waiting':
      case 'room_in_progress':
        final roomId = active['room_id'] as String?;
        final matchId = active['match_id'] as String?;
        // Si la salle a déjà un match, aller directement au match
        if (matchId != null && matchId.toString().isNotEmpty) {
          return '/games/$gameType/match/$matchId';
        }
        if (roomId != null) return '/games/$gameType/room/$roomId';
        break;
      case 'quick_lobby':
        // Rediriger vers la recherche bloquante synchronisée
        return '/games/$gameType/quick-search';
      default:
        return null;
    }
    return null;
  }

  Map<String, dynamic>? _activeExtra(Map<String, dynamic> active) {
    final type = active['type'] as String?;
    if (type == 'quick_lobby') {
      return {
        'bet_amount': active['bet_amount'],
        'rule_type': active['rule_type'] ?? 'normal',
      };
    }
    if (type == 'match') {
      return {
        'rule_type': active['rule_type'] ?? 'normal',
        'bet_amount': active['bet_amount'] ?? 0,
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(gamesCatalogProvider);
    final activeAsync = ref.watch(activeGameProvider);
    activeAsync.whenData((active) {
      if (active != null && !_hasRedirected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final path = _activeRedirectPath(active);
          if (path != null && mounted && !_hasRedirected) {
            _hasRedirected = true;
            context.go(path, extra: _activeExtra(active));
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: NeonColors.surface,
      body: RefreshIndicator(
        color: NeonColors.primary,
        backgroundColor: NeonColors.card,
        onRefresh: () => ref.refresh(gamesCatalogProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            catalogAsync.when(
              data: (games) => games.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : _buildGrid(context, games),
              loading: () => _buildLoadingGrid(),
              error: (error, _) => SliverFillRemaining(
                child: _buildErrorState(ref, error),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catalogue des jeux',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NeonColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Choisissez votre jeu et défiez la communauté',
            style: TextStyle(
              fontSize: 14,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<GameModel> games) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final crossAxisCount = width > 1100
              ? 3
              : width > 700
                  ? 2
                  : 1;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 210,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => GameCatalogCard(game: games[index]),
              childCount: games.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: ShimmerLoader(height: 210),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videogame_asset_off_outlined,
            size: 56,
            color: NeonColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'Aucun jeu disponible pour le moment',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_outlined,
            size: 56,
            color: NeonColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger les jeux',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 16),
          NeonButton(
            text: 'Réessayer',
            width: 160,
            variant: NeonButtonVariant.outline,
            onPressed: () => ref.invalidate(gamesCatalogProvider),
          ),
        ],
      ),
    );
  }
}

/// Carte néon d'un jeu du catalogue
class GameCatalogCard extends StatelessWidget {
  final GameModel game;

  const GameCatalogCard({super.key, required this.game});

  static final _amountFormat = (() { try { return NumberFormat('#,##0', 'fr_FR'); } catch (_) { return NumberFormat.decimalPattern(); } })();

  IconData get _gameIcon {
    switch (game.type) {
      case 'dice':
        return Icons.casino_outlined;
      case 'ludo':
        return Icons.grid_view_rounded;
      case 'card':
        return Icons.style_outlined;
      case 'roulette':
        return Icons.track_changes_outlined;
      default:
        return Icons.videogame_asset_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final comingSoon = game.comingSoon;

    return Opacity(
      opacity: comingSoon ? 0.55 : 1,
      child: NeonCard(
        onTap: comingSoon ? null : () => context.go('/games/${game.type}'),
        isEnabled: !comingSoon,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: comingSoon ? null : NeonGradients.cta,
                    color: comingSoon ? NeonColors.border : null,
                  ),
                  child: game.type == 'dice' && !comingSoon
                      ? const Center(child: WiwigaDiceIcon(size: 38, withShadow: false))
                      : Icon(
                          _gameIcon,
                          size: 28,
                          color: comingSoon
                              ? NeonColors.textMuted
                              : NeonColors.background,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: NeonColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      comingSoon
                          ? const GlowBadge(
                              text: 'Bientôt disponible',
                              color: NeonColors.secondary,
                            )
                          : GlowBadge(
                              text: '${game.playersOnline} en ligne',
                              color: NeonColors.success,
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pas d'Expanded/Spacer ici : NeonCard ne borne pas la hauteur
            // de la Column (RenderFlex unbounded sinon)
            SizedBox(
              height: 36,
              child: Text(
                comingSoon
                    ? 'Ce jeu arrive prochainement sur WIWIGA. Restez connecté !'
                    : game.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!comingSoon) ...[
                        const TokenCoin(
                          size: 14,
                          metal: TokenMetal.emerald,
                          lod: TokenLod.flat,
                          showShadow: false,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Mise min. ${_amountFormat.format(game.minBet.toInt())} wiga',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: NeonColors.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!comingSoon)
                  NeonButton(
                    text: 'Découvrir',
                    width: 130,
                    height: 40,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    onPressed: () => context.go('/games/${game.type}'),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

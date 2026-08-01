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
import '../../widgets/neon/neon_widgets.dart';

/// Écran Catalogue : grille responsive des jeux disponibles
class GamesCatalogScreen extends ConsumerWidget {
  const GamesCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(gamesCatalogProvider);

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
          Icon(Icons.videogame_asset_off_outlined,
              size: 56, color: NeonColors.textMuted,),
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
          const Icon(Icons.wifi_off_outlined, size: 56, color: NeonColors.error),
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

  static final _amountFormat = NumberFormat('#,##0', 'fr_FR');

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
                  child: Icon(
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
                        const Icon(Icons.payments_outlined,
                            size: 16, color: NeonColors.secondary,),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Mise min. ${_amountFormat.format((game.minBet ~/ 100 * 10))} jetons',
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
                        horizontal: 12, vertical: 8,),
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

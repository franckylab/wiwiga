import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/game_stats_models.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Providers ===

final leaderboardGameTypeProvider = StateProvider<String>((ref) => 'dice');
final leaderboardPeriodProvider = StateProvider<String>((ref) => 'weekly');
final leaderboardMetricProvider = StateProvider<String>((ref) => 'wins');

/// Provider qui récupère les récompenses ranking depuis PlatformConfig
final rankingRewardsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final adminRepo = ref.read(adminRepositoryProvider);
    final configs = await adminRepo.getPlatformConfigByCategory('ranking');
    final rewards = <Map<String, dynamic>>[];
    for (final c in configs) {
      final key = c['key'] as String? ?? '';
      if (key.startsWith('leaderboard_reward_top')) {
        final rank = int.tryParse(key.replaceAll('leaderboard_reward_top', '')) ?? 0;
        final amount = int.tryParse(c['value']?.toString() ?? c['default_value']?.toString() ?? '0') ?? 0;
        if (rank > 0) rewards.add({'rank': rank, 'amount': amount});
      }
    }
    rewards.sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
    return rewards;
  } catch (_) {
    return [];
  }
});

// === Écran ===

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameType = ref.watch(leaderboardGameTypeProvider);
    final period = ref.watch(leaderboardPeriodProvider);
    final metric = ref.watch(leaderboardMetricProvider);

    // Map period to API format
    final apiPeriod = switch (period) {
      'daily' => 'day',
      'weekly' => 'week',
      'monthly' => 'month',
      _ => 'all',
    };

    final leaderboardAsync = ref.watch(gameLeaderboardProvider((
      gameType: gameType,
      metric: metric,
      period: apiPeriod,
    ),),);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMetricSelector(ref, metric),
            _buildPeriodSelector(ref, period),
            Expanded(
              child: leaderboardAsync.when(
                data: (leaderboard) => Column(
                  children: [
                    if (leaderboard.entries.length >= 3)
                      _buildPodium(leaderboard.entries.take(3).toList()),
                    _buildRewardsBanner(ref),
                    Expanded(child: _buildLeaderboardList(leaderboard)),
                    if (leaderboard.myRank != null)
                      _buildMyRankFooter(leaderboard),
                  ],
                ),
                loading: () => const NeonLoadingSpinner.center(),
                error: (e, _) => _buildError(e.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeonColors.rankGold.withValues(alpha: 0.3),
            NeonColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: NeonColors.rankGold, size: 28),
          const SizedBox(width: 8),
          Text('CLASSEMENT', style: AppTypography.heading3),
          const Spacer(),
          const GlowBadge(
            text: 'SAISON 1',
            color: NeonColors.rankGold,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector(WidgetRef ref, String current) {
    final metrics = [
      {'key': 'wins', 'label': 'Victoires', 'icon': Icons.emoji_events},
      {'key': 'total_won', 'label': 'Gains', 'icon': Icons.monetization_on},
      {'key': 'biggest_win', 'label': 'Plus gros gain', 'icon': Icons.trending_up},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: metrics.map((m) {
          final isSelected = current == m['key'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => ref.read(leaderboardMetricProvider.notifier).state = m['key'] as String,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? NeonColors.secondary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? NeonColors.secondary : NeonColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(m['icon'] as IconData? ?? Icons.star, size: 14, color: isSelected ? NeonColors.secondary : NeonColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        m['label'] as String,
                        style: TextStyle(
                          color: isSelected ? NeonColors.secondary : NeonColors.textSecondary,
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, String current) {
    final periods = [
      {'key': 'daily', 'label': 'Jour'},
      {'key': 'weekly', 'label': 'Semaine'},
      {'key': 'monthly', 'label': 'Mois'},
      {'key': 'all', 'label': 'Total'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: periods.map((p) {
          final isSelected = current == p['key'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => ref.read(leaderboardPeriodProvider.notifier).state = p['key']!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? NeonColors.rankGold.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? NeonColors.rankGold : NeonColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p['label']!,
                    style: TextStyle(
                      color: isSelected ? NeonColors.rankGold : NeonColors.textSecondary,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodium(List<GameLeaderboardEntry> top3) {
    // Mapping rang → métal pour podium 3D
    TokenMetal metalForRank(int r) {
      if (r == 1) return TokenMetal.gold;
      if (r == 2) return TokenMetal.silver;
      if (r == 3) return TokenMetal.bronze;
      if (r <= 5) return TokenMetal.diamond;
      return TokenMetal.emerald;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top3.length > 1) _PodiumCard(entry: top3[1], height: 100, color: NeonColors.rankSilver, metal: metalForRank(top3[1].rank)),
          const SizedBox(width: 8),
          _PodiumCard(entry: top3[0], height: 130, color: NeonColors.rankGold, metal: metalForRank(top3[0].rank)),
          const SizedBox(width: 8),
          if (top3.length > 2) _PodiumCard(entry: top3[2], height: 85, color: NeonColors.rankBronze, metal: metalForRank(top3[2].rank)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(GameLeaderboard leaderboard) {
    final entries = leaderboard.entries;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final tierColor = _getRankColor(entry.rank);
        final isTop3 = entry.rank <= 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: NeonCard(
            child: Row(
              children: [
                // Rank — 3D métal si top3, sinon flat
                if (isTop3)
                  TokenCoin(
                    size: 36,
                    metal: entry.rank == 1
                        ? TokenMetal.gold
                        : entry.rank == 2
                            ? TokenMetal.silver
                            : TokenMetal.bronze,
                    lod: TokenLod.bevel,
                    rankLabel: '${entry.rank}',
                    withW: false,
                    showShadow: false,
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tierColor.withValues(alpha: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.rank}',
                      style: TextStyle(
                        color: tierColor,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                // Name + value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          color: NeonColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.wins} victoires',
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                // Value
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatValue(entry.value),
                      style: const TextStyle(
                        color: NeonColors.rankGold,
                        fontFamily: 'Orbitron',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'pts',
                      style: TextStyle(
                        color: NeonColors.textSecondary,
                        fontSize: 10,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyRankFooter(GameLeaderboard leaderboard) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.primary.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: NeonColors.primary.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Text(
            'Votre rang: #${leaderboard.myRank}',
            style: const TextStyle(color: NeonColors.primary, fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            _formatValue(leaderboard.myValue ?? 0),
            style: const TextStyle(color: NeonColors.primary, fontFamily: 'Orbitron'),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsBanner(WidgetRef ref) {
    final rewardsAsync = ref.watch(rankingRewardsProvider);
    return rewardsAsync.when(
      data: (rewards) {
        if (rewards.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NeonColors.rankGold.withValues(alpha: 0.15),
                NeonColors.secondary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NeonColors.rankGold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.card_giftcard, color: NeonColors.rankGold, size: 18),
              const SizedBox(width: 8),
              const Text('R\u00e9compenses', style: TextStyle(color: NeonColors.rankGold, fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              ...rewards.take(3).map((r) {
                final rank = r['rank'] as int;
                final amount = r['amount'] as int;
                final color = rank == 1 ? NeonColors.rankGold : rank == 2 ? NeonColors.rankSilver : NeonColors.rankBronze;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('#$rank', style: TextStyle(color: color, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                      Text('${(amount / 1000).toStringAsFixed(0)}K', style: TextStyle(color: color, fontSize: 11, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: NeonColors.error, size: 48),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: NeonColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return NeonColors.rankGold;
    if (rank <= 5) return NeonColors.rankPlatinum;
    if (rank <= 10) return NeonColors.rankSilver;
    if (rank <= 20) return NeonColors.rankBronze;
    return NeonColors.textSecondary;
  }

  String _formatValue(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

// === Podium Card — 3D métal ===

class _PodiumCard extends StatelessWidget {
  final GameLeaderboardEntry entry;
  final double height;
  final Color color;
  final TokenMetal metal;

  const _PodiumCard({
    required this.entry,
    required this.height,
    required this.color,
    this.metal = TokenMetal.gold,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = entry.rank == 1;
    return Expanded(
      child: NeonCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rank — pièce 3D métal
            TokenCoin(
              size: isFirst ? 48 : 40,
              metal: metal,
              lod: TokenLod.full,
              effect: isFirst ? TokenEffect.shimmer : TokenEffect.none,
              animated: isFirst,
              rankLabel: '${entry.rank}',
              withW: false,
            ),
            const SizedBox(height: 8),
            Text(
              entry.name,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.value}',
              style: TextStyle(
                color: color,
                fontFamily: 'Orbitron',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

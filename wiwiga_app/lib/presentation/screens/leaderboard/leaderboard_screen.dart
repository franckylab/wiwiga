import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Models ===

class LeaderboardEntry {
  final int rank;
  final String name;
  final int wins;
  final int losses;
  final int totalEarnings;
  final int winRate;
  final String rankTier;

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.wins,
    required this.losses,
    required this.totalEarnings,
    required this.winRate,
    required this.rankTier,
  });
}

// === Providers ===

final leaderboardPeriodProvider = StateProvider<String>((ref) => 'weekly');

final leaderboardEntriesProvider = Provider<List<LeaderboardEntry>>((ref) {
  return [
    LeaderboardEntry(rank: 1, name: 'ProGamer_CM', wins: 156, losses: 23, totalEarnings: 2450000, winRate: 87, rankTier: 'diamond'),
    LeaderboardEntry(rank: 2, name: 'DiceKing', wins: 142, losses: 31, totalEarnings: 1890000, winRate: 82, rankTier: 'diamond'),
    LeaderboardEntry(rank: 3, name: 'LuckyHand', wins: 128, losses: 42, totalEarnings: 1560000, winRate: 75, rankTier: 'platinum'),
    LeaderboardEntry(rank: 4, name: 'Chanceux237', wins: 115, losses: 38, totalEarnings: 1230000, winRate: 75, rankTier: 'platinum'),
    LeaderboardEntry(rank: 5, name: 'NeonPlayer', wins: 98, losses: 45, totalEarnings: 980000, winRate: 69, rankTier: 'gold'),
    LeaderboardEntry(rank: 6, name: 'Gamer_X', wins: 87, losses: 52, totalEarnings: 750000, winRate: 63, rankTier: 'gold'),
    LeaderboardEntry(rank: 7, name: 'RollMaster', wins: 76, losses: 48, totalEarnings: 620000, winRate: 61, rankTier: 'gold'),
    LeaderboardEntry(rank: 8, name: 'BetKing_CM', wins: 65, losses: 55, totalEarnings: 480000, winRate: 54, rankTier: 'silver'),
    LeaderboardEntry(rank: 9, name: 'Vous', wins: 47, losses: 29, totalEarnings: 350000, winRate: 62, rankTier: 'silver'),
    LeaderboardEntry(rank: 10, name: 'Newbie237', wins: 23, losses: 34, totalEarnings: 120000, winRate: 40, rankTier: 'bronze'),
  ];
});

// === Écran ===

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardEntriesProvider);
    final period = ref.watch(leaderboardPeriodProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Period selector
            _buildPeriodSelector(ref, period),
            // Top 3 podium
            _buildPodium(entries.take(3).toList()),
            // Full list
            Expanded(
              child: _buildLeaderboardList(entries),
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

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (top3.length > 1) _PodiumCard(entry: top3[1], height: 100, color: NeonColors.rankSilver),
          const SizedBox(width: 8),
          // 1st place (taller)
          _PodiumCard(entry: top3[0], height: 130, color: NeonColors.rankGold),
          const SizedBox(width: 8),
          // 3rd place
          if (top3.length > 2) _PodiumCard(entry: top3[2], height: 85, color: NeonColors.rankBronze),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isYou = entry.name == 'Vous';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isYou ? NeonColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isYou ? Border.all(color: NeonColors.primary.withValues(alpha: 0.3)) : null,
          ),
          child: NeonCard(
            child: Row(
              children: [
                // Rank
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getRankColor(entry.rankTier).withValues(alpha: 0.15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.rank}',
                    style: TextStyle(
                      color: _getRankColor(entry.rankTier),
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: isYou ? FontWeight.bold : FontWeight.w500,
                              color: isYou ? NeonColors.primary : NeonColors.textPrimary,
                            ),
                          ),
                          if (isYou) ...[
                            const SizedBox(width: 6),
                            const GlowBadge(text: 'VOUS', color: NeonColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${entry.wins}V - ${entry.losses}D',
                            style: const TextStyle(
                              color: NeonColors.textSecondary,
                              fontSize: 11,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${entry.winRate}% win',
                            style: TextStyle(
                              color: entry.winRate >= 60 ? NeonColors.success : NeonColors.textSecondary,
                              fontSize: 11,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Earnings
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTokens(entry.totalEarnings),
                      style: const TextStyle(
                        color: NeonColors.rankGold,
                        fontFamily: 'Orbitron',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'jetons',
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

  Color _getRankColor(String tier) {
    switch (tier) {
      case 'diamond': return NeonColors.rankDiamond;
      case 'platinum': return NeonColors.rankPlatinum;
      case 'gold': return NeonColors.rankGold;
      case 'silver': return NeonColors.rankSilver;
      case 'bronze': return NeonColors.rankBronze;
      default: return NeonColors.textSecondary;
    }
  }

  String _formatTokens(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ',);
  }
}

// === Podium Card ===

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final Color color;

  const _PodiumCard({
    required this.entry,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: NeonCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rank badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '${entry.rank}',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
              '${entry.winRate}%',
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

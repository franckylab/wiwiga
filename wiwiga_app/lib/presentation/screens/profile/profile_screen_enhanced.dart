import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/auth/success_animation.dart';

/// Écran Profil amélioré avec données dynamiques, historique, achievements
class ProfileScreenEnhanced extends ConsumerWidget {
  const ProfileScreenEnhanced({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header avec avatar et rang
            SliverToBoxAdapter(child: _ProfileHeader(profile: profile)),
            // Stats rapides
            SliverToBoxAdapter(child: _QuickStats(profile: profile)),
            // XP Bar
            SliverToBoxAdapter(child: _XpBar(profile: profile)),
            // Achievements
            SliverToBoxAdapter(
              child: _AchievementsSection(achievements: profile.achievements),
            ),
            // Historique récent
            SliverToBoxAdapter(
              child: _RecentGamesSection(games: profile.recentGames),
            ),
            // Actions
            SliverToBoxAdapter(child: _ProfileActions(profile: profile)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// === HEADER ===

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRankColor(profile.rankTier).withValues(alpha: 0.3),
            NeonColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Avatar + rang
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getRankColor(profile.rankTier),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getRankColor(profile.rankTier).withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: NeonColors.surface,
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: _getRankColor(profile.rankTier),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: NeonColors.background,
                ),
                child: RankBadge(
                  rank: profile.rankLabel,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Username
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.username ?? 'Joueur',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.textPrimary,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(width: 8),
              if (profile.isVerified)
                const Icon(Icons.verified, color: NeonColors.info, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          // Phone
          Text(
            profile.phone,
            style: const TextStyle(
              fontSize: 14,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          // Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: NeonColors.success, size: 18),
              const SizedBox(width: 6),
              Text(
                _formatTokens(profile.balance.toInt()),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.success,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'jetons',
                style: TextStyle(
                  fontSize: 12,
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// === QUICK STATS ===

class _QuickStats extends StatelessWidget {
  final UserProfile profile;

  const _QuickStats({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: NeonCard(
        child: Row(
          children: [
            _StatMini(
              value: '${profile.gamesPlayed}',
              label: 'Parties',
              color: NeonColors.primary,
            ),
            _Divider(),
            _StatMini(
              value: '${profile.wins}',
              label: 'Victoires',
              color: NeonColors.success,
            ),
            _Divider(),
            _StatMini(
              value: '${profile.winRate.toStringAsFixed(0)}%',
              label: 'Win Rate',
              color: profile.winRate >= 50 ? NeonColors.success : NeonColors.error,
            ),
            _Divider(),
            _StatMini(
              value: '${profile.currentStreak}',
              label: 'Série',
              color: NeonColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatMini({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 30, color: NeonColors.border,
  );
}

// === XP BAR ===

class _XpBar extends StatelessWidget {
  final UserProfile profile;

  const _XpBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final xpForNextLevel = _xpForNextRank(profile.rankTier);
    final xpProgress = (profile.xpPoints / xpForNextLevel).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'XP: ${profile.xpPoints}',
                  style: const TextStyle(
                    color: NeonColors.primary,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Prochain: ${profile.rankTier == 'diamond' ? 'MAX' : _nextRankLabel(profile.rankTier)}',
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontFamily: 'Inter',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: xpProgress,
                backgroundColor: NeonColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getRankColor(profile.rankTier),
                ),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _xpForNextRank(String tier) {
    switch (tier) {
      case 'bronze': return 2000;
      case 'silver': return 5000;
      case 'gold': return 10000;
      case 'platinum': return 20000;
      case 'diamond': return 99999;
      default: return 2000;
    }
  }

  String _nextRankLabel(String tier) {
    switch (tier) {
      case 'bronze': return 'Argent';
      case 'silver': return 'Or';
      case 'gold': return 'Platine';
      case 'platinum': return 'Diamant';
      default: return 'MAX';
    }
  }
}

// === ACHIEVEMENTS ===

class _AchievementsSection extends StatelessWidget {
  final List<Achievement> achievements;

  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.isUnlocked).toList();
    final locked = achievements.where((a) => !a.isUnlocked).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: NeonColors.rankGold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'ACHIEVEMENTS',
                style: TextStyle(
                  color: NeonColors.textPrimary,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${unlocked.length}/${achievements.length}',
                style: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Unlocked achievements
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: unlocked.map((a) => _AchievementBadge(achievement: a)).toList(),
          ),
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'À débloquer',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontFamily: 'Inter',
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: locked.map((a) => _AchievementBadge(achievement: a)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final color = _getTierColor(achievement.tier);

    return Tooltip(
      message: achievement.description,
      child: Container(
        width: 60,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: achievement.isUnlocked 
              ? color.withValues(alpha: 0.15) 
              : NeonColors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: achievement.isUnlocked ? color : NeonColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getAchievementIcon(achievement.icon),
              color: achievement.isUnlocked ? color : NeonColors.textSecondary.withValues(alpha: 0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: achievement.isUnlocked ? color : NeonColors.textSecondary,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === RECENT GAMES ===

class _RecentGamesSection extends StatelessWidget {
  final List<RecentGame> games;

  const _RecentGamesSection({required this.games});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: NeonColors.info, size: 22),
              SizedBox(width: 8),
              Text(
                'PARTIES RÉCENTES',
                style: TextStyle(
                  color: NeonColors.textPrimary,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...games.map((game) => _RecentGameTile(game: game)),
        ],
      ),
    );
  }
}

class _RecentGameTile extends StatelessWidget {
  final RecentGame game;

  const _RecentGameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final isWin = game.result == 'win';
    final color = isWin ? NeonColors.success : NeonColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeonCard(
        child: Row(
          children: [
            // Result icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(
                isWin ? Icons.check : Icons.close,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Game info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isWin ? 'Victoire' : 'Défaite',
                        style: TextStyle(
                          color: color,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (game.predictedSum != null && game.actualSum != null)
                        Text(
                          'Préd: ${game.predictedSum} → Réel: ${game.actualSum}',
                          style: const TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 10,
                            fontFamily: 'Inter',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(game.playedAt),
                    style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isWin ? '+' : '-'}${_formatTokens(game.betAmount.toInt())}',
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isWin && game.winnings > 0)
                  Text(
                    '+${_formatTokens(game.winnings.toInt())} gagné',
                    style: const TextStyle(
                      color: NeonColors.success,
                      fontSize: 9,
                      fontFamily: 'Inter',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === ACTIONS ===

class _ProfileActions extends ConsumerWidget {
  final UserProfile profile;

  const _ProfileActions({required this.profile});

  void _performLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: const Text('Déconnexion', style: TextStyle(color: NeonColors.textPrimary)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: TextStyle(color: NeonColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                _showLogoutAnimation(context);
              }
            },
            child: const Text('Déconnexion', style: TextStyle(color: NeonColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutAnimation(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, _, __) => const Scaffold(
        backgroundColor: Color(0xFF0A0A1A),
        body: Center(
          child: SuccessAnimation(
            message: 'Déconnecté',
            subtitle: 'À bientôt sur WIWIGA !',
            duration: Duration(milliseconds: 1200),
          ),
        ),
      ),
      transitionDuration: Duration.zero,
    );
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      context.go('/auth');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          NeonCard(
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.edit,
                  title: 'Modifier le profil',
                  color: NeonColors.primary,
                  onTap: () {},
                ),
                _ActionDivider(),
                _ActionTile(
                  icon: Icons.receipt_long,
                  title: 'Historique complet',
                  color: NeonColors.info,
                  onTap: () {},
                ),
                _ActionDivider(),
                _ActionTile(
                  icon: Icons.security,
                  title: 'Sécurité',
                  color: NeonColors.warning,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NeonButton(
            text: 'DÉCONNEXION',
            onPressed: () => _performLogout(context, ref),
            variant: NeonButtonVariant.danger,
            icon: Icons.logout,
            width: double.infinity,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'WIWIGA v1.0.0',
              style: TextStyle(
                color: NeonColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: NeonColors.textPrimary,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: NeonColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Divider(color: NeonColors.border.withValues(alpha: 0.3), height: 1),
  );
}

// === HELPERS ===

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

Color _getTierColor(String tier) {
  switch (tier) {
    case 'diamond': return NeonColors.rankDiamond;
    case 'gold': return NeonColors.rankGold;
    case 'silver': return NeonColors.rankSilver;
    case 'bronze': return NeonColors.rankBronze;
    default: return NeonColors.textSecondary;
  }
}

IconData _getAchievementIcon(String icon) {
  switch (icon) {
    case 'emoji_events': return Icons.emoji_events;
    case 'local_fire_department': return Icons.local_fire_department;
    case 'attach_money': return Icons.attach_money;
    case 'military_tech': return Icons.military_tech;
    case 'diamond': return Icons.diamond;
    case 'workspace_premium': return Icons.workspace_premium;
    default: return Icons.star;
  }
}

String _formatTokens(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]} ',
  );
}

String _formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

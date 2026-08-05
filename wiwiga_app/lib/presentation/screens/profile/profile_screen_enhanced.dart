import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/auth/avatar_picker.dart';
import '../../widgets/profile/avatar_picker_sheet.dart';
import '../../widgets/profile/profile_edit_sheet.dart';

/// Écran Profil amélioré avec données réelles du backend
class ProfileScreenEnhanced extends ConsumerStatefulWidget {
  const ProfileScreenEnhanced({super.key});

  @override
  ConsumerState<ProfileScreenEnhanced> createState() =>
      _ProfileScreenEnhancedState();
}

class _ProfileScreenEnhancedState
    extends ConsumerState<ProfileScreenEnhanced> {
  @override
  void initState() {
    super.initState();
    // Charger le profil au démarrage
    Future.microtask(() {
      ref.read(userProfileProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider);
    final authUser = ref.watch(authProvider).user;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barre de navigation avec bouton retour
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: NeonColors.primary),
                    tooltip: 'Retour',
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'MON PROFIL',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: NeonColors.textSecondary, size: 22),
                    tooltip: 'Paramètres',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profileState.isLoading && profileState.profile == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: NeonColors.primary,
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Header avec avatar et rang
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      authUser: authUser,
                      profile: profileState.profile,
                    ),
                  ),
                  // Stats rapides
                  SliverToBoxAdapter(
                    child: _QuickStats(profile: profileState.profile),
                  ),
                  // XP Bar
                  SliverToBoxAdapter(
                    child: _XpBar(profile: profileState.profile),
                  ),
                  // Achievements
                  SliverToBoxAdapter(
                    child: _AchievementsSection(
                      achievements: profileState.achievements,
                    ),
                  ),
                  // Actions
                  const SliverToBoxAdapter(
                    child: _ProfileActions(),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === HEADER ===

class _ProfileHeader extends ConsumerWidget {
  final UserModel? authUser;
  final UserProfile? profile;

  const _ProfileHeader({this.authUser, this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankTier = profile?.rankTier ?? 'bronze';
    final username = authUser?.username ?? profile?.username ?? 'Joueur';
    final phone = authUser?.phone ?? profile?.phone ?? '';
    final isVerified = authUser?.isActive ?? profile?.isVerified ?? false;
    final balance = authUser?.tokenBalance ?? profile?.balance.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRankColor(rankTier).withValues(alpha: 0.3),
            NeonColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Avatar + rang
          GestureDetector(
            onTap: () => AvatarPickerSheet.show(context).then((result) {
              if (result == true) {
                ref.read(authProvider.notifier).refreshProfile();
              }
            }),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AvatarDisplay(
                  avatarType: authUser?.avatarType ?? AvatarType.defaultAvatar,
                  avatarUrl: authUser?.avatarUrl,
                  username: username,
                  size: 100,
                  borderColor: _getRankColor(rankTier),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeonColors.background,
                  ),
                  child: RankBadge(
                    rank: profile?.rankLabel ?? 'Bronze',
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Username (tappable)
          GestureDetector(
            onTap: () => ProfileEditSheet.show(context).then((result) {
              if (result == true) {
                ref.read(authProvider.notifier).refreshProfile();
              }
            }),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NeonColors.textPrimary,
                    fontFamily: 'Orbitron',
                  ),
                ),
                const SizedBox(width: 8),
                if (isVerified)
                  const Icon(Icons.verified,
                      color: NeonColors.info, size: 20,),
                const SizedBox(width: 4),
                const Icon(Icons.edit,
                    color: NeonColors.textMuted, size: 14,),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Phone
          Text(
            phone,
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
              const Icon(Icons.monetization_on,
                  color: NeonColors.success, size: 18,),
              const SizedBox(width: 6),
              Text(
                _formatTokens(balance),
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
  final UserProfile? profile;

  const _QuickStats({this.profile});

  @override
  Widget build(BuildContext context) {
    final gamesPlayed = profile?.gamesPlayed ?? 0;
    final wins = profile?.wins ?? 0;
    final winRate = profile?.winRate ?? 0;
    final currentStreak = profile?.currentStreak ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: NeonCard(
        child: Row(
          children: [
            _StatMini(
              value: '$gamesPlayed',
              label: 'Parties',
              color: NeonColors.primary,
            ),
            _Divider(),
            _StatMini(
              value: '$wins',
              label: 'Victoires',
              color: NeonColors.success,
            ),
            _Divider(),
            _StatMini(
              value: '${winRate.toStringAsFixed(0)}%',
              label: 'Win Rate',
              color: winRate >= 50 ? NeonColors.success : NeonColors.error,
            ),
            _Divider(),
            _StatMini(
              value: '$currentStreak',
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
        width: 1,
        height: 30,
        color: NeonColors.border,
      );
}

// === XP BAR ===

class _XpBar extends StatelessWidget {
  final UserProfile? profile;

  const _XpBar({this.profile});

  @override
  Widget build(BuildContext context) {
    final xpPoints = profile?.xpPoints ?? 0;
    final rankTier = profile?.rankTier ?? 'bronze';
    final xpForNextLevel = _xpForNextRank(rankTier);
    final xpProgress = (xpPoints / xpForNextLevel).clamp(0.0, 1.0);

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
                  'XP: $xpPoints',
                  style: const TextStyle(
                    color: NeonColors.primary,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Prochain: ${rankTier == 'diamond' ? 'MAX' : _nextRankLabel(rankTier)}',
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
                  _getRankColor(rankTier),
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

    if (achievements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: NeonCard(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events,
                      color: NeonColors.textMuted, size: 32,),
                  const SizedBox(height: 8),
                  Text(
                    'Jouez pour débloquer des achievements !',
                    style: TextStyle(
                      color: NeonColors.textSecondary.withValues(alpha: 0.7),
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: NeonColors.rankGold, size: 22,),
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                unlocked.map((a) => _AchievementBadge(achievement: a)).toList(),
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
              children:
                  locked.map((a) => _AchievementBadge(achievement: a)).toList(),
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
              color: achievement.isUnlocked
                  ? color
                  : NeonColors.textSecondary.withValues(alpha: 0.5),
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
                color: achievement.isUnlocked
                    ? color
                    : NeonColors.textSecondary,
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

// === ACTIONS ===

class _ProfileActions extends ConsumerWidget {
  const _ProfileActions();

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
                  onTap: () {
                    ProfileEditSheet.show(context).then((result) {
                      if (result == true) {
                        ref.read(authProvider.notifier).refreshProfile();
                      }
                    });
                  },
                ),
                _ActionDivider(),
                _ActionTile(
                  icon: Icons.monetization_on_outlined,
                  title: 'Mes jetons',
                  subtitle: 'Solde et transactions',
                  color: NeonColors.success,
                  onTap: () => context.push('/tokens'),
                ),
                _ActionDivider(),
                _ActionTile(
                  icon: Icons.receipt_long,
                  title: 'Historique',
                  subtitle: 'Toutes les transactions',
                  color: NeonColors.info,
                  onTap: () => context.push('/transactions'),
                ),
              ],
            ),
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
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: NeonColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: NeonColors.textSecondary, size: 20,),
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
        child: Divider(
            color: NeonColors.border.withValues(alpha: 0.3), height: 1,),
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

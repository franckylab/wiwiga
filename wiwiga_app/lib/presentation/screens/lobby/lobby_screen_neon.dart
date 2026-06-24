import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/neon_theme.dart';
import '../../core/theme/typography.dart';
import '../widgets/neon/neon_widgets.dart';
import '../providers/config_provider.dart';

/// Écran Lobby redesigné avec style néon gaming
class LobbyScreenNeon extends ConsumerWidget {
  const LobbyScreenNeon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(themeConfigProvider);
    final featureConfig = ref.watch(featureConfigProvider);
    final isMaintenance = ref.watch(isMaintenanceActiveProvider);

    // Vérifier maintenance
    if (isMaintenance) {
      return _MaintenanceScreen(featureConfig: featureConfig);
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header avec balance
            SliverToBoxAdapter(
              child: _HeaderSection(),
            ),
            
            // Section Jeux disponibles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JEUX DISPONIBLES',
                      style: AppTypography.heading3,
                    ),
                    const SizedBox(height: 16),
                    _GameGrid(),
                  ],
                ),
              ),
            ),
            
            // Section Statistiques rapides
            SliverToBoxAdapter(
              child: _QuickStatsSection(),
            ),
            
            // Footer
            SliverToBoxAdapter(
              child: _FooterSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: NeonGradients.cta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Row(
                children: [
                  Icon(
                    Icons.gamepad,
                    color: NeonColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WIWIGA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.primary,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),
              
              // Boutons profil et notifications
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: NeonColors.primary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.account_circle_outlined, color: NeonColors.primary),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Balance
          BalanceDisplay(
            balanceCentimes: 250000, // 2,500 FCFA
            fontSize: 36,
            showLabel: true,
            onTap: () {
              // Naviguer vers wallet
            },
          ),
          
          const SizedBox(height: 16),
          
          // Boutons d'action rapide
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'DÉPOSER',
                  onPressed: () {},
                  variant: NeonButtonVariant.success,
                  icon: Icons.add,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonButton(
                  text: 'RETIRER',
                  onPressed: () {},
                  variant: NeonButtonVariant.outline,
                  icon: Icons.remove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final games = [
      {
        'name': 'Jeu de Dés',
        'icon': Icons.casino,
        'minBet': '100 FCFA',
        'players': '1,234',
        'status': GameStatus.inProgress,
      },
      {
        'name': 'Poker',
        'icon': Icons.play_card,
        'minBet': '500 FCFA',
        'players': '856',
        'status': GameStatus.waiting,
      },
      {
        'name': 'Blackjack',
        'icon': Icons.auto_awesome,
        'minBet': '200 FCFA',
        'players': '642',
        'status': GameStatus.inProgress,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _GameCardWidget(game: game);
      },
    );
  }
}

class _GameCardWidget extends StatelessWidget {
  final Map<String, dynamic> game;

  const _GameCardWidget({required this.game});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      onTap: () {
        // Naviguer vers le jeu
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône du jeu
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: NeonColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              game['icon'] as IconData,
              size: 48,
              color: NeonColors.primary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Nom du jeu
          Text(
            game['name'] as String,
            style: AppTypography.heading4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 8),
          
          // Statut
          GameStatusIndicator(
            status: game['status'] as GameStatus,
          ),
          
          const Spacer(),
          
          // Infos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${game['minBet']}',
                style: TextStyle(
                  color: NeonColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              Text(
                '${game['players']} joueurs',
                style: TextStyle(
                  color: NeonColors.textSecondary,
                  fontSize: 12,
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

class _QuickStatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VOS STATISTIQUES',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.emoji_events,
                    label: 'Victoires',
                    value: '47',
                    color: NeonColors.success,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.trending_up,
                    label: 'Win Rate',
                    value: '62%',
                    color: NeonColors.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.local_fire_department,
                    label: 'Série',
                    value: '5',
                    color: NeonColors.secondary,
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Divider(color: NeonColors.border),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FooterButton(icon: Icons.help_outline, label: 'Aide'),
              _FooterButton(icon: Icons.rule, label: 'Règles'),
              _FooterButton(icon: Icons.support_agent, label: 'Support'),
              _FooterButton(icon: Icons.history, label: 'Historique'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '© 2026 WIWIGA - Tous droits réservés',
            style: TextStyle(
              color: NeonColors.textSecondary.withOpacity(0.5),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: NeonColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: NeonColors.primary,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final AsyncValue featureConfig;

  const _MaintenanceScreen({required this.featureConfig});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: NeonColors.secondary,
              ),
              const SizedBox(height: 24),
              Text(
                'MAINTENANCE',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.secondary,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'WIWIGA est actuellement en maintenance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 32),
              NeonButton(
                text: 'RÉESSAYER',
                onPressed: () {},
                variant: NeonButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

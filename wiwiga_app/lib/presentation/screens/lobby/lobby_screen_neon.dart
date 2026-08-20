import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../providers/config_provider.dart';
import '../../../data/providers/token_provider.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../../data/models/game_model.dart';

/// Écran Lobby redesigné avec style néon gaming
class LobbyScreenNeon extends ConsumerWidget {
  const LobbyScreenNeon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      decoration: const BoxDecoration(
        gradient: NeonGradients.cta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              const Row(
                children: [
                  WiwigaLogo(
                    variant: LogoVariant.icon,
                    size: 32,
                  ),
                  SizedBox(width: 8),
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
                    icon: const Icon(Icons.notifications_outlined, color: NeonColors.primary),
                    onPressed: () => context.push('/settings'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined, color: NeonColors.primary),
                    onPressed: () => context.push('/profile'),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Solde Jetons
          _TokenBalanceWidget(),
          
          const SizedBox(height: 16),
          
          // Boutons d'action rapide
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'ACHETER',
                  onPressed: () => context.push('/tokens'),
                  variant: NeonButtonVariant.success,
                  icon: Icons.shopping_cart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonButton(
                  text: 'ÉCHANGER',
                  onPressed: () => context.push('/tokens'),
                  variant: NeonButtonVariant.outline,
                  icon: Icons.swap_horiz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenBalanceWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);
    final tokens = tokenState.tokenBalance;
    final fcfa = tokenState.monetaryValueFcfa;

    return GestureDetector(
      onTap: () {
        // Naviguer vers wallet
      },
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TokenIcon(size: 24, variant: TokenVariant.normal, animated: true),
              const SizedBox(width: 8),
              Text(
                tokens.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (m) => '${m[1]} ',
                ),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.textPrimary,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          Text(
            'JETONS  •  ≈ ${fcfa.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              fontSize: 12,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(gamesCatalogProvider);

    return catalogAsync.when(
      data: (games) {
        if (games.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun jeu disponible', style: TextStyle(color: NeonColors.textSecondary)),
            ),
          );
        }
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
            return _GameCardWidget(gameModel: game);
          },
        );
      },
      loading: () => const NeonLoadingSpinner.center(),
      error: (error, _) => const Center(
        child: Text('Erreur de chargement', style: TextStyle(color: NeonColors.error)),
      ),
    );
  }
}

class _GameCardWidget extends StatelessWidget {
  final GameModel gameModel;

  const _GameCardWidget({required this.gameModel});

  @override
  Widget build(BuildContext context) {
    // Icône selon le type de jeu
    final gameIcon = switch (gameModel.type) {
      'dice' => Icons.casino,
      'cards' => Icons.style,
      _ => Icons.games,
    };

    return NeonCard(
      onTap: () {
        if (gameModel.comingSoon) return;
        context.push('/games/${gameModel.type}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: gameModel.comingSoon
                  ? NeonColors.textSecondary.withValues(alpha: 0.1)
                  : NeonColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  gameIcon,
                  size: 48,
                  color: gameModel.comingSoon ? NeonColors.textSecondary : NeonColors.primary,
                ),
                if (gameModel.comingSoon)
                  const Text('Bientôt', style: TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            gameModel.name,
            style: AppTypography.heading4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          GameStatusIndicator(
            status: gameModel.comingSoon ? GameStatus.comingSoon : GameStatus.inProgress,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${gameModel.minBet.toInt()} jetons',
                style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12, fontFamily: 'Inter'),
              ),
              Text(
                gameModel.playersOnline > 0
                    ? '${gameModel.playersOnline} en ligne'
                    : '${gameModel.maxPlayers} max',
                style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12, fontFamily: 'Inter'),
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
            const Row(
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
          style: const TextStyle(
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
          const Row(
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
              color: NeonColors.textSecondary.withValues(alpha: 0.5),
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

  void _onTap(BuildContext context) {
    switch (label) {
      case 'Aide':
        _showHelpDialog(context);
      case 'Règles':
        _showRulesDialog(context);
      case 'Support':
        _showSupportDialog(context);
      case 'Historique':
        context.push('/transactions');
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Centre d\'aide', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bienvenue dans l\'aide WIWIGA !\n\n'
          '• Pour jouer, créez ou rejoignez une partie\n'
          '• Gérez vos jetons dans le Wallet\n'
          '• Invitez des amis et jouez ensemble\n'
          '• Consultez les règles de chaque jeu\n\n'
          'Contact: support@wiwiga.cm',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Règles des jeux', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🎲 Dés', style: TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('Lancez les dés, le plus haut score gagne !\nMisez des jetons et affrontez vos amis.', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
            SizedBox(height: 16),
            Text('♟️ Ludo', style: TextStyle(color: NeonColors.secondary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('Course stratégique jusqu\'à l\'arrivée.\nBloquez vos adversaires et atteignez le premier la ligne.', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
            SizedBox(height: 16),
            Text('🃏 Cartes', style: TextStyle(color: NeonColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('Variantes multiples de jeux de cartes.\nStratégie et bluff au programme !', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          ],),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Support', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Besoin d\'aide ?', style: TextStyle(color: NeonColors.textSecondary)),
          SizedBox(height: 16),
          Row(children: [
            Icon(Icons.email, color: NeonColors.primary, size: 20),
            SizedBox(width: 8),
            Text('support@wiwiga.cm', style: TextStyle(color: NeonColors.textPrimary)),
          ],),
          SizedBox(height: 12),
          Row(children: [
            Icon(Icons.phone, color: NeonColors.primary, size: 20),
            SizedBox(width: 8),
            Text('+237 6XX XXX XXX', style: TextStyle(color: NeonColors.textPrimary)),
          ],),
        ],),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _onTap(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: NeonColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
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
              const Icon(
                Icons.construction,
                size: 80,
                color: NeonColors.secondary,
              ),
              const SizedBox(height: 24),
              const Text(
                'MAINTENANCE',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.secondary,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
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
                onPressed: () => context.go('/home'),
                variant: NeonButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

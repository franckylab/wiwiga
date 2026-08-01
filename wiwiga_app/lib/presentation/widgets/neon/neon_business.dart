import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/neon_theme.dart';
import 'token_icon.dart';

/// Affichage du solde en jetons avec animation compteur et glow
/// 
/// Remplace l'ancien BalanceDisplay (centimes FCFA) par un affichage
/// base sur les jetons WIWIGA.
class TokenBalanceDisplay extends StatefulWidget {
  final int tokenBalance;
  final double fontSize;
  final bool showLabel;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool animated;

  const TokenBalanceDisplay({
    super.key,
    required this.tokenBalance,
    this.fontSize = 36,
    this.showLabel = true,
    this.onTap,
    this.isLoading = false,
    this.animated = true,
  });

  @override
  State<TokenBalanceDisplay> createState() => _TokenBalanceDisplayState();
}

class _TokenBalanceDisplayState extends State<TokenBalanceDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: NeonGlow.opacityLow,
      end: NeonGlow.opacityHigh,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTokens(int tokens) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return formatter.format(tokens);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: widget.fontSize + 10,
            decoration: BoxDecoration(
              color: NeonColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TokenIcon(
                    size: widget.fontSize * 0.7,
                    variant: TokenVariant.normal,
                    animated: widget.animated,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTokens(widget.tokenBalance),
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.primary,
                      fontFamily: 'Orbitron',
                      shadows: [
                        Shadow(
                          color: NeonColors.primary.withValues(alpha: _glowAnimation.value),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 4),
                const Text(
                  'Jetons disponibles',
                  style: TextStyle(
                    fontSize: 14,
                    color: NeonColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Alias pour compatibilite - affiche le solde en jetons
/// @deprecated Utiliser [TokenBalanceDisplay] a la place
class BalanceDisplay extends StatelessWidget {
  final int balanceCentimes;
  final double fontSize;
  final bool showLabel;
  final VoidCallback? onTap;
  final bool isLoading;

  const BalanceDisplay({
    super.key,
    required this.balanceCentimes,
    this.fontSize = 36,
    this.showLabel = true,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert centimes to approximate tokens (1 FCFA = 10 tokens, 1 FCFA = 100 centimes)
    final tokens = (balanceCentimes / 100 * 10).round();
    return TokenBalanceDisplay(
      tokenBalance: tokens,
      fontSize: fontSize,
      showLabel: showLabel,
      onTap: onTap,
      isLoading: isLoading,
    );
  }
}


/// Badge de rang/niveau avec couleur spécifique
class RankBadge extends StatelessWidget {
  final String rank;
  final double size;

  const RankBadge({
    super.key,
    required this.rank,
    this.size = 60,
  });

  Color get _rankColor {
    switch (rank.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'argent':
        return const Color(0xFFC0C0C0);
      case 'or':
        return NeonColors.secondary;
      case 'platine':
        return const Color(0xFFE5E4E2);
      case 'diamant':
        return NeonColors.accent;
      default:
        return NeonColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _rankColor,
            _rankColor.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _rankColor.withValues(alpha: NeonGlow.opacityMedium),
            blurRadius: NeonGlow.blurMedium,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          rank.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: NeonColors.background,
            fontFamily: 'Orbitron',
          ),
        ),
      ),
    );
  }
}


/// Indicateur de statut de jeu avec couleur et icône
class GameStatusIndicator extends StatelessWidget {
  final GameStatus status;
  final String? customText;

  const GameStatusIndicator({
    super.key,
    required this.status,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final icon = _statusIcon;
    final text = customText ?? _statusText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: NeonGlow.opacityMedium),
                blurRadius: NeonGlow.blurSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Color get _statusColor {
    switch (status) {
      case GameStatus.waiting:
        return NeonColors.secondary;
      case GameStatus.inProgress:
        return NeonColors.primary;
      case GameStatus.finished:
        return NeonColors.accent;
      case GameStatus.cancelled:
        return NeonColors.danger;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case GameStatus.waiting:
        return Icons.hourglass_empty;
      case GameStatus.inProgress:
        return Icons.play_circle_filled;
      case GameStatus.finished:
        return Icons.check_circle;
      case GameStatus.cancelled:
        return Icons.cancel;
    }
  }

  String get _statusText {
    switch (status) {
      case GameStatus.waiting:
        return 'En attente';
      case GameStatus.inProgress:
        return 'En cours';
      case GameStatus.finished:
        return 'Terminé';
      case GameStatus.cancelled:
        return 'Annulé';
    }
  }
}

enum GameStatus {
  waiting,
  inProgress,
  finished,
  cancelled,
}

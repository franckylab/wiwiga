import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/neon_theme.dart';
import 'token_coin.dart';

/// Affichage du solde en wiga avec animation compteur et glow
/// 
/// Remplace l'ancien BalanceDisplay (centimes FCFA) par un affichage
/// base sur les wiga WIWIGA.
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
    final formatter = (() { try { return NumberFormat('#,##0', 'fr_FR'); } catch (_) { return NumberFormat.decimalPattern(); } })();
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
                  TokenCoin(
                    size: widget.fontSize * 0.7,
                    metal: TokenMetal.emerald,
                    lod: TokenCoin.autoLod(widget.fontSize * 0.7),
                    effect: widget.animated ? TokenEffect.pulse : TokenEffect.none,
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
                  'Wiga disponibles',
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

/// Alias pour compatibilite - affiche le solde en wiga
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
    // Convert centimes to wiga (1 FCFA = 1 wiga, 1 FCFA = 100 centimes)
    final tokens = (balanceCentimes / 100).round();
    return TokenBalanceDisplay(
      tokenBalance: tokens,
      fontSize: fontSize,
      showLabel: showLabel,
      onTap: onTap,
      isLoading: isLoading,
    );
  }
}


/// Badge de rang/niveau avec pièce 3D métal
class RankBadge extends StatelessWidget {
  final String rank;
  final double size;

  const RankBadge({
    super.key,
    required this.rank,
    this.size = 60,
  });

  TokenMetal get _metal {
    switch (rank.toLowerCase()) {
      case 'bronze':
        return TokenMetal.bronze;
      case 'argent':
        return TokenMetal.silver;
      case 'or':
        return TokenMetal.gold;
      case 'platine':
        return TokenMetal.silver;
      case 'diamant':
        return TokenMetal.holographic;
      default:
        return TokenMetal.emerald;
    }
  }

  String get _label {
    switch (rank.toLowerCase()) {
      case 'bronze':
        return '3';
      case 'argent':
        return '2';
      case 'or':
        return '1';
      case 'platine':
        return 'P';
      case 'diamant':
        return 'D';
      default:
        return rank.isNotEmpty ? rank.substring(0, 1).toUpperCase() : '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTopRank = ['or', 'argent', 'bronze'].contains(rank.toLowerCase());
    return TokenCoin(
      size: size,
      metal: _metal,
      lod: TokenCoin.autoLod(size),
      effect: isTopRank ? TokenEffect.shimmer : TokenEffect.none,
      animated: isTopRank,
      rankLabel: _label,
      withW: false,
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
      case GameStatus.comingSoon:
        return NeonColors.textSecondary;
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
      case GameStatus.comingSoon:
        return Icons.event_note;
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
      case GameStatus.comingSoon:
        return 'Bientôt disponible';
    }
  }
}

enum GameStatus {
  waiting,
  inProgress,
  finished,
  cancelled,
  comingSoon,
}

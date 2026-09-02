// ============================================================
// Fichier: token_chip.dart
// Description: Chip de mise selectable (preset pari)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/neon_theme.dart';
import 'token_coin.dart';

/// Chip de mise — preset cliquable avec pièce 3D intégrée
///
/// Utilisé dans CreateGame (presets) et GameDetail (sélecteur mise).
/// Gère selected / disabled / haptic + animations GPU-only.
class TokenChip extends StatefulWidget {
  final int amount;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;
  final double size;
  final TokenMetal metal;

  const TokenChip({
    super.key,
    required this.amount,
    this.isSelected = false,
    this.isEnabled = true,
    this.onTap,
    this.size = 44,
    this.metal = TokenMetal.emerald,
  });

  @override
  State<TokenChip> createState() => _TokenChipState();
}

class _TokenChipState extends State<TokenChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.isSelected) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant TokenChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isEnabled) return;
    HapticFeedback.lightImpact();
    // flip micro-animation via controller
    _ctrl.forward().then((_) {
      if (!widget.isSelected) _ctrl.reverse();
    });
    widget.onTap?.call();
  }

  String _format(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final metal = widget.isSelected
        ? (widget.amount >= 5000 ? TokenMetal.gold : TokenMetal.emerald)
        : widget.metal;

    final chip = AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        final s = reduceMotion ? 1.0 : _scaleAnim.value;
        return Transform.scale(
          scale: s,
          child: child,
        );
      },
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (metal == TokenMetal.gold
                    ? NeonColors.tokenGold.withValues(alpha: 0.14)
                    : NeonColors.primary.withValues(alpha: 0.14))
                : NeonColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? (metal == TokenMetal.gold
                      ? NeonColors.tokenGold
                      : NeonColors.primary)
                  : NeonColors.border,
              width: widget.isSelected ? 1.6 : 1.0,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: (metal == TokenMetal.gold
                              ? NeonColors.tokenGold
                              : NeonColors.primary)
                          .withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TokenCoin(
                size: widget.size * 0.58,
                metal: metal,
                lod: TokenCoin.autoLod(widget.size * 0.58),
                effect:
                    widget.isSelected ? TokenEffect.pulse : TokenEffect.none,
                animated: widget.isSelected,
                showShadow: false,
              ),
              const SizedBox(width: 6),
              Text(
                _format(widget.amount),
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontWeight:
                      widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  color: widget.isSelected
                      ? (metal == TokenMetal.gold
                          ? NeonColors.tokenGold
                          : NeonColors.primary)
                      : NeonColors.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'wiga',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  color: widget.isSelected
                      ? (metal == TokenMetal.gold
                          ? NeonColors.tokenGold.withValues(alpha: 0.92)
                          : NeonColors.primary.withValues(alpha: 0.92))
                      : NeonColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.isEnabled) {
      return Opacity(opacity: 0.46, child: chip);
    }

    return GestureDetector(
      onTap: _handleTap,
      child: chip,
    );
  }
}

/// Groupe de chips — wrap responsive pour presets
class TokenChipGroup extends StatelessWidget {
  final List<int> amounts;
  final int selectedAmount;
  final ValueChanged<int> onSelected;
  final double chipSize;

  const TokenChipGroup({
    super.key,
    required this.amounts,
    required this.selectedAmount,
    required this.onSelected,
    this.chipSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts.map((a) {
        return TokenChip(
          amount: a,
          isSelected: a == selectedAmount,
          onTap: () => onSelected(a),
          size: chipSize,
        );
      }).toList(),
    );
  }
}

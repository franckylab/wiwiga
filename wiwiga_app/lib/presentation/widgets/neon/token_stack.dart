// ============================================================
// Fichier: token_stack.dart
// Description: Pile de wiga 3D (pot / cagnotte)
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'token_coin.dart';

/// Pile de wiga — pot / cagnotte
///
/// Affiche [count] pièces décalées en Z avec ombre empilée.
/// Utilisé dans DiceMatch (pot) et Wallet (aperçu).
class TokenStack extends StatelessWidget {
  final int count;
  final double size;
  final TokenMetal metal;
  final TokenMetal? altMetal;
  final bool animated;
  final TokenEffect effect;

  const TokenStack({
    super.key,
    required this.count,
    this.size = 44,
    this.metal = TokenMetal.emerald,
    this.altMetal,
    this.animated = false,
    this.effect = TokenEffect.none,
  });

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(1, 12);
    final stepY = (size * 0.16).clamp(5.0, 10.0);
    final totalH = size + (n - 1) * stepY + 8;

    return SizedBox(
      width: size * 1.32,
      height: totalH,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Ombre au sol qui s'épaissit
          Positioned(
            bottom: 0,
            child: Container(
              width: size * (0.72 + n * 0.04).clamp(0.72, 1.0),
              height: size * 0.18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: (0.18 + n * 0.02).clamp(0.18, 0.32)),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          for (int i = 0; i < n; i++)
            Positioned(
              bottom: 4 + i * stepY,
              child: _StackCoin(
                size: size - i * 0.45,
                metal: altMetal != null && i.isOdd ? altMetal! : metal,
                index: i,
                animated: animated,
                effect: effect,
              ),
            ),
        ],
      ),
    );
  }
}

class _StackCoin extends StatelessWidget {
  final double size;
  final TokenMetal metal;
  final int index;
  final bool animated;
  final TokenEffect effect;

  const _StackCoin({
    required this.size,
    required this.metal,
    required this.index,
    required this.animated,
    required this.effect,
  });

  @override
  Widget build(BuildContext context) {
    final eff = animated && effect == TokenEffect.none ? TokenEffect.float : effect;
    // Décalage horizontal subtil pour effet naturel
    final dx = (index % 3 == 1 ? 1.2 : index % 3 == 2 ? -1.0 : 0.0);
    return Transform.translate(
      offset: Offset(dx, 0),
      child: TokenCoin(
        size: size,
        metal: metal,
        lod: TokenCoin.autoLod(size),
        effect: index == 0 ? eff : TokenEffect.none,
        animated: index == 0 && (animated || eff != TokenEffect.none),
        showShadow: false,
      ),
    );
  }
}

/// Pile animée avec drop — ajoute un wiga qui tombe
class AnimatedTokenStack extends StatefulWidget {
  final int count;
  final double size;
  final TokenMetal metal;
  final TokenMetal? altMetal;

  const AnimatedTokenStack({
    super.key,
    required this.count,
    this.size = 44,
    this.metal = TokenMetal.emerald,
    this.altMetal,
  });

  @override
  State<AnimatedTokenStack> createState() => _AnimatedTokenStackState();
}

class _AnimatedTokenStackState extends State<AnimatedTokenStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _dropCtrl;
  late Animation<double> _dropAnim;
  int _displayCount = 0;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.count;
    _dropCtrl = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _dropAnim = CurvedAnimation(parent: _dropCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant AnimatedTokenStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _displayCount = widget.count;
      _dropCtrl.forward(from: 0);
    } else if (widget.count != oldWidget.count) {
      setState(() => _displayCount = widget.count);
    }
  }

  @override
  void dispose() {
    _dropCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _displayCount.clamp(1, 12);
    final isDropping = _dropCtrl.isAnimating && _displayCount > 1;

    return SizedBox(
      width: widget.size * 1.32,
      height: widget.size + (n - 1) * widget.size * 0.16 + 8,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: widget.size * 0.82,
              height: widget.size * 0.18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          for (int i = 0; i < n; i++)
            if (!(isDropping && i == n - 1))
              Positioned(
                bottom: 4 + i * widget.size * 0.16,
                child: TokenCoin(
                  size: widget.size - i * 0.45,
                  metal: widget.altMetal != null && i.isOdd ? widget.altMetal! : widget.metal,
                  showShadow: false,
                ),
              ),
          if (isDropping)
            AnimatedBuilder(
              animation: _dropAnim,
              builder: (context, _) {
                final t = _dropAnim.value;
                // chute -40 → 0 + rotation 8° →0
                final dy = (1 - t) * -42;
                final rot = (1 - t) * 0.14;
                final i = n - 1;
                return Positioned(
                  bottom: 4 + i * widget.size * 0.16 - dy,
                  child: Transform.rotate(
                    angle: rot,
                    child: TokenCoin(
                      size: widget.size - i * 0.45,
                      metal: widget.altMetal != null && i.isOdd ? widget.altMetal! : widget.metal,
                      showShadow: false,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'token_coin.dart';

/// Alias de compatibilité — redirige vers TokenCoin 3D
///
/// Conservé pour éviter tout breaking change. Utiliser directement
/// [TokenCoin] pour les nouveaux écrans.
/// Mapping : normal/small → emerald, gold → gold, silver → silver.
class TokenIcon extends StatelessWidget {
  final double size;
  final TokenVariant variant;
  final bool animated;

  const TokenIcon({
    super.key,
    this.size = 24,
    this.variant = TokenVariant.normal,
    this.animated = false,
  });

  TokenMetal get _metal {
    switch (variant) {
      case TokenVariant.normal:
      case TokenVariant.small:
        return TokenMetal.emerald;
      case TokenVariant.gold:
        return TokenMetal.gold;
      case TokenVariant.silver:
        return TokenMetal.silver;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TokenCoin(
      size: size,
      metal: _metal,
      lod: TokenCoin.autoLod(size),
      effect: animated ? TokenEffect.pulse : TokenEffect.none,
      animated: animated,
      showShadow: size >= 20,
    );
  }
}

enum TokenVariant {
  normal,   // Emeraude neon → TokenMetal.emerald
  gold,     // Dore premium → TokenMetal.gold
  silver,   // Argent → TokenMetal.silver
  small,    // Reduit inline → emerald flat
}

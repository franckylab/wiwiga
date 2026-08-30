import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import '../neon/token_coin.dart';
import '../neon/wiwiga_loader.dart';

/// Ecran de chargement WIWIGA avec animation de wiga tournant
/// 
/// Variantes :
/// - [inline] : Petit spinner pour sections
/// - [overlay] : Overlay semi-transparent
/// - [fullscreen] : Plein ecran avec logo
class WiwigaLoading extends StatelessWidget {
  final LoadingVariant variant;
  final String? message;
  final Color? color;

  const WiwigaLoading({
    super.key,
    this.variant = LoadingVariant.fullscreen,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case LoadingVariant.inline:
        return _buildInline();
      case LoadingVariant.overlay:
        return _buildOverlay();
      case LoadingVariant.fullscreen:
        return _buildFullscreen();
    }
  }

  Widget _buildInline() {
    // LJ sans cadre — W cœur battant seul (inline 20)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WiwigaLoader(size: 20, withFrame: false, color: color),
        if (message != null) ...[
          const SizedBox(width: 8),
          Text(
            message!,
            style: TextStyle(
              color: color ?? NeonColors.textSecondary,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverlay() {
    // LJ avec cadre — overlay 48 (dual light + heart)
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: NeonColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (color ?? NeonColors.primary).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: (color ?? NeonColors.primary).withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WiwigaLoader(size: 48, withFrame: true, color: color),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreen() {
    // LJ avec cadre — fullscreen 96 (dual light + heartDouble) + progress
    return Container(
      decoration: const BoxDecoration(
        gradient: NeonGradients.splash,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loader LJ avec cadre — splash/PWA
            WiwigaLoader(size: 96, withFrame: true, color: color),
            const SizedBox(height: 32),
            // Message
            Text(
              message ?? 'Chargement...',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 14,
                fontFamily: 'Inter',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            // Barre de progression
            const _NeonProgressBar(),
          ],
        ),
      ),
    );
  }
}

enum LoadingVariant { inline, overlay, fullscreen }

/// Wiga en rotation pour les loaders
class _SpinningToken extends StatefulWidget {
  final double size;
  final Color? color;

  const _SpinningToken({required this.size, this.color});

  @override
  State<_SpinningToken> createState() => _SpinningTokenState();
}

class _SpinningTokenState extends State<_SpinningToken>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: TokenCoin(
        size: widget.size,
        metal: widget.color != null ? TokenMetal.gold : TokenMetal.emerald,
        lod: TokenCoin.autoLod(widget.size),
        effect: TokenEffect.spin,
        animated: true,
      ),
    );
  }
}

/// Barre de progression neon
class _NeonProgressBar extends StatefulWidget {
  const _NeonProgressBar();

  @override
  State<_NeonProgressBar> createState() => _NeonProgressBarState();
}

class _NeonProgressBarState extends State<_NeonProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 4,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: NeonColors.surface,
                ),
                child: Align(
                  alignment: Alignment(
                    _controller.value * 2 - 1,
                    0,
                  ),
                  child: Container(
                    width: constraints.maxWidth * 0.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          NeonColors.primary.withValues(alpha: 0),
                          NeonColors.primary,
                          NeonColors.tokenGold,
                          NeonColors.primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import '../neon/token_icon.dart';
import '../neon/wiwiga_logo.dart';

/// Ecran de chargement WIWIGA avec animation de jeton tournant
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpinningToken(size: 20, color: color),
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
              _SpinningToken(size: 48, color: color),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: NeonGradients.splash,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo anime
            const WiwigaLogo(
              variant: LogoVariant.icon,
              size: 80,
              animated: true,
            ),
            const SizedBox(height: 32),
            // Spinner
            _SpinningToken(size: 40, color: color),
            const SizedBox(height: 24),
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

/// Jeton en rotation pour les loaders
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
      child: TokenIcon(
        size: widget.size,
        variant: widget.color != null ? TokenVariant.gold : TokenVariant.normal,
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

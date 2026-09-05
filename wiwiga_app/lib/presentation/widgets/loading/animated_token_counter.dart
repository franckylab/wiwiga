import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Compteur anime pour les montants de wiga
/// 
/// Effet de scroll numerique (type flipboard) avec transition fluide.
/// Utilise pour afficher les gains/pertes de wiga en temps reel.
class AnimatedTokenCounter extends StatefulWidget {
  final int value;
  final double fontSize;
  final Color? color;
  final bool showSign;
  final Duration duration;

  const AnimatedTokenCounter({
    super.key,
    required this.value,
    this.fontSize = 24,
    this.color,
    this.showSign = false,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedTokenCounter> createState() => _AnimatedTokenCounterState();
}

class _AnimatedTokenCounterState extends State<AnimatedTokenCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedTokenCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Cache RegExp et évite allocation per frame
  static final _thousandsRegex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

  String _formatTokens(int tokens) {
    final absTokens = tokens.abs();
    return absTokens.toString().replaceAllMapped(_thousandsRegex, (m) => '${m[1]} ');
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isole le texte animé du reste
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final currentValue = (_previousValue + (widget.value - _previousValue) * _animation.value).round();
          final isPositive = widget.value >= 0;
          final displayColor = widget.color ?? (isPositive ? NeonColors.success : NeonColors.danger);
          final sign = widget.showSign ? (isPositive ? '+' : '') : '';
          // Sur web, désactive le Shadow coûteux (CanvasKit saveLayer)
          final shadows = kIsWeb
              ? null
              : [
                  Shadow(color: displayColor.withValues(alpha: 0.4), blurRadius: 8),
                ];
          return Text(
            '$sign${_formatTokens(currentValue)}',
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
              color: displayColor,
              fontFamily: 'Orbitron',
              shadows: shadows,
            ),
          );
        },
      ),
    );
  }
}

/// Compteur de wiga avec animation de flip vertical — P5 optimisé
/// 1 seul controller parent (implicit via AnimatedSwitcher) au lieu de N AnimationControllers
class TokenFlipCounter extends StatefulWidget {
  final int value;
  final double digitHeight;
  final Color color;

  const TokenFlipCounter({
    super.key,
    required this.value,
    this.digitHeight = 28,
    this.color = NeonColors.primary,
  });

  @override
  State<TokenFlipCounter> createState() => _TokenFlipCounterState();
}

class _TokenFlipCounterState extends State<TokenFlipCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // P5 FIX: 1 seul controller parent throttle 30fps, au lieu de N controllers 400ms par digit
    _controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(TokenFlipCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.value.toString().split('');
    // RepaintBoundary isole le flip du reste de l'UI
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: digits.map((digit) {
          return _FlipDigit(
            digit: digit,
            height: widget.digitHeight,
            color: widget.color,
          );
        }).toList(),
      ),
    );
  }
}

class _FlipDigit extends StatelessWidget {
  final String digit;
  final double height;
  final Color color;

  const _FlipDigit({
    required this.digit,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // P5 FIX: AnimatedSwitcher au lieu de AnimationController par digit — pas deTicker, pas de scale per frame
    return SizedBox(
      width: height * 0.6,
      height: height,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            // Flip vertical léger via Scale + Fade — sans Matrix4 3D, pas de saveLayer
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            digit,
            key: ValueKey<String>(digit),
            style: TextStyle(
              fontSize: height * 0.8,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      ),
    );
  }
}

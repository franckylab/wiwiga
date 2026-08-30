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

  String _formatTokens(int tokens) {
    final absTokens = tokens.abs();
    return absTokens
        .toString()
        .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ',);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentValue = (_previousValue +
                (widget.value - _previousValue) * _animation.value)
            .round();

        final isPositive = widget.value >= 0;
        final displayColor = widget.color ??
            (isPositive ? NeonColors.success : NeonColors.danger);

        final sign = widget.showSign
            ? (isPositive ? '+' : '')
            : '';

        return Text(
          '$sign${_formatTokens(currentValue)}',
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: displayColor,
            fontFamily: 'Orbitron',
            shadows: [
              Shadow(
                color: displayColor.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compteur de wiga avec animation de flip vertical
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

class _TokenFlipCounterState extends State<TokenFlipCounter> {
  @override
  Widget build(BuildContext context) {
    final digits = widget.value.toString().split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: digits.map((digit) {
        return _FlipDigit(
          digit: digit,
          height: widget.digitHeight,
          color: widget.color,
        );
      }).toList(),
    );
  }
}

class _FlipDigit extends StatefulWidget {
  final String digit;
  final double height;
  final Color color;

  const _FlipDigit({
    required this.digit,
    required this.height,
    required this.color,
  });

  @override
  State<_FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<_FlipDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  String _displayDigit = '0';

  @override
  void initState() {
    super.initState();
    _displayDigit = widget.digit;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _controller.reset();
      setState(() => _displayDigit = widget.digit);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        // Simule un flip vertical avec scale
        final scale = 1.0 - (_flipAnimation.value - 0.5).abs() * 0.3;
        return Transform.scale(
          scaleY: scale,
          child: SizedBox(
            width: widget.height * 0.6,
            height: widget.height,
            child: Center(
              child: Text(
                _displayDigit,
                style: TextStyle(
                  fontSize: widget.height * 0.8,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                  fontFamily: 'Orbitron',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

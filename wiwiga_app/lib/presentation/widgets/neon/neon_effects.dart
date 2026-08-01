import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Badge lumineux avec animation de pulsation
class GlowBadge extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const GlowBadge({
    super.key,
    required this.text,
    this.color = NeonColors.primary,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  @override
  State<GlowBadge> createState() => _GlowBadgeState();
}

class _GlowBadgeState extends State<GlowBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: _opacityAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _opacityAnimation.value * 0.5),
                blurRadius: NeonGlow.blurSmall,
              ),
            ],
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'Orbitron',
            ),
          ),
        );
      },
    );
  }
}


/// Loader avec effet shimmer animé
class ShimmerLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const ShimmerLoader({
    super.key,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -2,
      end: 2,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 0.5, 0),
              colors: [
                NeonColors.surface,
                NeonColors.surface.withValues(alpha: 0.5),
                NeonColors.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Modal néon avec backdrop blur et bordure lumineuse
class NeonModal {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    String? barrierLabel,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      barrierLabel: barrierLabel,
      isDismissible: barrierDismissible,
      builder: (context) => _NeonModalContent(child: child),
    );
  }
}

class _NeonModalContent extends StatelessWidget {
  final Widget child;

  const _NeonModalContent({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeonColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NeonTheme.borderRadius * 2),
        ),
        border: const Border(
          top: BorderSide(
            color: NeonColors.primary,
            width: NeonGlow.borderWidthThick,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: NeonColors.primary.withValues(alpha: NeonGlow.opacityMedium),
            blurRadius: NeonGlow.blurMedium,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

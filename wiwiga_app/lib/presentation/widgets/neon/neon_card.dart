import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Carte néon avec effets de glow au hover et animations
/// 
/// Utilisée pour les conteneurs de contenu, game cards, etc.
class NeonCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isEnabled;
  final Gradient? gradient;
  final Widget? header;
  final Widget? footer;

  const NeonCard({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.isEnabled = true,
    this.gradient,
    this.header,
    this.footer,
  });

  @override
  State<NeonCard> createState() => _NeonCardState();
}

class _NeonCardState extends State<NeonCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: NeonAnimations.transition,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),);

    _glowAnimation = Tween<double>(
      begin: NeonGlow.opacityLow,
      end: NeonGlow.opacityMedium,
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
    final isInteractive = widget.onTap != null && widget.isEnabled;

    return MouseRegion(
      onEnter: (_) {
        if (isInteractive) {
          setState(() => _isHovered = true);
          _controller.forward();
        }
      },
      onExit: (_) {
        if (isInteractive) {
          setState(() => _isHovered = false);
          _controller.reverse();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Cache colors to avoid withValues allocation per frame when not hovered
              final glowAlpha = _glowAnimation.value;
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.width,
                  decoration: BoxDecoration(
                    gradient: widget.gradient ?? NeonGradients.card,
                    color: NeonColors.surface,
                    borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
                    border: Border.all(
                      color: NeonColors.primary.withValues(alpha: glowAlpha),
                      width: _isHovered ? NeonGlow.borderWidthThick : NeonGlow.borderWidth,
                    ),
                    boxShadow: [
                      if (_isHovered)
                        BoxShadow(
                          color: NeonColors.primary.withValues(alpha: glowAlpha),
                          blurRadius: NeonGlow.blurMedium,
                          spreadRadius: 2,
                        ),
                      // Static shadow, const where possible
                      const BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            // Static child cached, not rebuilt per frame
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) ...[
                  widget.header!,
                  const Divider(color: NeonColors.border, height: 1),
                ],
                Padding(
                  padding: widget.padding,
                  child: widget.child,
                ),
                if (widget.footer != null) ...[
                  const Divider(color: NeonColors.border, height: 1),
                  widget.footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

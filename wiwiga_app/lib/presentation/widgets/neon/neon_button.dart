import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Bouton néon avec effets de glow et animations
/// 
/// Variantes : primary, secondary, danger, success, outline
class NeonButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final NeonButtonVariant variant;
  final double? width;
  final double height;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const NeonButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.variant = NeonButtonVariant.primary,
    this.width,
    this.height = 52,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  }) : super(key: key);

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

enum NeonButtonVariant {
  primary,
  secondary,
  danger,
  success,
  outline,
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: NeonAnimations.micro,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (!widget.isEnabled) return NeonColors.surface.withOpacity(0.3);
    
    switch (widget.variant) {
      case NeonButtonVariant.primary:
        return NeonColors.primary;
      case NeonButtonVariant.secondary:
        return NeonColors.secondary;
      case NeonButtonVariant.danger:
        return NeonColors.danger;
      case NeonButtonVariant.success:
        return NeonColors.success;
      case NeonButtonVariant.outline:
        return Colors.transparent;
    }
  }

  Color get _textColor {
    if (!widget.isEnabled) return NeonColors.textSecondary;
    
    switch (widget.variant) {
      case NeonButtonVariant.outline:
        return _borderColor;
      default:
        return NeonColors.background;
    }
  }

  Color get _borderColor {
    if (!widget.isEnabled) return NeonColors.border;
    
    switch (widget.variant) {
      case NeonButtonVariant.primary:
        return NeonColors.primary;
      case NeonButtonVariant.secondary:
        return NeonColors.secondary;
      case NeonButtonVariant.danger:
        return NeonColors.danger;
      case NeonButtonVariant.success:
        return NeonColors.success;
      case NeonButtonVariant.outline:
        return NeonColors.primary;
    }
  }

  double get _glowOpacity {
    if (!widget.isEnabled) return 0.0;
    if (_isPressed) return NeonGlow.opacityHigh;
    if (_isHovered) return NeonGlow.opacityMedium;
    return NeonGlow.opacityLow;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() {
          _isPressed = true;
          _controller.forward();
        }),
        onTapUp: (_) => setState(() {
          _isPressed = false;
          _controller.reverse();
        }),
        onTapCancel: () => setState(() {
          _isPressed = false;
          _controller.reverse();
        }),
        onTap: widget.isEnabled && !widget.isLoading ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: NeonAnimations.standard,
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
                  border: widget.variant == NeonButtonVariant.outline
                      ? Border.all(color: _borderColor, width: NeonGlow.borderWidth)
                      : null,
                  boxShadow: [
                    if (_glowOpacity > 0)
                      BoxShadow(
                        color: _borderColor.withOpacity(_glowOpacity),
                        blurRadius: _isHovered ? NeonGlow.blurMedium : NeonGlow.blurSmall,
                        spreadRadius: _isHovered ? 2 : 0,
                      ),
                  ],
                ),
                padding: widget.padding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_textColor),
                        ),
                      )
                    else ...[
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: _textColor, size: widget.fontSize + 2),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

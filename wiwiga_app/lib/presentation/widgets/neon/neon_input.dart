import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/neon_theme.dart';

/// Champ de saisie néon avec effets de glow au focus
/// 
/// Supporte texte, password, email, nombre, etc.
class NeonInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? icon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;
  final String? errorText;

  const NeonInput({
    Key? key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.icon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
    this.errorText,
  }) : super(key: key);

  @override
  State<NeonInput> createState() => _NeonInputState();
}

class _NeonInputState extends State<NeonInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _obscureText = widget.obscureText;

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: NeonAnimations.standard,
          decoration: BoxDecoration(
            color: NeonColors.surface,
            borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
            border: Border.all(
              color: _isFocused
                  ? NeonColors.primary
                  : widget.errorText != null
                      ? NeonColors.danger
                      : NeonColors.border,
              width: _isFocused ? NeonGlow.borderWidthThick : NeonGlow.borderWidth,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: NeonColors.primary.withOpacity(NeonGlow.opacityMedium),
                  blurRadius: NeonGlow.blurSmall,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: _obscureText,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontSize: 16,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: NeonColors.textSecondary.withOpacity(0.5),
                fontFamily: 'Inter',
              ),
              prefixIcon: widget.icon != null
                  ? Icon(widget.icon, color: NeonColors.primary)
                  : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: NeonColors.primary,
                      ),
                      onPressed: () {
                        setState(() => _obscureText = !_obscureText);
                      },
                    )
                  : widget.suffixIcon != null
                      ? IconButton(
                          icon: Icon(widget.suffixIcon, color: NeonColors.primary),
                          onPressed: widget.onSuffixIconTap,
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              counterText: widget.maxLength != null ? '' : null,
              errorText: widget.errorText,
              errorStyle: const TextStyle(
                color: NeonColors.danger,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: NeonColors.danger,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ],
    );
  }
}

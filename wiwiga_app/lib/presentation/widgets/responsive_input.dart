// ============================================================
// Fichier: responsive_input.dart
// Description: Champ de saisie responsive avec label et icône
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/responsive_builder.dart';

/// Champ de saisie responsive pour WIWIGA
class ResponsiveInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  
  const ResponsiveInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.onTap,
    this.readOnly = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final config = ResponsiveConfig.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: config.fontSizeSmall,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        
        SizedBox(height: config.spacingSmall),
        
        // Champ de saisie
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          onTap: onTap,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: config.fontSize,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, size: config.iconSize)
                : null,
            counterText: '', // Cache le compteur
          ),
        ),
      ],
    );
  }
}

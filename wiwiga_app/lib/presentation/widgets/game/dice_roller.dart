// ============================================================
// Fichier: dice_roller.dart
// Description: Widget réutilisable pour l'animation de lancer de dés
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Widget de dé individuel avec animation de lancer
class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  final bool isActive;
  final Color? borderColor;

  const DiceFace({
    super.key,
    required this.value,
    this.size = 64,
    this.isActive = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? (isActive ? NeonColors.primary : NeonColors.border);
    final glowColor = isActive ? NeonColors.primary.withValues(alpha: 0.3) : Colors.transparent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(size * 0.19),
        border: Border.all(color: color, width: isActive ? 2 : 1),
        boxShadow: isActive ? [BoxShadow(color: glowColor, blurRadius: 8)] : null,
      ),
      child: Center(
        child: value == 0
            ? Icon(Icons.casino, color: NeonColors.textSecondary, size: size * 0.5)
            : Text(
                '$value',
                style: TextStyle(
                  color: isActive ? NeonColors.primary : NeonColors.textPrimary,
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// Widget d'animation de lancer de dés
///
/// Affiche [diceCount] dés avec animation de rotation pendant le lancer.
/// Utilise crypto-safe random pour le résultat final.
class DiceRoller extends StatefulWidget {
  /// Nombre de dés à afficher
  final int diceCount;

  /// Callback appelé quand le lancer est terminé, avec la liste des valeurs
  final void Function(List<int> results)? onRollComplete;

  /// Taille de chaque dé
  final double diceSize;

  /// Couleur de bordure des dés actifs
  final Color? activeColor;

  const DiceRoller({
    super.key,
    required this.diceCount,
    this.onRollComplete,
    this.diceSize = 64,
    this.activeColor,
  });

  @override
  State<DiceRoller> createState() => _DiceRollerState();
}

class _DiceRollerState extends State<DiceRoller> with TickerProviderStateMixin {
  late AnimationController _animController;
  List<int> _diceValues = [];
  bool _isRolling = false;
  final Random _secureRandom = Random.secure();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    // Initialiser avec des dés vides
    _diceValues = List.filled(widget.diceCount, 0);
  }

  @override
  void didUpdateWidget(DiceRoller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diceCount != widget.diceCount) {
      _diceValues = List.filled(widget.diceCount, 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get isRolling => _isRolling;
  List<int> get currentValues => List.unmodifiable(_diceValues);

  /// Démarre l'animation de lancer et génère le résultat final
  void roll() {
    if (_isRolling) return;
    setState(() => _isRolling = true);

    _animController.forward(from: 0);

    // Animation : valeurs aléatoires rapides
    final random = Random();
    int animCount = 0;
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        timer?.cancel();
        return;
      }
      setState(() {
        _diceValues = List.generate(widget.diceCount, (_) => random.nextInt(6) + 1);
      });
      animCount++;
      if (animCount >= 8) {
        timer?.cancel();
        _finalizeRoll();
      }
    });
  }

  void _finalizeRoll() {
    // Résultat final crypto-safe
    final results = List.generate(widget.diceCount, (_) => _secureRandom.nextInt(6) + 1);

    setState(() {
      _diceValues = results;
      _isRolling = false;
    });

    widget.onRollComplete?.call(results);
  }

  /// Réinitialise les dés à l'état vide
  void reset() {
    setState(() {
      _diceValues = List.filled(widget.diceCount, 0);
      _isRolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: _diceValues.asMap().entries.map((entry) {
        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Effet de scale pendant l'animation
            final scale = _isRolling ? 0.9 + (0.1 * _animController.value) : 1.0;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: DiceFace(
            value: entry.value,
            size: widget.diceSize,
            isActive: !_isRolling && entry.value > 0,
            borderColor: widget.activeColor,
          ),
        );
      }).toList(),
    );
  }
}

/// Widget d'affichage de la somme des dés
class DiceSum extends StatelessWidget {
  final int sum;
  final String? label;

  const DiceSum({
    super.key,
    required this.sum,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: NeonColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Text(label!, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
          Text(
            '$sum',
            style: const TextStyle(
              color: NeonColors.accent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

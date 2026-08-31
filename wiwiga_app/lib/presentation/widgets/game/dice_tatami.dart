// ============================================================
// Fichier: dice_tatami.dart
// Description: Tatami / Table centrale où les dés sont lancés
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'dice_3d.dart';

/// Tatami central — surface de jeu texturée (bois + feutre) avec rebords néon
class DiceTatami extends StatefulWidget {
  final List<int> diceValues;
  final bool isRolling;
  final bool showEmpty;
  final int diceCount;
  final double maxWidth;
  final String? targetLabel; // pour mode cible
  final int? lastSum;
  final VoidCallback? onTap; // pour debug
  final Widget? overlay; // overlay victoire/défaite

  const DiceTatami({
    super.key,
    this.diceValues = const [],
    this.isRolling = false,
    this.showEmpty = true,
    this.diceCount = 2,
    this.maxWidth = 340,
    this.targetLabel,
    this.lastSum,
    this.onTap,
    this.overlay,
  });

  @override
  State<DiceTatami> createState() => _DiceTatamiState();
}

class _DiceTatamiState extends State<DiceTatami> with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = math.min(widget.maxWidth, constraints.maxWidth * 0.92);
        final h = w * 0.72;
        return Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, child) {
                final glow = 0.18 + _glowCtrl.value * 0.14;
                return Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: NeonColors.primary.withValues(alpha: glow), blurRadius: 22, spreadRadius: 1),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: child,
                );
              },
              child: Stack(
                children: [
                  // Cadre bois extérieur
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3A2416), Color(0xFF5A3520), Color(0xFF2B1A0F)],
                      ),
                      border: Border.all(color: const Color(0xFF6B3A20), width: 3),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF8B5A2B).withValues(alpha: 0.5), width: 1),
                      ),
                      // Feutre intérieur
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          children: [
                            // Base feutre avec texture
                            Container(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 1.1,
                                  colors: [Color(0xFF0F3D2E), Color(0xFF0A2E22), Color(0xFF082419)],
                                ),
                              ),
                            ),
                            // Grille tatami subtile
                            CustomPaint(size: Size(w, h), painter: _TatamiPainter()),
                            // Vignette intérieure
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                gradient: RadialGradient(
                                  center: Alignment.center, radius: 0.9,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
                                  stops: const [0.7, 1.0],
                                ),
                              ),
                            ),
                            // Bordure intérieure néon
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: NeonColors.primary.withValues(alpha: 0.22), width: 1),
                              ),
                            ),
                            // Contenu central: dés
                            Center(child: _buildDiceContent(w)),
                            // Overlay cible / somme
                            if (widget.targetLabel != null)
                              Positioned(
                                top: 8, left: 0, right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NeonColors.secondary.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: NeonColors.secondary.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(widget.targetLabel!, style: const TextStyle(color: NeonColors.secondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                  ),
                                ),
                              ),
                            // Somme en bas
                            if (widget.lastSum != null && !widget.isRolling)
                              Positioned(
                                bottom: 8, left: 0, right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NeonColors.primary.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: NeonColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Text('SOMME ${widget.lastSum}', style: const TextStyle(color: NeonColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontFamily: 'Orbitron')),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Overlay externe si victoire/défaite
                  if (widget.overlay != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.32),
                          child: Center(child: widget.overlay),
                        ),
                      ),
                    ),
                  // Étoiles décoratives coins
                  Positioned(top: 10, left: 10, child: _cornerStar()),
                  Positioned(top: 10, right: 10, child: _cornerStar()),
                  Positioned(bottom: 10, left: 10, child: _cornerStar()),
                  Positioned(bottom: 10, right: 10, child: _cornerStar()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cornerStar() => Icon(Icons.star_rounded, size: 10, color: NeonColors.primary.withValues(alpha: 0.45));

  Widget _buildDiceContent(double w) {
    final dice = widget.diceValues.isEmpty && widget.showEmpty
        ? List<int>.filled(widget.diceCount, 0)
        : widget.diceValues;

    // Si rolling, afficher animation avec valeurs aléatoires fluctuantes
    if (widget.isRolling) {
      return DiceGroup3D(values: dice.isEmpty ? List.filled(widget.diceCount, 3) : dice, isRolling: true, diceSize: w * 0.15);
    }

    if (dice.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino_outlined, size: w * 0.14, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(height: 6),
          Text('En attente du lancer', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, letterSpacing: 0.6)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiceGroup3D(values: dice, isRolling: false, diceSize: w * 0.15),
        if (dice.any((v) => v > 0) && widget.lastSum == null) ...[
          const SizedBox(height: 8),
          Text(
            '= ${dice.where((v) => v > 0).fold<int>(0, (a, b) => a + b)}',
            style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _TatamiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    // Lignes horizontales tatami
    for (double y = size.height * 0.22; y < size.height; y += size.height * 0.21) {
      canvas.drawLine(Offset(size.width * 0.06, y), Offset(size.width * 0.94, y), p);
    }
    // Points de couture
    final dotPaint = Paint()..color = NeonColors.primary.withValues(alpha: 0.10);
    for (double x = size.width * 0.18; x < size.width; x += size.width * 0.28) {
      for (double y = size.height * 0.18; y < size.height; y += size.height * 0.21) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Petit tatami compact pour mini-prévisualisation
class MiniTatami extends StatelessWidget {
  final List<int> dice;
  final double size;
  const MiniTatami({super.key, required this.dice, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 2.2, height: size * 1.4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(colors: [Color(0xFF0F3D2E), Color(0xFF0A2E22)]),
        border: Border.all(color: NeonColors.primary.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: NeonColors.primary.withValues(alpha: 0.12), blurRadius: 6)],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: dice.map((v) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Dice3D(value: v, size: size * 0.42, borderColor: NeonColors.primary.withValues(alpha: 0.6)),
          )).toList(),
        ),
      ),
    );
  }
}

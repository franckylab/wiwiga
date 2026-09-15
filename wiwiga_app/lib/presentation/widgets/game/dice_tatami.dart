// ============================================================
// Fichier: dice_tatami.dart
// Description: Tatami / Table centrale où les dés sont lancés
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'dice3d/dice_3d.dart' show DiceBoard3D;
import 'dice3d/dice_controller.dart' show Dice3DController;
import 'dice3d/dice_pips.dart' show DicePips;
import 'dice3d/dice_theme.dart' show DiceTheme;

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

  /// Contrôleurs du nouveau moteur physique (optionnel).
  /// Quand fourni et non vide, le tatami affiche [DiceBoard3D]
  /// (tumbling physique + snap exact face serveur) au lieu de l'ancien
  /// DiceGroup3D. Piloté par l'écran via roll/retarget/setRestingFace.
  final List<Dice3DController>? controllers;

  /// Durée d'animation 3D par dé (ms) : synchronisée sur le délai serveur
  /// `roll_reveal_delay_ms` par l'écran — l'anim se termine toujours avant
  /// la révélation numérique (jamais de somme pendant le tumbling).
  /// Clamp 600..2400, défaut 1600 (moteur physique historique).
  final int animationDurationMs;

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
    this.controllers,
    this.animationDurationMs = 1600,
  });

  @override
  State<DiceTatami> createState() => _DiceTatamiState();
}

class _DiceTatamiState extends State<DiceTatami>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;

  // Cache couleurs web pour éviter withValues per frame
  static final Color _glowBase = NeonColors.primary.withValues(alpha: 0.22);
  static final Color _blackShadow = Colors.black.withValues(alpha: 0.45);

  @override
  void initState() {
    super.initState();
    _glowCtrl =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    // Sur web on désactive le ticker si pas visible / hors viewport — ici on
    // évite le coûteux repeat 2s en mode web (glow statique).
    if (!kIsWeb) {
      _glowCtrl.repeat(reverse: true);
    }
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
        // Extract child stack to avoid rebuilding it per glow tick
        final content = Stack(
          children: [
            // Cadre bois extérieur
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3A2416),
                    Color(0xFF5A3520),
                    Color(0xFF2B1A0F),
                  ],
                ),
                border: Border.all(color: const Color(0xFF6B3A20), width: 3),
              ),
              padding: const EdgeInsets.all(7),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF8B5A2B).withValues(alpha: 0.5),
                    width: 1,
                  ),
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
                            colors: [
                              Color(0xFF0F3D2E),
                              Color(0xFF0A2E22),
                              Color(0xFF082419),
                            ],
                          ),
                        ),
                      ),
                      // Grille tatami subtile — painter léger, shouldRepaint false
                      RepaintBoundary(
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _TatamiPainter(),
                          isComplex: false,
                          willChange: false,
                        ),
                      ),
                      // Vignette intérieure
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.22),
                            ],
                            stops: const [0.7, 1.0],
                          ),
                        ),
                      ),
                      // Bordure intérieure néon
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: NeonColors.primary.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                      ),
                      // Contenu central: dés
                      Center(child: _buildDiceContent(w)),
                      // Overlay cible / somme
                      if (widget.targetLabel != null)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: NeonColors.secondary
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: NeonColors.secondary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                widget.targetLabel!,
                                style: const TextStyle(
                                  color: NeonColors.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Somme en bas : cercle numérique unique, animé.
                      // Pourquoi un cercle : un seul point focal épuré (pas de
                      // pill « SOMME » + « = X » en double), visible sans
                      // masquer les faces finales des dés au centre.
                      if (widget.lastSum != null && !widget.isRolling)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: TatamiResultBadge(
                              key: ValueKey('tatami_sum_${widget.lastSum}'),
                              value: widget.lastSum!,
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
        );

        // P1 FIX: Sur web, glow statique (pas de AnimatedBuilder 2s), blur 22→6, RepaintBoundary
        // Sur mobile, AnimatedBuilder conservé mais encapsulé en RepaintBoundary + couleurs cachées
        final Widget glowWrapper;
        if (kIsWeb) {
          glowWrapper = RepaintBoundary(
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _glowBase,
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: _blackShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: content,
            ),
          );
        } else {
          glowWrapper = RepaintBoundary(
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
                      BoxShadow(
                        color: NeonColors.primary.withValues(alpha: glow),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: _blackShadow,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: content,
            ),
          );
        }

        return Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: glowWrapper,
          ),
        );
      },
    );
  }

  Widget _cornerStar() => Icon(
        Icons.star_rounded,
        size: 10,
        color: NeonColors.primary.withValues(alpha: 0.45),
      );

  Widget _buildDiceContent(double w) {
    // Nouveau moteur physique : autonome (tumbling + snap serveur),
    // piloté par l'écran. Le flag isRolling ne le concerne pas.
    // La somme est affichée UNE fois, en cercle en bas du tatami
    // (TatamiResultBadge) — jamais en double sous les dés.
    final diceControllers = widget.controllers;
    if (diceControllers != null && diceControllers.isNotEmpty) {
      return DiceBoard3D(
        controllers: diceControllers,
        diceSize: w * 0.15,
        duration: Duration(
          milliseconds: widget.animationDurationMs.clamp(600, 2400),
        ),
      );
    }

    // Repli sans contrôleurs (hors match, préviews) : faces statiques
    // serveur, AUCUNE animation ni RNG (règle n°2).
    final dice = widget.diceValues.isEmpty && widget.showEmpty
        ? List<int>.filled(widget.diceCount, 0)
        : widget.diceValues;

    if (dice.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.casino_outlined,
            size: w * 0.14,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 6),
          Text(
            'En attente du lancer',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      );
    }

    // Repli sans contrôleurs : faces statiques serveur uniquement.
    // La somme passe par TatamiResultBadge (bas du tatami) — aucun doublon.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dice
          .map(
            (v) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: DicePips(value: v, size: w * 0.15),
            ),
          )
          .toList(),
    );
  }
}

/// Résultat numérique du tatami : cercle unique, épuré, animé.
/// Pourquoi un widget dédié : un seul point focal (chiffre seul, Orbitron),
/// entrance scale + fondu (300ms, `Curves.easeOutBack`), halo glow néon et
/// anneau extérieur subtil — lisible sans masquer les faces finales des dés.
/// Couleurs UNIQUEMENT depuis [NeonColors] (conforme design system WIWIGA).
class TatamiResultBadge extends StatefulWidget {
  /// Somme à afficher (chiffre seul, jamais de préfixe « SOMME »).
  final int value;

  /// Diamètre du cercle (responsive : l'appelant adapte au tatami).
  final double size;

  const TatamiResultBadge({super.key, required this.value, this.size = 52});

  @override
  State<TatamiResultBadge> createState() => _TatamiResultBadgeState();
}

class _TatamiResultBadgeState extends State<TatamiResultBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    // Pulse doux continu (glow 0.25 → 0.45) : feedback vivant sans ticker
    // coûteux — sur web, glow statique (pas de repeat, cf. DiceTatami).
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    if (!kIsWeb) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Entrance rejouée à chaque nouvelle somme (clé par valeur côté parent) :
    // scale 0.6 → 1.0 + fondu, 300ms standard WIWIGA.
    return Semantics(
      label: 'Résultat : ${widget.value}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Opacity(
            opacity: ((scale - 0.6) / 0.4).clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: kIsWeb ? _buildBadge(0.35) : _buildPulseBadge(),
      ),
    );
  }

  Widget _buildPulseBadge() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = 0.25 + _pulseCtrl.value * 0.2;
        return _buildBadge(glow);
      },
    );
  }

  Widget _buildBadge(double glowOpacity) {
    final d = widget.size;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NeonColors.surface,
        border: Border.all(color: NeonColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: NeonColors.primary.withValues(alpha: glowOpacity),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneau intérieur subtil (profondeur, sans gradient).
          Container(
            width: d - 10,
            height: d - 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: NeonColors.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
          Text(
            '${widget.value}',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontSize: d * 0.38,
              fontWeight: FontWeight.w900,
              fontFamily: 'Orbitron',
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: NeonColors.primary.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
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
    for (double y = size.height * 0.22;
        y < size.height;
        y += size.height * 0.21) {
      canvas.drawLine(
        Offset(size.width * 0.06, y),
        Offset(size.width * 0.94, y),
        p,
      );
    }
    // Points de couture
    final dotPaint = Paint()
      ..color = NeonColors.primary.withValues(alpha: 0.10);
    for (double x = size.width * 0.18; x < size.width; x += size.width * 0.28) {
      for (double y = size.height * 0.18;
          y < size.height;
          y += size.height * 0.21) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Petit tatami compact pour mini-prévisualisation (faces statiques serveur).
class MiniTatami extends StatelessWidget {
  final List<int> dice;
  final double size;
  const MiniTatami({super.key, required this.dice, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 2.2,
      height: size * 1.4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3D2E), Color(0xFF0A2E22)],
        ),
        border: Border.all(color: NeonColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: NeonColors.primary.withValues(alpha: 0.12),
            blurRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: dice
              .map(
                (v) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DicePips(
                    value: v,
                    size: size * 0.42,
                    theme: DiceTheme.miniPreview,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

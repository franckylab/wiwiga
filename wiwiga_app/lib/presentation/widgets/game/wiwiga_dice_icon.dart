// ============================================================
// WIWIGA - Icône 3D du Jeu de Dés
// Design exclusif Wiwiga : relief, ombre, luminosité, faces
// Auteur : WIWIGA Team - 2026-09-18
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Icône 3D premium du jeu de dés — unique Wiwiga
/// - Cube isométrique avec relief extrudé
/// - Face avant en dégradé perle + reflets
/// - Faces latérales en perspective pour 3D
/// - Ombre portée douce + lueur néon Wiwiga
/// - Points en creux avec ombre interne
class WiwigaDiceIcon extends StatelessWidget {
  final double size;
  final bool animated;
  final bool withShadow;
  final double? elevation;

  const WiwigaDiceIcon({
    super.key,
    this.size = 52,
    this.animated = false,
    this.withShadow = true,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final s = size;
    final face = s * 0.68;
    final depth = s * 0.18;
    final radius = s * 0.14;

    Widget dice = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Ombre portée au sol (elliptique)
        if (withShadow)
          Positioned(
            bottom: -s * 0.06,
            child: Container(
              width: face * 0.95,
              height: s * 0.14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(face * 0.5),
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        // Corps 3D : faces latérales + avant
        SizedBox(
          width: face + depth * 0.9,
          height: face + depth * 0.9,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Face droite (perspective)
              Positioned(
                left: face * 0.72,
                top: depth * 0.35,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(0.55),
                  child: Container(
                    width: face * 0.52,
                    height: face * 0.88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(radius * 0.7),
                        bottomRight: Radius.circular(radius * 0.7),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F3A2E), Color(0xFF0A2A1F)],
                      ),
                      border: Border.all(
                          color: const Color(0xFF1A5C4A).withValues(alpha: 0.9),
                          width: 1.1),
                    ),
                  ),
                ),
              ),

              // Face haute (perspective)
              Positioned(
                left: depth * 0.35,
                top: 0,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(0.55),
                  child: Container(
                    width: face * 0.88,
                    height: face * 0.52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(radius * 0.7),
                        topRight: Radius.circular(radius * 0.7),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF14B8A6), Color(0xFF0D7A6E)],
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1),
                    ),
                  ),
                ),
              ),

              // Face avant principale — perle Wiwiga avec relief
              Positioned(
                left: 0,
                top: depth * 0.52,
                child: Container(
                  width: face,
                  height: face,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF8FAFC),
                        Color(0xFFE2E8F0),
                        Color(0xFFCBD5E1)
                      ],
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.18),
                          blurRadius: s * 0.18,
                          offset: Offset(0, s * 0.08)),
                      BoxShadow(
                          color: NeonColors.primary.withValues(alpha: 0.18),
                          blurRadius: s * 0.22,
                          spreadRadius: 0),
                      BoxShadow(
                          color: Colors.white.withValues(alpha: 0.55),
                          blurRadius: 1,
                          offset: const Offset(-1, -1)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius - 1),
                    child: Stack(
                      children: [
                        // Reflet glossy haut
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: face * 0.32,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.62),
                                  Colors.transparent
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Points en creux — face 5 (Wiwiga signature : 5 points en croix)
                        Center(child: _FiveFace(face: face)),

                        // Ombre interne basse
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: face * 0.18,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.transparent
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Liseré néon Wiwiga en bas
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 2.2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                NeonColors.primary,
                                NeonColors.accent
                              ]),
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(radius)),
                            ),
                          ),
                        ),

                        // Petit "W" discret en haut-droite (marque)
                        Positioned(
                          top: face * 0.06,
                          right: face * 0.08,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: NeonColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: NeonColors.primary
                                      .withValues(alpha: 0.35),
                                  width: 0.7),
                            ),
                            child: const Text('W',
                                style: TextStyle(
                                    color: NeonColors.primary,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    fontFamily: 'Orbitron')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Arête brillante 3D
              Positioned(
                left: face * 0.02,
                top: depth * 0.52 + 1,
                child: Container(
                  width: 1.2,
                  height: face * 0.92,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lueur néon externe Wiwiga (halo)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    NeonColors.primary.withValues(alpha: 0.10),
                    Colors.transparent
                  ],
                  radius: 0.85,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder: (c, v, child) =>
            Transform.scale(scale: 0.85 + 0.15 * v, child: child),
        child: dice,
      );
    }
    return dice;
  }
}

/// Face 5 points en creux avec ombre interne
class _FiveFace extends StatelessWidget {
  final double face;
  const _FiveFace({required this.face});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: face * 0.14,
      height: face * 0.14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.7),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 1.5,
              offset: const Offset(0, 1)),
          BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 0.5,
              offset: const Offset(-0.5, -0.5)),
        ],
      ),
      child: Center(
        child: Container(
          width: face * 0.06,
          height: face * 0.06,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );

    final gap = face * 0.22;
    final base = face * 0.18;
    return SizedBox(
      width: face,
      height: face,
      child: Stack(
        children: [
          Positioned(left: base, top: base, child: dot),
          Positioned(right: base, top: base, child: dot),
          Positioned(left: face * 0.43, top: face * 0.43, child: dot),
          Positioned(left: base, bottom: base, child: dot),
          Positioned(right: base, bottom: base, child: dot),
        ],
      ),
    );
  }
}

/// Variante compacte pour listes (sans ombre sol)
class WiwigaDiceBadge extends StatelessWidget {
  final double size;
  const WiwigaDiceBadge({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return WiwigaDiceIcon(size: size, withShadow: false);
  }
}

/// Icône hero pour headers (avec halo pulsant)
class WiwigaDiceHero extends StatefulWidget {
  final double size;
  const WiwigaDiceHero({super.key, this.size = 64});

  @override
  State<WiwigaDiceHero> createState() => _WiwigaDiceHeroState();
}

class _WiwigaDiceHeroState extends State<WiwigaDiceHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (c, child) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: NeonColors.primary
                    .withValues(alpha: 0.18 + _ctrl.value * 0.10),
                blurRadius: 18 + _ctrl.value * 6)
          ],
        ),
        child: child,
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
              center: Alignment.center,
              radius: 0.85),
          border: Border.all(
              color: NeonColors.primary.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Center(
            child: WiwigaDiceIcon(size: widget.size * 0.78, withShadow: false)),
      ),
    );
  }
}

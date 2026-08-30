// ============================================================
// Fichier: token_coin.dart
// Description: Pièce 3D WIWIGA — système paramétrique LOD
//   Variants métal, volume/bevel/tranche, effets GPU
// Auteur: WIWIGA Team — génération 2026-08-30
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Pièce 3D WIWIGA — composant unique paramétrique
///
/// Remplace TokenIcon (hexagone) par cercle 3D à volume réel.
/// LOD auto selon [size] : flat <20, bevel 20-36, edge 36-64, full >64.
/// Re-exporte TokenVariant legacy pour compatibilité via alias.
class TokenCoin extends StatelessWidget {
  final double size;
  final TokenMetal metal;
  final TokenLod lod;
  final TokenEffect effect;
  final bool showShadow;
  final bool withW;
  final String? rankLabel;
  final bool animated;
  final VoidCallback? onTap;
  final double thicknessFactor;

  const TokenCoin({
    super.key,
    this.size = 44,
    this.metal = TokenMetal.emerald,
    this.lod = TokenLod.full,
    this.effect = TokenEffect.none,
    this.showShadow = true,
    this.withW = true,
    this.rankLabel,
    this.animated = false,
    this.onTap,
    this.thicknessFactor = 1.0,
  });

  /// LOD automatique selon taille — règle HTML validée
  static TokenLod autoLod(double s) {
    if (s < 20) return TokenLod.flat;
    if (s < 36) return TokenLod.bevel;
    if (s < 64) return TokenLod.edge;
    return TokenLod.full;
  }

  TokenLod get effectiveLod {
    // Si l'appelant passe full on laisse auto décider ; sinon on respecte l'explicite
    // Astuce: si size est très petite et lod est edge/full on downgrade
    final a = autoLod(size);
    if (lod == TokenLod.full) return a;
    // Si lod demandé est plus détaillé que ce que la taille permet, on clamp vers le bas
    if (a.index < lod.index) return a;
    return lod;
  }

  @override
  Widget build(BuildContext context) {
    // Accessibilité: ne pas animer si reduceMotion
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final eff = reduceMotion &&
            (effect == TokenEffect.spin ||
                effect == TokenEffect.flip ||
                effect == TokenEffect.float)
        ? TokenEffect.none
        : effect;

    final coin = _TokenCoinCore(
      size: size,
      metal: metal,
      lod: effectiveLod,
      withW: withW,
      rankLabel: rankLabel,
      showShadow: showShadow,
      thicknessFactor: thicknessFactor,
    );

    Widget child;
    if (animated || eff != TokenEffect.none) {
      child = _AnimatedTokenCoin(
        size: size,
        metal: metal,
        lod: effectiveLod,
        effect: animated && eff == TokenEffect.none ? TokenEffect.pulse : eff,
        showShadow: showShadow,
        withW: withW,
        rankLabel: rankLabel,
        thicknessFactor: thicknessFactor,
        child: coin,
      );
    } else {
      child = RepaintBoundary(child: coin);
    }

    final semanticsLabel = rankLabel != null
        ? 'Rang $rankLabel'
        : '${size.toInt()} wiga ${metal.name}';

    Widget wrapped = withW && rankLabel == null
        ? Semantics(
            label: semanticsLabel,
            image: size >= 36,
            excludeSemantics: size < 20,
            child: child,
          )
        : child;

    if (onTap != null) {
      wrapped = GestureDetector(
        onTap: onTap,
        child: wrapped,
      );
    }

    // Garantie zone tactile 44x44 si cliquable et petit
    if (onTap != null && size < 44) {
      wrapped = SizedBox(
        width: 44,
        height: 44,
        child: Center(child: wrapped),
      );
    }

    return wrapped;
  }
}

/// Coeur statique — CustomPaint pur, sans animation
class _TokenCoinCore extends StatelessWidget {
  final double size;
  final TokenMetal metal;
  final TokenLod lod;
  final bool withW;
  final String? rankLabel;
  final bool showShadow;
  final double thicknessFactor;

  const _TokenCoinCore({
    required this.size,
    required this.metal,
    required this.lod,
    required this.withW,
    this.rankLabel,
    required this.showShadow,
    required this.thicknessFactor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TokenCoinPainter(
          metal: metal,
          lod: lod,
          withW: withW,
          rankLabel: rankLabel,
          showShadow: showShadow,
          thicknessFactor: thicknessFactor,
          shimmerProgress: 0,
          spinProgress: 0,
        ),
      ),
    );
  }
}

/// Version animée — gère pulse / shimmer / spin / float / flip
class _AnimatedTokenCoin extends StatefulWidget {
  final double size;
  final TokenMetal metal;
  final TokenLod lod;
  final TokenEffect effect;
  final bool showShadow;
  final bool withW;
  final String? rankLabel;
  final double thicknessFactor;
  final Widget child;

  const _AnimatedTokenCoin({
    required this.size,
    required this.metal,
    required this.lod,
    required this.effect,
    required this.showShadow,
    required this.withW,
    this.rankLabel,
    required this.thicknessFactor,
    required this.child,
  });

  @override
  State<_AnimatedTokenCoin> createState() => _AnimatedTokenCoinState();
}

class _AnimatedTokenCoinState extends State<_AnimatedTokenCoin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnim;
  late Animation<double> _spinAnim;

  @override
  void initState() {
    super.initState();
    final isPulse = widget.effect == TokenEffect.pulse;
    final isShimmer = widget.effect == TokenEffect.shimmer;
    final isSpin = widget.effect == TokenEffect.spin;
    final isFloat = widget.effect == TokenEffect.float;
    final isFlip = widget.effect == TokenEffect.flip;

    Duration dur = const Duration(milliseconds: 1900);
    if (isShimmer) dur = const Duration(milliseconds: 2200);
    if (isSpin) dur = const Duration(milliseconds: 1400);
    if (isFloat) dur = const Duration(milliseconds: 1800);
    if (isFlip) dur = const Duration(milliseconds: 700);

    _controller = AnimationController(duration: dur, vsync: this);

    if (isPulse || isFloat) {
      _controller.repeat(reverse: true);
    } else if (isShimmer) {
      _controller.repeat();
    } else if (isSpin) {
      _controller.repeat();
    } else if (isFlip) {
      _controller.forward();
    } else {
      _controller.repeat(reverse: true);
    }

    _pulseAnim = Tween<double>(begin: 0.30, end: 0.58).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _spinAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedTokenCoin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _controller.stop();
      if (widget.effect == TokenEffect.flip) {
        _controller.forward(from: 0);
      } else if (widget.effect == TokenEffect.spin ||
          widget.effect == TokenEffect.shimmer) {
        _controller.repeat();
      } else {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Flip est géré via Transform 3D autour de Y
    if (widget.effect == TokenEffect.flip) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 0→0.5 : face avant qui tourne, 0.5→1 : face arrière
          final angle = t * math.pi; // 0→180°
          final scale = 1.0 + math.sin(t * math.pi) * 0.06;
          return RepaintBoundary(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle)
                ..scale(scale),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _TokenCoinPainter(
                    metal: widget.metal,
                    lod: widget.lod,
                    withW: widget.withW,
                    rankLabel: widget.rankLabel,
                    showShadow: widget.showShadow,
                    thicknessFactor: widget.thicknessFactor,
                    shimmerProgress: 0,
                    spinProgress: 0,
                    flipProgress: t,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.effect == TokenEffect.spin) {
      return AnimatedBuilder(
        animation: _spinAnim,
        builder: (context, _) {
          final angle = _spinAnim.value * 2 * math.pi;
          return RepaintBoundary(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _TokenCoinPainter(
                    metal: widget.metal,
                    lod: widget.lod,
                    withW: widget.withW,
                    rankLabel: widget.rankLabel,
                    showShadow: widget.showShadow,
                    thicknessFactor: widget.thicknessFactor,
                    shimmerProgress: 0,
                    spinProgress: _spinAnim.value,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.effect == TokenEffect.float) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final dy = math.sin(_controller.value * math.pi) * -4.5;
          return RepaintBoundary(
            child: Transform.translate(
              offset: Offset(0, dy),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _TokenCoinPainter(
                    metal: widget.metal,
                    lod: widget.lod,
                    withW: widget.withW,
                    rankLabel: widget.rankLabel,
                    showShadow: widget.showShadow,
                    thicknessFactor: widget.thicknessFactor,
                    shimmerProgress: 0,
                    spinProgress: 0,
                    floatProgress: _controller.value,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.effect == TokenEffect.shimmer) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return RepaintBoundary(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _TokenCoinPainter(
                  metal: widget.metal,
                  lod: widget.lod,
                  withW: widget.withW,
                  rankLabel: widget.rankLabel,
                  showShadow: widget.showShadow,
                  thicknessFactor: widget.thicknessFactor,
                  shimmerProgress: _controller.value,
                  spinProgress: 0,
                ),
              ),
            ),
          );
        },
      );
    }

    // Pulse (défaut)
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        return RepaintBoundary(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _TokenCoinPainter(
                metal: widget.metal,
                lod: widget.lod,
                withW: widget.withW,
                rankLabel: widget.rankLabel,
                showShadow: widget.showShadow,
                thicknessFactor: widget.thicknessFactor,
                shimmerProgress: 0,
                spinProgress: 0,
                pulseProgress: _pulseAnim.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Painter 3D — face, bevel, tranche, insert, W, spéculaire, shimmer
class _TokenCoinPainter extends CustomPainter {
  final TokenMetal metal;
  final TokenLod lod;
  final bool withW;
  final String? rankLabel;
  final bool showShadow;
  final double thicknessFactor;
  final double shimmerProgress;
  final double spinProgress;
  final double pulseProgress;
  final double floatProgress;
  final double flipProgress;

  _TokenCoinPainter({
    required this.metal,
    required this.lod,
    required this.withW,
    this.rankLabel,
    required this.showShadow,
    required this.thicknessFactor,
    this.shimmerProgress = 0,
    this.spinProgress = 0,
    this.pulseProgress = 0.38,
    this.floatProgress = 0,
    this.flipProgress = 0,
  });

  Color get _base {
    switch (metal) {
      case TokenMetal.emerald: return TokenMetals.emeraldBase;
      case TokenMetal.gold: return TokenMetals.goldBase;
      case TokenMetal.silver: return TokenMetals.silverBase;
      case TokenMetal.bronze: return TokenMetals.bronzeBase;
      case TokenMetal.diamond: return TokenMetals.diamondBase;
      case TokenMetal.holographic: return NeonColors.accent;
    }
  }

  Color get _mid {
    switch (metal) {
      case TokenMetal.emerald: return TokenMetals.emeraldMid;
      case TokenMetal.gold: return TokenMetals.goldMid;
      case TokenMetal.silver: return TokenMetals.silverMid;
      case TokenMetal.bronze: return TokenMetals.bronzeMid;
      case TokenMetal.diamond: return TokenMetals.diamondMid;
      case TokenMetal.holographic: return NeonColors.tokenHoloMid;
    }
  }

  Color get _dark {
    switch (metal) {
      case TokenMetal.emerald: return TokenMetals.emeraldDark;
      case TokenMetal.gold: return TokenMetals.goldDark;
      case TokenMetal.silver: return TokenMetals.silverDark;
      case TokenMetal.bronze: return TokenMetals.bronzeDark;
      case TokenMetal.diamond: return TokenMetals.diamondDark;
      case TokenMetal.holographic: return NeonColors.tokenHoloEnd;
    }
  }

  Color get _edgeColor => TokenMetals.edgeFor(metal);
  Color get _glowColor => TokenMetals.glowFor(metal);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final center = Offset(cx, cy);
    final isFlat = lod == TokenLod.flat;
    final hasBevel = lod.index >= TokenLod.bevel.index;
    final hasEdge = lod.index >= TokenLod.edge.index;
    final isFull = lod == TokenLod.full;

    // Flip: si >0.5 on assombrit légèrement pour simuler tranche
    final flipDarken = flipProgress > 0.48 && flipProgress < 0.52
        ? 0.18
        : (flipProgress > 0.5 ? 0.08 : 0.0);

    // --- 1. Ombre portée ---
    if (showShadow && !isFlat) {
      final shadowR = r * 0.96;
      final shadowY = r * 0.18;
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22);
      // ellipse aplatie
      canvas.save();
      canvas.translate(cx, cy + shadowY + r * 0.62);
      canvas.scale(1.0, 0.38);
      canvas.drawCircle(Offset.zero, shadowR, shadowPaint);
      canvas.restore();
    }

    // --- 2. Tranche (edge) ---
    if (hasEdge) {
      final edgeH = (r * 0.22 * thicknessFactor).clamp(2.0, r * 0.42);
      final edgeRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: r * 1.86,
        height: edgeH,
      );
      final edgeRRect = RRect.fromRectAndRadius(edgeRect, Radius.circular(edgeH / 2));
      final edgePaint = Paint()
        ..shader = LinearGradient(
          colors: [_dark, _edgeColor, _base, _edgeColor, _dark],
          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
        ).createShader(edgeRect)
        ..style = PaintingStyle.fill;
      // On dessine seulement si taille suffisante (sinon on simule via border)
      if (size.width >= 36) {
        canvas.drawRRect(edgeRRect, edgePaint);
        // highlight haut / ombre bas
        final hiPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7;
        canvas.drawRRect(edgeRRect, hiPaint);
      }
    }

    // --- 3. Face principale ---
    final faceRadius = isFlat ? r * 0.92 : r * 0.88;
    final faceRect = Rect.fromCircle(center: center, radius: faceRadius);

    // Face gradient selon métal
    Paint facePaint;
    if (metal == TokenMetal.holographic && isFull) {
      facePaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: const [
            Color(0xFF00D9FF),
            Color(0xFF7C3AED),
            Color(0xFFFF2E93),
            Color(0xFFFFD700),
            Color(0xFF00D9FF),
          ],
          stops: const [0.0, 0.32, 0.58, 0.82, 1.0],
          transform: GradientRotation(spinProgress * 2 * math.pi),
        ).createShader(faceRect);
      if (flipDarken > 0) {
        facePaint.colorFilter = ColorFilter.mode(
          Colors.black.withValues(alpha: flipDarken),
          BlendMode.srcATop,
        );
      }
    } else {
      // Radial bombé
      facePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.28, -0.34),
          radius: 1.18,
          colors: [
            Color.lerp(_mid, Colors.white, 0.18)!,
            _base,
            Color.lerp(_base, _dark, 0.22)!,
            _dark,
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(faceRect);
    }
    canvas.drawCircle(center, faceRadius, facePaint);

    // Holo voile blanc radial par-dessus
    if (metal == TokenMetal.holographic && isFull) {
      final veilPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.62,
          colors: [Colors.white.withValues(alpha: 0.42), Colors.transparent],
        ).createShader(faceRect);
      canvas.drawCircle(center, faceRadius, veilPaint);
    }

    // --- 4. Bordure / rim ---
    final rimPaint = Paint()
      ..color = _base
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.032).clamp(1.0, 2.4);
    canvas.drawCircle(center, faceRadius, rimPaint);

    // --- 5. Bevel (chanfrein) ---
    if (hasBevel) {
      final bevelR = faceRadius * 0.92;
      final bevelPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (r * 0.055).clamp(1.2, 3.2)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(faceRect);
      canvas.drawCircle(center, bevelR, bevelPaint);
    }

    // --- 6. Anneau intérieur ---
    if (hasBevel) {
      final innerPaint = Paint()
        ..color = Colors.white.withValues(alpha: isFlat ? 0.22 : 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (r * 0.018).clamp(0.8, 1.6);
      canvas.drawCircle(center, faceRadius * 0.78, innerPaint);
      // second micro cercle pour profondeur
      final microPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      canvas.drawCircle(center, faceRadius * 0.76, microPaint);
    }

    // --- 7. Insert damier (or) ---
    if (metal == TokenMetal.gold && hasEdge) {
      _drawGoldInsert(canvas, center, faceRadius);
    }

    // --- 8. Spéculaire ---
    if (hasBevel) {
      final specW = faceRadius * 0.84;
      final specH = faceRadius * 0.60;
      final specRect = Rect.fromCenter(
        center: Offset(cx - faceRadius * 0.18, cy - faceRadius * 0.22),
        width: specW,
        height: specH,
      );
      final specPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: isFull ? 0.46 : 0.32),
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(specRect);
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: faceRadius * 0.78)));
      canvas.drawOval(specRect, specPaint);
      canvas.restore();
    }

    // --- 9. W ou rang ---
    if (rankLabel != null) {
      _drawRank(canvas, center, faceRadius);
    } else if (withW) {
      _drawW(canvas, center, faceRadius);
    }

    // --- 10. Shimmer sweep ---
    if (shimmerProgress > 0 && shimmerProgress < 1 && hasBevel) {
      _drawShimmer(canvas, faceRect, shimmerProgress);
    }

    // --- 11. Glow externe (pulse) ---
    if (pulseProgress > 0.31 && !isFlat) {
      final glowPaint = Paint()
        ..color = _glowColor.withValues(alpha: (pulseProgress - 0.28).clamp(0.0, 0.42))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10;
      canvas.drawCircle(center, faceRadius * 1.02, glowPaint);
    }
  }

  void _drawGoldInsert(Canvas canvas, Offset center, double faceRadius) {
    final insertR = faceRadius * 0.62;
    final insertRect = Rect.fromCircle(center: center, radius: insertR);

    // 4 segments damier or / crème
    const cream = Color(0xFFFFF8DC);
    const lightGold = Color(0xFFFFF2A8);
    // On dessine 4 arcs alternés
    for (int i = 0; i < 4; i++) {
      final start = (math.pi / 2) * i - math.pi / 4;
      final sweep = math.pi / 2;
      final segPaint = Paint()
        ..color = i.isEven ? lightGold : cream
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(insertRect, start, sweep, false)
        ..close();
      canvas.drawPath(path, segPaint);
    }
    // anneau central transparent
    final holePaint = Paint()
      ..color = _base
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, insertR * 0.42, holePaint);
    // bord pointillé
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    // tirets autour du insert
    const dashes = 20;
    for (int i = 0; i < dashes; i++) {
      final a = (2 * math.pi / dashes) * i;
      if (i.isOdd) continue;
      final p1 = Offset(
        center.dx + (insertR - 1) * math.cos(a),
        center.dy + (insertR - 1) * math.sin(a),
      );
      final p2 = Offset(
        center.dx + (insertR - 1) * math.cos(a + 0.12),
        center.dy + (insertR - 1) * math.sin(a + 0.12),
      );
      canvas.drawLine(p1, p2, dashPaint);
    }
    // bord fin
    final borderPaint = Paint()
      ..color = _base.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(center, insertR, borderPaint);
    canvas.drawCircle(center, insertR * 0.42, borderPaint);
  }

  void _drawW(Canvas canvas, Offset center, double radius) {
    // W proportionnel, stroke adaptatif
    final r = radius;
    final strokeW = (r * 0.10).clamp(1.2, 3.2);
    final glowW = strokeW * 1.26;

    final w = r * 0.58;
    final h = r * 0.48;
    final sx = center.dx - w;
    final sy = center.dy - h * 0.72;

    final wPath = Path()
      ..moveTo(sx, sy)
      ..lineTo(sx + w * 0.50, sy + h * 1.72)
      ..lineTo(sx + w * 0.75, sy + h * 0.68)
      ..lineTo(sx + w * 1.25, sy + h * 0.68)
      ..lineTo(sx + w * 1.50, sy + h * 1.72)
      ..lineTo(sx + w * 2.0, sy);

    // ombre portée du W (emboss)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    final shadowPath = wPath.shift(const Offset(0.9, 1.2));
    canvas.drawPath(shadowPath, shadowPaint);

    // glow blanc derrière
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2);
    canvas.drawPath(wPath, glowPaint);

    // W principal
    final wPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(wPath, wPaint);
  }

  void _drawRank(Canvas canvas, Offset center, double faceRadius) {
    final text = rankLabel!;
    final fontSize = faceRadius * 0.72;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 4, offset: const Offset(0, 1)),
            Shadow(color: Colors.white.withValues(alpha: 0.32), blurRadius: 8),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 + 1);
    tp.paint(canvas, offset);
  }

  void _drawShimmer(Canvas canvas, Rect faceRect, double progress) {
    // Bande diagonale qui traverse
    final w = faceRect.width * 0.28;
    // progress 0→1 => -1.2 → 2.2
    final x = faceRect.left + (faceRect.width + w) * (progress * 2.2 - 0.6) - w / 2;
    final bandRect = Rect.fromLTWH(x, faceRect.top - faceRect.height * 0.18, w, faceRect.height * 1.36);
    final bandPath = Path()
      ..addRect(bandRect);
    // clip au cercle
    final clipPath = Path()..addOval(faceRect);
    canvas.save();
    canvas.clipPath(clipPath);
    // rotate 12° via canvas transform
    canvas.save();
    // approximate skew by rotating
    final bandPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.38, 0.50, 0.62, 1.0],
      ).createShader(bandRect);
    canvas.drawPath(bandPath, bandPaint);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TokenCoinPainter oldDelegate) {
    return oldDelegate.metal != metal ||
        oldDelegate.lod != lod ||
        oldDelegate.withW != withW ||
        oldDelegate.rankLabel != rankLabel ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.thicknessFactor != thicknessFactor ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.spinProgress != spinProgress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.flipProgress != flipProgress;
  }
}

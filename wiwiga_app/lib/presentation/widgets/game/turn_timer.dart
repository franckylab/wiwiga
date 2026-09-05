// ============================================================
// Fichier: turn_timer.dart
// Description: Timer circulaire pour tour de jeu avec forfait
// Auteur: WIWIGA Team - Refactor 2026-08-31 — Optim P3 2026-09
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Timer circulaire pour le tour du joueur
/// Affiche décompte, passe en alerte rouge sous 5s, callback onTimeout -> forfait
/// Mode serveur : fournir `deadline` (synchrone) et/ou `remainingOverride` pour éviter dérive horloge
class TurnTimer extends StatefulWidget {
  final int totalSeconds;
  final DateTime? deadline; // deadline serveur (prioritaire)
  final int? remainingOverride; // remaining déjà calculé côté parent (synchro)
  final VoidCallback? onTimeout;
  final bool isActive;
  final bool isPaused;
  final double size;
  final Color activeColor;
  final Color warningColor;

  const TurnTimer({
    super.key,
    required this.totalSeconds,
    this.deadline,
    this.remainingOverride,
    this.onTimeout,
    this.isActive = true,
    this.isPaused = false,
    this.size = 56,
    this.activeColor = NeonColors.primary,
    this.warningColor = NeonColors.error,
  });

  @override
  State<TurnTimer> createState() => _TurnTimerState();
}

class _TurnTimerState extends State<TurnTimer> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  Timer? _ticker;
  late int _remaining;
  late DateTime _deadline;

  // Cache border color to avoid withValues hot path
  static final Color _borderBg = NeonColors.border.withValues(alpha: 0.5);

  @override
  void initState() {
    super.initState();
    // Mode serveur synchrone : si remainingOverride fourni, on s'aligne sur parent (pas de ticker local)
    if (widget.remainingOverride != null) {
      _remaining = widget.remainingOverride!;
      _deadline = widget.deadline ?? DateTime.now().add(Duration(seconds: _remaining));
      _pulse = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
      _syncPulse();
      // Ne pas démarrer de ticker local si piloté par parent (dice_match) — synchro serveur
      if (widget.deadline == null) {
        _start();
      } else {
        // Deadline serveur : on laisse parent mettre à jour via didUpdateWidget chaque seconde
        // On démarre quand même un ticker léger pour décrémenter si parent ne pousse pas (fallback)
        if (widget.isActive && !widget.isPaused) _start();
      }
    } else if (widget.deadline != null) {
      _deadline = widget.deadline!;
      _remaining = _calcRemainingFromDeadline();
      _pulse = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
      _syncPulse();
      _start();
    } else {
      _remaining = widget.totalSeconds;
      _deadline = DateTime.now().add(Duration(seconds: widget.totalSeconds));
      _pulse = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
      _syncPulse();
      _start();
    }
  }

  int _calcRemainingFromDeadline() {
    final diff = _deadline.difference(DateTime.now()).inMilliseconds;
    return (diff / 1000).ceil().clamp(0, widget.totalSeconds);
  }

  void _syncPulse() {
    final isUrgent = _remaining <= 3 && _remaining > 0;
    // P3 FIX: supprime _pulse interne si _remaining>5 — pas d'AnimationController actif hors alerte
    if (isUrgent && widget.isActive && !widget.isPaused) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) _pulse.stop();
      // Sur web, on évite tick inactif
      if (kIsWeb) _pulse.reset();
    }
  }

  @override
  void didUpdateWidget(TurnTimer old) {
    super.didUpdateWidget(old);
    final deadlineChanged = old.deadline != widget.deadline;
    final remainingChanged = old.remainingOverride != widget.remainingOverride;
    // Mode serveur synchrone : remainingOverride piloté par parent → simple sync, pas de restart ticker
    if (widget.remainingOverride != null) {
      if (remainingChanged || deadlineChanged) {
        _remaining = widget.remainingOverride!;
        if (widget.deadline != null) _deadline = widget.deadline!;
        _syncPulse();
        setState(() {});
      }
      // Ne pas redémarrer le ticker à chaque seconde si piloté par parent
      if (old.isActive != widget.isActive || old.isPaused != widget.isPaused) {
        if (widget.isPaused || !widget.isActive) {
          _ticker?.cancel();
          _syncPulse();
        } else if (widget.deadline == null) {
          _start();
          _syncPulse();
        }
      }
      return;
    }
    if (deadlineChanged || remainingChanged || old.totalSeconds != widget.totalSeconds || old.isActive != widget.isActive) {
      if (widget.deadline != null) {
        _deadline = widget.deadline!;
        _remaining = widget.remainingOverride ?? _calcRemainingFromDeadline();
        _ticker?.cancel();
        if (widget.isActive && !widget.isPaused) _start();
        _syncPulse();
        setState(() {});
      } else if (old.totalSeconds != widget.totalSeconds || old.isActive != widget.isActive) {
        _restart();
      }
    }
    if (old.isPaused != widget.isPaused || old.isActive != widget.isActive) {
      if (widget.isPaused || !widget.isActive) {
        _ticker?.cancel();
        _syncPulse();
      } else {
        _start();
        _syncPulse();
      }
    }
    // Si remaining a changé, resync pulse
    if (_remaining <= 3) {
      _syncPulse();
    }
  }

  void _restart() {
    _ticker?.cancel();
    if (widget.deadline != null) {
      _deadline = widget.deadline!;
      _remaining = widget.remainingOverride ?? _calcRemainingFromDeadline();
    } else if (widget.remainingOverride != null) {
      _remaining = widget.remainingOverride!;
      _deadline = DateTime.now().add(Duration(seconds: _remaining));
    } else {
      _remaining = widget.totalSeconds;
      _deadline = DateTime.now().add(Duration(seconds: widget.totalSeconds));
    }
    if (widget.isActive && !widget.isPaused) _start();
    _syncPulse();
    setState(() {});
  }

  void _start() {
    if (!widget.isActive || widget.isPaused) return;
    _ticker?.cancel();
    // P3 FIX: 200ms → 1000ms (ceil suffit pour secondes, évite setState 5×/s)
    _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (!mounted) return;
      // Si on a un remainingOverride piloté par parent (dice_match), on ne doit pas recalculer via deadline seule
      // Mais dans ce mode, TurnTimer est piloté par didUpdateWidget ; on évite dérive
      final diff = _deadline.difference(DateTime.now()).inMilliseconds;
      final sec = (diff / 1000).ceil().clamp(0, widget.totalSeconds);
      if (sec != _remaining) {
        setState(() => _remaining = sec);
        _syncPulse();
      }
      if (sec <= 0) {
        _ticker?.cancel();
        _pulse.stop();
        widget.onTimeout?.call();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalSeconds == 0 ? 0.0 : _remaining / widget.totalSeconds;
    final isWarning = _remaining <= 5 && _remaining > 0;
    final isUrgent = _remaining <= 3 && _remaining > 0;
    final color = _remaining <= 0 ? NeonColors.error : (isWarning ? widget.warningColor : widget.activeColor);

    // Cache shadow color to avoid withValues per build
    final shadowAlpha = isUrgent ? 0.32 : 0.14;
    final shadowBlur = isUrgent ? 10.0 : 6.0;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fond
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NeonColors.surface,
                border: Border.all(color: NeonColors.border),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: shadowAlpha), blurRadius: shadowBlur),
                ],
              ),
            ),
            // Progress circulaire — CustomPainter sans saveLayer (vs CircularProgressIndicator)
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _TurnTimerArcPainter(
                    progress: progress,
                    color: color,
                    backgroundColor: _borderBg,
                    strokeWidth: 3.5,
                  ),
                  isComplex: false,
                  willChange: true,
                ),
              ),
            ),
            // Pulse warning — uniquement si urgent, RepaintBoundary + arrêt ticker si !isActive
            if (isUrgent)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    width: widget.size + 6 + _pulse.value * 6,
                    height: widget.size + 6 + _pulse.value * 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.35 * (1 - _pulse.value)), width: 1.5),
                    ),
                  ),
                ),
              ),
            // Texte
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_remaining',
                  style: TextStyle(
                    color: color,
                    fontSize: widget.size * 0.34,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                    height: 1,
                  ),
                ),
                Text(
                  's',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: widget.size * 0.16,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
            // Icône sablier petite
            Positioned(
              top: 2,
              child: Icon(Icons.hourglass_top_rounded, size: widget.size * 0.18, color: color.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter arc simple sans saveLayer — remplace CircularProgressIndicator
class _TurnTimerArcPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  const _TurnTimerArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - strokeWidth / 2;
    final center = Offset(cx, cy);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Fond cercle complet
    canvas.drawCircle(center, radius, bgPaint);
    // Arc progression — start -90° (haut)
    if (progress > 0.001) {
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TurnTimerArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Barre linéaire fine pour header
class TurnLinearProgress extends StatelessWidget {
  final int remaining;
  final int total;
  final bool isActive;

  const TurnLinearProgress({super.key, required this.remaining, required this.total, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : remaining / total;
    final isWarning = remaining <= 5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: p,
        minHeight: 4,
        backgroundColor: NeonColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(isWarning ? NeonColors.warning : NeonColors.primary),
      ),
    );
  }
}

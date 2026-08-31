// ============================================================
// Fichier: turn_timer.dart
// Description: Timer circulaire pour tour de jeu avec forfait
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Timer circulaire pour le tour du joueur
/// Affiche décompte, passe en alerte rouge sous 5s, callback onTimeout -> forfait
class TurnTimer extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback? onTimeout;
  final bool isActive;
  final bool isPaused;
  final double size;
  final Color activeColor;
  final Color warningColor;

  const TurnTimer({
    super.key,
    required this.totalSeconds,
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

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _deadline = DateTime.now().add(Duration(seconds: widget.totalSeconds));
    _pulse = AnimationController(duration: const Duration(milliseconds: 700), vsync: this)..repeat(reverse: true);
    _start();
  }

  @override
  void didUpdateWidget(TurnTimer old) {
    super.didUpdateWidget(old);
    if (old.totalSeconds != widget.totalSeconds || old.isActive != widget.isActive) {
      _restart();
    }
    if (old.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _ticker?.cancel();
      } else {
        _start();
      }
    }
  }

  void _restart() {
    _ticker?.cancel();
    _remaining = widget.totalSeconds;
    _deadline = DateTime.now().add(Duration(seconds: widget.totalSeconds));
    if (widget.isActive && !widget.isPaused) _start();
    setState(() {});
  }

  void _start() {
    if (!widget.isActive) return;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final diff = _deadline.difference(DateTime.now()).inMilliseconds;
      final sec = (diff / 1000).ceil().clamp(0, widget.totalSeconds);
      if (sec != _remaining) setState(() => _remaining = sec);
      if (sec <= 0) {
        _ticker?.cancel();
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

    return SizedBox(
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
                BoxShadow(color: color.withValues(alpha: isUrgent ? 0.45 : 0.18), blurRadius: isUrgent ? 14 : 8),
              ],
            ),
          ),
          // Progress circulaire
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.5,
              backgroundColor: NeonColors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // Pulse warning
          if (isUrgent)
            AnimatedBuilder(
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
    );
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

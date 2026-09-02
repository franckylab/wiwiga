// ============================================================
// Fichier: player_zone.dart
// Description: Zone joueur autour du tatami — score, niveau, mise, état tour
// Auteur: WIWIGA Team - Refactor 2026-08-31
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'turn_timer.dart';

/// Modèle léger d'affichage joueur pour UI match
class PlayerZoneData {
  final String id;
  final String name;
  final String displayName; // "Moi" pour self
  final int score; // sets gagnés
  final int level; // niveau joueur
  final int xpProgress; // 0-100
  final int betAmount; // wiga misés
  final bool isActiveTurn;
  final bool isEliminated;
  final bool isWaiting;
  final int? lastSum; // dernière somme lancée
  final List<int>? lastDice;
  final int setsToWin;
  final String avatarLetter;
  final Color accent;

  const PlayerZoneData({
    required this.id,
    required this.name,
    required this.displayName,
    this.score = 0,
    this.level = 1,
    this.xpProgress = 0,
    this.betAmount = 0,
    this.isActiveTurn = false,
    this.isEliminated = false,
    this.isWaiting = false,
    this.lastSum,
    this.lastDice,
    this.setsToWin = 2,
    this.avatarLetter = '?',
    this.accent = NeonColors.primary,
  });
}

/// Zone joueur individuelle — responsive, avec icône dé cliquable si c'est son tour
class PlayerZone extends StatefulWidget {
  final PlayerZoneData data;
  final int turnSeconds; // pour le timer
  final VoidCallback?
      onTapDice; // appelé quand joueur clique sur son icône dé pour jouer
  final VoidCallback? onTimeout; // forfait
  final bool showTimer;
  final bool isMe;
  final double? width;

  const PlayerZone({
    super.key,
    required this.data,
    this.turnSeconds = 30,
    this.onTapDice,
    this.onTimeout,
    this.showTimer = false,
    this.isMe = false,
    this.width,
  });

  @override
  State<PlayerZone> createState() => _PlayerZoneState();
}

class _PlayerZoneState extends State<PlayerZone>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (widget.data.isActiveTurn && !widget.data.isEliminated) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PlayerZone old) {
    super.didUpdateWidget(old);
    final shouldPulse = widget.data.isActiveTurn && !widget.data.isEliminated;
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final isActive = d.isActiveTurn && !d.isEliminated;
    final isLocked = !isActive && !d.isEliminated;
    final accent = d.isEliminated
        ? NeonColors.error
        : (isActive ? d.accent : NeonColors.border);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) =>
          Transform.scale(scale: isActive ? _scale.value : 1.0, child: child),
      child: Container(
        width: widget.width,
        constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: d.isEliminated
                ? [
                    NeonColors.surface.withValues(alpha: 0.9),
                    NeonColors.surface,
                  ]
                : isActive
                    ? [d.accent.withValues(alpha: 0.16), NeonColors.surface]
                    : [NeonColors.card, NeonColors.surface],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: isActive ? 0.85 : 0.35),
            width: isActive ? 2.2 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: d.accent.withValues(alpha: 0.32),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Barre XP en haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: LinearProgressIndicator(
                  value: (d.xpProgress.clamp(0, 100)) / 100,
                  minHeight: 3,
                  backgroundColor: NeonColors.border.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(d.accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ligne avatar + noms
                  Row(
                    children: [
                      _buildAvatar(d, isActive),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    d.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isActive
                                          ? d.accent
                                          : NeonColors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: widget.isMe ? 13 : 12,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                if (widget.isMe) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NeonColors.primary
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: NeonColors.primary
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: const Text(
                                      'MOI',
                                      style: TextStyle(
                                        color: NeonColors.primary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              widget.isMe ? d.name : d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 10,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Niveau + icônes
                            Row(
                              children: [
                                _levelBadge(d.level, d.accent),
                                const SizedBox(width: 4),
                                ..._levelIcons(d.level).take(3),
                                const Spacer(),
                                if (d.betAmount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NeonColors.tokenGold
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: NeonColors.tokenGold
                                            .withValues(alpha: 0.32),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.monetization_on_rounded,
                                          size: 10,
                                          color: NeonColors.tokenGold,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${d.betAmount}',
                                          style: const TextStyle(
                                            color: NeonColors.tokenGold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Orbitron',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Timer si actif
                      if (isActive && widget.showTimer)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: TurnTimer(
                            totalSeconds: widget.turnSeconds,
                            onTimeout: widget.onTimeout,
                            size: 44,
                            activeColor: d.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Ligne score + mise + somme
                  Row(
                    children: [
                      _statChip(
                        Icons.emoji_events_rounded,
                        '${d.score}/${d.setsToWin}',
                        d.score >= d.setsToWin
                            ? NeonColors.success
                            : NeonColors.primary,
                        'Sets',
                      ),
                      const SizedBox(width: 6),
                      _statChip(
                        Icons.layers_rounded,
                        'Niv ${d.level}',
                        NeonColors.accent,
                        'Niveau',
                      ),
                      const Spacer(),
                      if (d.lastSum != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: NeonColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: NeonColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '${d.lastSum}',
                            style: const TextStyle(
                              color: NeonColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Zone action dé
                  _buildDiceAction(d, isActive, isLocked),
                  // Éliminé overlay text
                  if (d.isEliminated) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: NeonColors.error.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: NeonColors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 12,
                            color: NeonColors.error,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ÉLIMINÉ — Forfait',
                            style: TextStyle(
                              color: NeonColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Badge tour actif en haut à droite
            if (isActive)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: d.accent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: d.accent.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.casino_rounded, size: 10, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'À TOI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Verrou si non actif
            if (isLocked && !d.isEliminated && d.isWaiting)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: NeonColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeonColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: NeonColors.textSecondary,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'ATTENTE',
                        style: TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(PlayerZoneData d, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [d.accent.withValues(alpha: 0.55), d.accent],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: d.accent.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Center(
            child: Text(
              d.avatarLetter.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
        // Indicateur niveau en bas
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeonColors.surface,
              border: Border.all(color: d.accent, width: 1.2),
            ),
            child: Center(
              child: Text(
                '${d.level}',
                style: TextStyle(
                  color: d.accent,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _levelBadge(int level, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForLevel(level), size: 10, color: accent),
          const SizedBox(width: 2),
          Text(
            'Lv $level',
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLevel(int lvl) {
    if (lvl >= 50) return Icons.military_tech_rounded;
    if (lvl >= 30) return Icons.workspace_premium_rounded;
    if (lvl >= 15) return Icons.star_rounded;
    if (lvl >= 5) return Icons.bolt_rounded;
    return Icons.circle_rounded;
  }

  List<Widget> _levelIcons(int lvl) {
    final count = (lvl ~/ 10).clamp(0, 3);
    return List.generate(
      count,
      (_) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          Icons.star_rounded,
          size: 10,
          color: NeonColors.tokenGold.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiceAction(PlayerZoneData d, bool isActive, bool isLocked) {
    if (d.isEliminated) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NeonColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.casino_outlined,
              size: 16,
              color: NeonColors.textSecondary,
            ),
            SizedBox(width: 6),
            Text(
              'Ne peut plus jouer',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (isActive) {
      // Bouton dé cliquable — doit cliquer sur icon dé dans sa zone
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTapDice,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [d.accent, d.accent.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: d.accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LANCER LES DÉS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.touch_app_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Verrouillé en attente
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: NeonColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: NeonColors.border.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.casino_outlined,
              size: 14,
              color: NeonColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'En attente du tour',
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.lock_rounded,
            size: 12,
            color: NeonColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

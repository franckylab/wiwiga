// ============================================================
// Fichier: player_zone.dart
// Description: Zone joueur compacte — une seule ligne horizontale :
//   avatar (niveau greffé) + nom/score, bouton dé icon-only avec timer greffé.
//   Sobre, dense, responsive. Le serveur reste l'unique source de vérité.
// Auteur: WIWIGA Team - Refactor compact 2026-09
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'turn_timer.dart';

/// Modèle léger d'affichage joueur pour UI match.
/// Conservé inchangé pour compatibilité (l'écran fournit les données serveur).
class PlayerZoneData {
  final String id;
  final String name;
  final String displayName; // "Moi" pour self
  final int score; // sets gagnés — toujours visible par tous
  final int level; // niveau joueur (greffé sur l'avatar)
  final int xpProgress; // 0-100 (non affiché : version compacte)
  final int betAmount; // jetons misés (non affiché : redondant avec header)
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

/// Zone joueur individuelle compacte — une ligne horizontale.
/// [onTapDice] non-null = bouton dé activé (tour du joueur local).
class PlayerZone extends StatefulWidget {
  final PlayerZoneData data;
  final int turnSeconds; // pour le timer (durée totale)
  final DateTime? turnDeadline; // deadline serveur (synchro temps réel)
  final int? turnRemaining; // remaining serveur (fallback)
  final VoidCallback?
      onTapDice; // appelé quand joueur clique sur son icône dé pour jouer
  final VoidCallback? onTimeout; // forfait
  final bool showTimer;
  final bool isMe;
  final double? width;
  final bool compact; // adversaires : paddings et fontes réduits

  const PlayerZone({
    super.key,
    required this.data,
    this.turnSeconds = 30,
    this.turnDeadline,
    this.turnRemaining,
    this.onTapDice,
    this.onTimeout,
    this.showTimer = false,
    this.isMe = false,
    this.width,
    this.compact = false,
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    // Pulsation sobre (1.0 → 1.03) uniquement sur tour actif
    _scale = Tween<double>(begin: 1.0, end: 1.03)
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
    final accent = d.isEliminated
        ? NeonColors.textSecondary
        : (isActive ? d.accent : NeonColors.border);
    final dense = widget.compact && !widget.isMe;
    const activeBlur = kIsWeb ? 6.0 : 12.0;

    final container = Container(
      width: widget.width,
      constraints: BoxConstraints(
        maxWidth: dense ? 200 : 260,
      ),
      decoration: BoxDecoration(
        color: d.isEliminated
            ? NeonColors.surface.withValues(alpha: 0.7)
            : (isActive
                ? NeonColors.surface
                : NeonColors.card.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: d.isEliminated
              ? NeonColors.border.withValues(alpha: 0.5)
              : accent.withValues(alpha: isActive ? 0.8 : 0.35),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: d.accent.withValues(alpha: 0.28),
              blurRadius: activeBlur,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 6 : 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(d, isActive, dense),
          SizedBox(width: dense ? 6 : 8),
          // Nom + score (score toujours visible par tous)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: d.isEliminated
                        ? NeonColors.textSecondary
                        : (isActive ? d.accent : NeonColors.textPrimary),
                    fontWeight: FontWeight.w800,
                    fontSize: dense ? 11 : 12,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Score sets — icon + stricte nécessaire, visible par tous
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 11,
                      color: d.isEliminated
                          ? NeonColors.textSecondary
                          : (d.score >= d.setsToWin
                              ? NeonColors.success
                              : NeonColors.primary),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${d.score}/${d.setsToWin}',
                      style: TextStyle(
                        color: d.isEliminated
                            ? NeonColors.textSecondary
                            : (d.score >= d.setsToWin
                                ? NeonColors.success
                                : NeonColors.textPrimary),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Orbitron',
                        height: 1,
                      ),
                    ),
                    // Dernière somme — pastille discrète
                    if (d.lastSum != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: NeonColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                NeonColors.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          '= ${d.lastSum}',
                          style: const TextStyle(
                            color: NeonColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            fontFamily: 'Orbitron',
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: dense ? 6 : 8),
          // Bouton dé icon-only + timer greffé
          _buildDiceButton(d, isActive, dense),
        ],
      ),
    );

    if (!isActive) {
      return RepaintBoundary(child: container);
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: container,
      ),
    );
  }

  /// Avatar avec niveau greffé + pastille d'état (tour actif / éliminé).
  Widget _buildAvatar(PlayerZoneData d, bool isActive, bool dense) {
    final size = dense ? 32.0 : 36.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: d.isEliminated
                ? NeonColors.border.withValues(alpha: 0.5)
                : d.accent.withValues(alpha: isActive ? 0.9 : 0.45),
            border: Border.all(
              color: d.isEliminated
                  ? NeonColors.border
                  : (isActive
                      ? Colors.white.withValues(alpha: 0.9)
                      : d.accent.withValues(alpha: 0.4)),
              width: 1.5,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: d.accent.withValues(alpha: 0.4),
                  blurRadius: kIsWeb ? 6 : 10,
                ),
            ],
          ),
          child: Center(
            child: Text(
              d.avatarLetter.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: d.isEliminated ? 0.6 : 1.0,
                ),
                fontWeight: FontWeight.w900,
                fontSize: dense ? 12 : 13,
              ),
            ),
          ),
        ),
        // Niveau greffé en bas à droite
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeonColors.surface,
              border: Border.all(
                color: d.isEliminated
                    ? NeonColors.border
                    : d.accent,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                '${d.level}',
                style: TextStyle(
                  color: d.isEliminated
                      ? NeonColors.textSecondary
                      : d.accent,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        // Pastille d'état : tour actif (point lumineux) / éliminé (block)
        if (d.isEliminated)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: NeonColors.error,
              ),
              child: const Icon(
                Icons.block_rounded,
                size: 9,
                color: Colors.white,
              ),
            ),
          )
        else if (isActive)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: d.accent,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: d.accent.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Bouton dé icon-only (44px min tactile) avec timer greffé en pastille.
  Widget _buildDiceButton(PlayerZoneData d, bool isActive, bool dense) {
    final canPlay = widget.onTapDice != null && !d.isEliminated;
    final showTimer = isActive && widget.showTimer;
    // 44px : cible tactile minimale (règle responsive)
    const buttonSize = 44.0;
    Widget diceFace;
    if (d.isEliminated) {
      diceFace = Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NeonColors.surface,
          border: Border.all(color: NeonColors.border),
        ),
        child: const Icon(
          Icons.casino_outlined,
          size: 20,
          color: NeonColors.textSecondary,
        ),
      );
    } else if (canPlay) {
      diceFace = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTapDice,
          child: Tooltip(
            message: 'Lancer les dés',
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: d.accent,
                boxShadow: [
                  BoxShadow(
                    color: d.accent.withValues(alpha: 0.35),
                    blurRadius: kIsWeb ? 6 : 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.casino_rounded,
                size: 22,
                color: Colors.white,
                semanticLabel: 'Lancer les dés',
              ),
            ),
          ),
        ),
      );
    } else if (isActive) {
      // Tour de l'adversaire : pastille teintée non cliquable
      diceFace = Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: d.accent.withValues(alpha: 0.16),
          border: Border.all(
            color: d.accent.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.casino_rounded,
          size: 20,
          color: d.accent,
        ),
      );
    } else {
      // En attente : icon discret
      diceFace = Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: NeonColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: const Icon(
          Icons.casino_outlined,
          size: 18,
          color: NeonColors.textSecondary,
        ),
      );
    }

    if (!showTimer) return diceFace;

    // Timer greffé en pastille sur le bouton — subtil, piloté serveur.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        diceFace,
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeonColors.surface,
              border: Border.all(
                color: d.accent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: widget.turnDeadline != null
                ? TurnTimer(
                    totalSeconds: widget.turnSeconds,
                    deadline: widget.turnDeadline,
                    remainingOverride: widget.turnRemaining,
                    onTimeout: widget.onTimeout,
                    size: 24,
                    activeColor: d.accent,
                  )
                : TurnTimer(
                    totalSeconds: widget.turnSeconds,
                    onTimeout: widget.onTimeout,
                    size: 24,
                    activeColor: d.accent,
                  ),
          ),
        ),
      ],
    );
  }
}

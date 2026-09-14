// ============================================================
// Fichier: dice_3d.dart
// Description: Widget Dice3D — illusion 3D Matrix4 + physique légère.
//              Piloté par Dice3DController : tumbling provisoire puis snap
//              EXACT sur la face serveur. Sans cible serveur, le dé boucle
//              (jamais de face fabriquée) puis retombe au repos connu.
// Auteur: WIWIGA Team
// ============================================================

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'dice_controller.dart';
import 'dice_face.dart';
import 'dice_physics.dart';
import 'dice_pips.dart';
import 'dice_scene.dart';
import 'dice_theme.dart';

/// Dé 3D léger (0 plugin natif, 60 FPS).
///
/// Déclenchement :
/// ```dart
/// controller.roll(faceServeur, rollId: rollId); // résultat connu
/// controller.beginTumble(rollId: rollId);       // puis retarget(face)
/// ```
/// Le widget expose [onRollStart], [onRollEnd] et [isRolling].
/// [onRollEnd] n'est appelé qu'avec une face SERVEUR confirmée.
class Dice3D extends StatefulWidget {
  /// Contrôleur (propriétaire de l'état rolling + anti-rejeu).
  final Dice3DController controller;

  /// Taille de l'arête du dé.
  final double size;

  /// Durée d'animation (configurable, défaut 1.6 s, plage 1.2..2.0 s).
  final Duration duration;

  /// Thème visuel (matière/couleurs).
  final DiceTheme theme;

  /// Force de lancer (1.0 = normal, > 1 = plus loin/fort).
  final double throwStrength;

  /// Appelé au démarrage de l'animation.
  final VoidCallback? onRollStart;

  /// Appelé à la fin avec la face serveur affichée.
  final ValueChanged<int>? onRollEnd;

  const Dice3D({
    super.key,
    required this.controller,
    this.size = 96,
    this.duration = const Duration(milliseconds: 1600),
    this.theme = const DiceTheme.ivory(),
    this.throwStrength = 1.0,
    this.onRollStart,
    this.onRollEnd,
  });

  /// Vrai pendant l'animation (désactive le bouton "Lancer").
  bool get isRolling => controller.isRolling;

  @override
  State<Dice3D> createState() => Dice3DState();
}

/// État public pour tests (pump + lecture [shownFace]).
class Dice3DState extends State<Dice3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final DicePhysics _physics = DicePhysics();
  final math.Random _visualRandom = math.Random();

  DiceState? _sim;
  int _shownFace = 0; // 0 = vide (cohérent avec restingFace initial)
  int? _targetFace;
  double _blend = 0;
  vm.Quaternion? _blendFrom;

  /// Boucles de tumbling sans cible (attente réseau). Borné : au-delà,
  /// le dé retombe au repos serveur connu au lieu de tourner sans fin.
  int _loopsWithoutTarget = 0;
  static const int _maxLoopsWithoutTarget = 3;

  /// Pas de physique (120 Hz, indépendant du refresh écran).
  static const double _step = 1 / 120;

  /// Face actuellement affichée (repos ou fin d'anim = face serveur).
  int get shownFace => _shownFace;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_tick)
      ..addStatusListener(_onStatus);
    widget.controller.addListener(_onControllerSignal);
  }

  void _onControllerSignal() {
    final c = widget.controller;
    if (c.isRolling) {
      // Cible mise à jour à tout moment (roll initial ou retarget serveur).
      // Si le blend avait commencé vers une ancienne cible, on rebase sur
      // l'orientation courante (transition continue, pas de saut visible).
      if (c.face != _targetFace && mounted) {
        setState(() {
          if (_blend > 0) _blendFrom = _sim?.orientation.clone();
          _targetFace = c.face;
        });
      }
      if (!_clock.isAnimating) _startTumble();
      return;
    }
    // Repos demandé (reset externe, fin) : annule toute animation en cours
    // (sinon un reset mid-anim laisserait un snap sur une face périmée),
    // puis reflète l'état serveur sans animation.
    if (_clock.isAnimating || _sim != null || _targetFace != null) {
      _clock.reset();
      _sim = null;
      _targetFace = null;
      _blend = 0;
      _blendFrom = null;
      _loopsWithoutTarget = 0;
      if (mounted) setState(() => _shownFace = c.restingFace);
      return;
    }
    if (_shownFace != c.restingFace && mounted) {
      setState(() => _shownFace = c.restingFace);
    }
  }

  void _startTumble() {
    _targetFace = widget.controller.face;
    _blend = 0;
    _blendFrom = null;
    _loopsWithoutTarget = 0;
    _sim = DiceState(
      position: vm.Vector3.zero(),
      velocity: vm.Vector3.zero(),
      orientation: vm.Quaternion.identity(),
      angularVelocity: vm.Vector3.zero(),
    );
    _physics.throwFromButton(_sim!, _visualRandom, widget.throwStrength);
    _clock.duration = widget.duration;
    _clock.forward(from: 0);
    widget.onRollStart?.call();
  }

  /// Relance un cycle de tumbling (attente du résultat serveur).
  /// Nouvelle impulsion pour un mouvement continu, sans snap.
  void _loopTumble() {
    _blend = 0;
    _blendFrom = null;
    _loopsWithoutTarget++;
    _sim = DiceState(
      position: vm.Vector3.zero(),
      velocity: vm.Vector3.zero(),
      orientation: _sim?.orientation.clone() ?? vm.Quaternion.identity(),
      angularVelocity: vm.Vector3.zero(),
    );
    _physics.throwFromButton(_sim!, _visualRandom, widget.throwStrength);
    _clock.forward(from: 0);
  }

  void _tick() {
    final sim = _sim;
    if (sim == null) return;
    final target = _targetFace;
    final t = _clock.value;
    _stepPhysics(sim);
    // Sans cible serveur : pas de blend (le dé continue de tourner,
    // aucune face ne peut se figer sur du provisoire).
    if (target != null) _applyLanding(sim, target, t);
    if (mounted) setState(() {});
  }

  /// Intègre la physique (phase libre 0..65 %).
  void _stepPhysics(DiceState sim) {
    _physics.update(sim, _step);
    if (_blend == 0) {
      // Tumbling visuel : cycle rapide (effet, pas résultat).
      _shownFace = 1 + _visualRandom.nextInt(6);
    }
  }

  /// Mélange vers la face serveur (65..100 %), puis snap exact.
  void _applyLanding(DiceState sim, int target, double t) {
    if (t <= 0.65) return;
    _blend = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
    _blendFrom ??= sim.orientation.clone();
    sim.orientation =
        DicePhysics.forceLandingOnFace(_blendFrom!, target, _blend);
    DicePhysics.lerpTo(sim.position, vm.Vector3(0, 0.5, 0), _blend * 0.12);
    if (_blend >= 1) _shownFace = target;
  }

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    final face = _targetFace;
    if (face == null) {
      // Toujours pas de cible serveur : boucle (attente réseau), sauf
      // au-delà du budget → retombe au repos serveur connu (honnête :
      // affiche le dernier état serveur, jamais une face inventée).
      // Le reconcile (polling/REST, même roll_id) suivra.
      if (_loopsWithoutTarget >= _maxLoopsWithoutTarget ||
          !widget.controller.isRolling) {
        _giveUpToRest();
        return;
      }
      _loopTumble();
      return;
    }
    _sim = null;
    _targetFace = null;
    _blendFrom = null;
    _loopsWithoutTarget = 0;
    _shownFace = face; // snap exact : face serveur dans 100 % des cas
    widget.controller.notifySettled();
    widget.onRollEnd?.call(face);
  }

  /// Abandon propre : fige sur le repos serveur connu SANS valider de
  /// résultat (pas de onRollEnd : rien n'a été affiché comme résultat).
  void _giveUpToRest() {
    _sim = null;
    _targetFace = null;
    _blend = 0;
    _blendFrom = null;
    _loopsWithoutTarget = 0;
    _shownFace = widget.controller.restingFace;
    if (widget.controller.isRolling) widget.controller.notifySettled();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(Dice3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerSignal);
      widget.controller.addListener(_onControllerSignal);
    }
    if (oldWidget.duration != widget.duration && !_clock.isAnimating) {
      _clock.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerSignal);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = _sim;
    // 0 = vide (repos initial) : orientation neutre, DicePips affiche vide.
    final q = sim?.orientation ??
        (_shownFace == 0
            ? vm.Quaternion.identity()
            : DiceFaceOrientation.forFace(_shownFace));
    final lift = sim != null ? (-sim.position.y * 14).clamp(-46.0, 0.0) : 0.0;
    final driftX = sim != null ? sim.position.x.toDouble() * 14 : 0.0;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size * 1.7,
        height: widget.size * 2.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: widget.size * 0.12,
              child: DiceShadow(
                size: widget.size,
                heightFactor: sim == null ? 1 : (1 + -lift / 60),
              ),
            ),
            Transform.translate(
              offset: Offset(driftX.clamp(-40, 40), lift),
              child: _tilted(q),
            ),
          ],
        ),
      ),
    );
  }

  /// Tilt plateau fixe + rotation physique (perspective légère).
  Widget _tilted(vm.Quaternion q) {
    // Sur web : perspective Matrix4 coûteuse sous CanvasKit → fallback
    // scale/translate simple (même politique que l'ancien dice_3d).
    if (kIsWeb) {
      final s = _clock.isAnimating ? 0.9 + 0.1 * _clock.value : 1.0;
      return Transform.scale(
        scale: s,
        child: DicePips(value: _shownFace, size: widget.size, theme: widget.theme),
      );
    }
    final tilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateX(0.35);
    final spin = Matrix4.compose(
      vm.Vector3.zero(),
      q,
      vm.Vector3.all(1.0),
    );
    return Transform(
      alignment: Alignment.center,
      transform: tilt..multiply(spin),
      child: DicePips(value: _shownFace, size: widget.size, theme: widget.theme),
    );
  }
}

/// Groupe multi-dés synchronisés (stagger 120 ms, 1 contrôleur par dé).
/// Pourquoi un widget dédié : un match utilise N dés, chacun sa face serveur.
class DiceBoard3D extends StatelessWidget {
  final List<Dice3DController> controllers;
  final double diceSize;
  final Duration duration;
  final DiceTheme theme;

  const DiceBoard3D({
    super.key,
    required this.controllers,
    this.diceSize = 72,
    this.duration = const Duration(milliseconds: 1600),
    this.theme = const DiceTheme.ivory(),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Dice3D(
                controller: controllers[i],
                size: diceSize,
                duration: Duration(
                  milliseconds: duration.inMilliseconds + i * 120,
                ),
                theme: theme,
              ),
            ),
        ],
      ),
    );
  }
}

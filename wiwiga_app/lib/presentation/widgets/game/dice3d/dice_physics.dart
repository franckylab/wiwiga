// ============================================================
// Fichier: dice_physics.dart
// Description: Simulation balistique légère (gravité, rebonds, friction,
//              rotation 3 axes). Pur Dart, sans plugin natif : 60 FPS.
//              Ne décide JAMAIS du résultat, uniquement de la trajectoire.
// Auteur: WIWIGA Team
// ============================================================

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

import 'dice_face.dart';

/// État cinématique d'un dé (unités normalisées, arête = 1).
class DiceState {
  /// Position monde (y = hauteur, sol en [DicePhysics.groundY] + 0.5).
  Vector3 position;

  /// Vitesse monde.
  Vector3 velocity;

  /// Orientation monde.
  Quaternion orientation;

  /// Vitesse angulaire monde (rad/s).
  Vector3 angularVelocity;

  DiceState({
    required this.position,
    required this.velocity,
    required this.orientation,
    required this.angularVelocity,
  });

  /// État de repos au centre du tatami.
  factory DiceState.resting({required int face}) {
    return DiceState(
      position: Vector3(0, 0.5, 0),
      velocity: Vector3.zero(),
      orientation: DiceFaceOrientation.forFace(face).clone(),
      angularVelocity: Vector3.zero(),
    );
  }

  /// Clone profond (évite de muter le cache d'orientations).
  DiceState copy() => DiceState(
        position: position.clone(),
        velocity: velocity.clone(),
        orientation: orientation.clone(),
        angularVelocity: angularVelocity.clone(),
      );
}

/// Paramètres exposés et réglables depuis l'UI debug ou les tests.
class DicePhysicsTuning {
  /// Gravité (unités/s²). Défaut calibré pour une chute de ~0.6 s.
  final double gravity;

  /// Restitution au rebond (0 = mou, 1 = élastique). 0.45 = plastique.
  final double restitution;

  /// Friction tangentielle au rebond (0..1).
  final double friction;

  /// Traînée linéaire (air).
  final double linearDamping;

  /// Traînée angulaire (le dé cesse de tourner avant de se poser).
  final double angularDamping;

  const DicePhysicsTuning({
    this.gravity = 22.0,
    this.restitution = 0.45,
    this.friction = 0.25,
    this.linearDamping = 0.15,
    this.angularDamping = 1.6,
  });
}

/// Simulation à pas fixe. Appeler [update] à 120 Hz via accumulateur
/// (stable sur écrans 60/90/120 Hz).
class DicePhysics {
  /// Ordonnée du sol (centre du tatami).
  final double groundY;

  /// Seuil de vitesse sous lequel le dé est considéré posé.
  final double settleEpsilon;

  /// Réglages (gravité, élasticité, friction, forces).
  final DicePhysicsTuning tuning;

  DicePhysics({
    this.groundY = 0.0,
    this.settleEpsilon = 0.05,
    this.tuning = const DicePhysicsTuning(),
  });

  /// Avance la simulation d'un pas [dt] (secondes).
  void update(DiceState s, double dt) {
    _applyGravity(s, dt);
    _applyDamping(s, dt);
    _integratePosition(s, dt);
    _integrateRotation(s, dt);
    _collideGround(s);
    _applyRollingFriction(s, dt);
  }

  /// Vrai si le dé est visuellement posé (vitesse quasi nulle + au sol).
  bool isSettled(DiceState s) {
    const half = 0.5;
    final onGround = (s.position.y - half - groundY).abs() < 0.02;
    return onGround &&
        s.velocity.length < settleEpsilon &&
        s.angularVelocity.length < 0.6;
  }

  /// Impulsion initiale : le dé semble lancé depuis le bouton "Lancer"
  /// (bord bas, proche caméra), pas depuis le centre.
  /// [visualRandom] ne sert qu'à la trajectoire visuelle.
  void throwFromButton(
    DiceState s,
    math.Random visualRandom,
    double strength,
  ) {
    s.position.setValues(0.0, 3.2, 2.4);
    s.velocity.setValues(
      (visualRandom.nextDouble() - 0.5) * 4.0,
      2.0 + visualRandom.nextDouble() * 2.0,
      -(3.0 + visualRandom.nextDouble() * 2.0) * strength,
    );
    s.angularVelocity.setValues(
      6 + visualRandom.nextDouble() * 8,
      6 + visualRandom.nextDouble() * 8,
      6 + visualRandom.nextDouble() * 8,
    );
  }

  /// Mélange cinématique vers la face imposée (0..1).
  /// Pourquoi une méthode statique : le contrôleur l'appelle en fin
  /// d'animation quand la physique a fait son effet, sans la "casser"
  /// (transition continue, pas de téléportation visible).
  /// Implémentation slerp manuelle (vector_math 2.2.0 n'en fournit pas).
  static Quaternion forceLandingOnFace(
    Quaternion current,
    int face,
    double t,
  ) {
    final target = DiceFaceOrientation.forFace(face);
    return slerp(current, target, _easeOutCubic(t.clamp(0, 1)));
  }

  /// Interpolation sphérique entre deux quaternions unitaires.
  static Quaternion slerp(Quaternion a, Quaternion b, double t) {
    var dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    var bx = b.x, by = b.y, bz = b.z, bw = b.w;
    if (dot < 0) {
      // Chemin le plus court (q et -q = même rotation).
      dot = -dot;
      bx = -bx;
      by = -by;
      bz = -bz;
      bw = -bw;
    }
    const epsilon = 1e-6;
    if (dot > 1 - epsilon) {
      // Quasi alignés : lerp normalisée (évite division par ~0).
      final out = Quaternion(
        a.x + (bx - a.x) * t,
        a.y + (by - a.y) * t,
        a.z + (bz - a.z) * t,
        a.w + (bw - a.w) * t,
      )..normalize();
      return out;
    }
    final theta = math.acos(dot.clamp(-1.0, 1.0));
    final sinTheta = math.sin(theta);
    final wa = math.sin((1 - t) * theta) / sinTheta;
    final wb = math.sin(t * theta) / sinTheta;
    return Quaternion(
      a.x * wa + bx * wb,
      a.y * wa + by * wb,
      a.z * wa + bz * wb,
      a.w * wa + bw * wb,
    );
  }

  /// Interpolation linéaire de vecteurs (vector_math 2.2.0 sans lerp).
  static void lerpTo(Vector3 current, Vector3 target, double t) {
    current.x += (target.x - current.x) * t;
    current.y += (target.y - current.y) * t;
    current.z += (target.z - current.z) * t;
  }

  static double _easeOutCubic(double t) =>
      1 - math.pow(1 - t, 3).toDouble();

  void _applyGravity(DiceState s, double dt) {
    s.velocity.y -= tuning.gravity * dt;
  }

  void _applyDamping(DiceState s, double dt) {
    s.velocity.scale(math.exp(-tuning.linearDamping * dt));
  }

  void _integratePosition(DiceState s, double dt) {
    s.position.addScaled(s.velocity, dt);
  }

  void _integrateRotation(DiceState s, double dt) {
    final w = s.angularVelocity.length;
    if (w < 1e-6) return;
    final axis = s.angularVelocity.normalized();
    final dq = Quaternion.axisAngle(axis, w * dt);
    s.orientation = dq * s.orientation..normalize();
    s.angularVelocity.scale(math.exp(-tuning.angularDamping * dt));
  }

  void _collideGround(DiceState s) {
    const half = 0.5;
    if (s.position.y - half > groundY) return;
    s.position.y = groundY + half;
    if (s.velocity.y < 0) {
      // Sous le seuil d'impact : contact reposant (évite le micro-rebond
      // permanent gravité/restitution qui empêche isSettled).
      if (s.velocity.y.abs() < 1.0) {
        s.velocity.y = 0;
      } else {
        s.velocity.y = -s.velocity.y * tuning.restitution;
      }
    }
    s.velocity.x *= (1 - tuning.friction);
    s.velocity.z *= (1 - tuning.friction);
    s.angularVelocity.scale(0.82);
    if (s.velocity.length < settleEpsilon) s.velocity.setZero();
  }

  /// Friction de roulement continue au sol (sans elle, le dé glisse
  /// indéfiniment sur x/z et isSettled ne devient jamais vrai).
  void _applyRollingFriction(DiceState s, double dt) {
    const half = 0.5;
    final onGround = (s.position.y - half - groundY).abs() < 0.03;
    if (!onGround) return;
    // Amortissement horizontal fort + angulaire renforcé au contact.
    final k = math.exp(-3.0 * dt);
    s.velocity.x *= k;
    s.velocity.z *= k;
    s.angularVelocity.scale(math.exp(-2.0 * dt));
    if (s.velocity.length < settleEpsilon) {
      s.velocity.setZero();
    }
  }
}

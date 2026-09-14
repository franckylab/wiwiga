// Tests unitaires : face + physique.
// Critère : la face finale imposée est respectée à 100 %, le sol
// n'est jamais traversé, les paramètres sont exposés.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_face.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_physics.dart';

DiceState _flyingState() => DiceState(
      position: Vector3(0, 3.2, 2.4),
      velocity: Vector3(1.0, 2.0, -3.0),
      orientation: Quaternion.identity(),
      angularVelocity: Vector3(7, 8, 9),
    );

void main() {
  group('DiceFace', () {
    test('accepte 1..6, rejette le reste', () {
      for (var f = 1; f <= 6; f++) {
        expect(DiceFace.isValid(f), isTrue);
        expect(DiceFace.fromServer(f).value, f);
      }
      expect(DiceFace.isValid(0), isFalse);
      expect(DiceFace.isValid(7), isFalse);
      expect(() => DiceFace.fromServer(0), throwsArgumentError);
      expect(() => DiceFace.fromServer(9), throwsArgumentError);
    });

    test('orientations cibles distinctes par face', () {
      final seen = <String>{};
      for (var f = 1; f <= 6; f++) {
        final q = DiceFaceOrientation.forFace(f);
        expect(q.length, closeTo(1.0, 1e-9)); // quaternion unitaire
        seen.add('${q.x.toStringAsFixed(4)},${q.y.toStringAsFixed(4)},'
            '${q.z.toStringAsFixed(4)},${q.w.toStringAsFixed(4)}');
      }
      expect(seen.length, 6);
    });
  });

  group('DicePhysics.update', () {
    test('la gravité fait chuter le dé', () {
      final physics = DicePhysics();
      final s = _flyingState();
      final y0 = s.position.y;
      physics.update(s, 1 / 120);
      expect(s.velocity.y, lessThan(2.0));
      expect(s.position.y, lessThan(y0 + 0.05));
    });

    test('le sol n\'est jamais traversé (600 pas)', () {
      final physics = DicePhysics();
      final s = _flyingState();
      for (var i = 0; i < 600; i++) {
        physics.update(s, 1 / 120);
        expect(s.position.y, greaterThanOrEqualTo(0.5 - 1e-6));
      }
    });

    test('le dé finit posé (vitesse ~ nulle)', () {
      final physics = DicePhysics();
      final s = _flyingState();
      for (var i = 0; i < 1200; i++) {
        physics.update(s, 1 / 120);
      }
      expect(physics.isSettled(s), isTrue);
    });

    test('paramètres exposés : restitution 0 = pas de rebond', () {
      final physics = DicePhysics(
        tuning: const DicePhysicsTuning(restitution: 0),
      );
      final s = DiceState(
        position: Vector3(0, 0.6, 0),
        velocity: Vector3(0, -5, 0),
        orientation: Quaternion.identity(),
        angularVelocity: Vector3.zero(),
      );
      for (var i = 0; i < 120; i++) {
        physics.update(s, 1 / 120);
      }
      expect(s.velocity.y.abs(), lessThan(0.5));
    });

    test('throwFromButton part du bouton, pas du centre', () {
      final physics = DicePhysics();
      final s = DiceState(
        position: Vector3.zero(),
        velocity: Vector3.zero(),
        orientation: Quaternion.identity(),
        angularVelocity: Vector3.zero(),
      );
      physics.throwFromButton(s, math.Random(42), 1.0);
      expect(s.position.y, greaterThan(2.0)); // en hauteur
      expect(s.position.z, greaterThan(1.0)); // proche caméra
      expect(s.velocity.z, lessThan(0)); // vers le tatami
      expect(s.angularVelocity.length, greaterThan(5)); // rotation 3 axes
    });
  });

  group('DicePhysics.forceLandingOnFace', () {
    test('t=1 donne exactement l\'orientation cible (6 faces)', () {
      final start = Quaternion.euler(1.2, 0.7, -0.4);
      for (var f = 1; f <= 6; f++) {
        final q = DicePhysics.forceLandingOnFace(start, f, 1.0);
        final target = DiceFaceOrientation.forFace(f);
        final diff = (q.x - target.x).abs() +
            (q.y - target.y).abs() +
            (q.z - target.z).abs() +
            (q.w - target.w).abs();
        // Slerp peut donner q ou -q (même rotation) : accepter les deux.
        final diffNeg = (q.x + target.x).abs() +
            (q.y + target.y).abs() +
            (q.z + target.z).abs() +
            (q.w + target.w).abs();
        expect(diff < 1e-9 || diffNeg < 1e-9, isTrue, reason: 'face $f');
      }
    });

    test('t=0 conserve l\'orientation courante', () {
      final start = Quaternion.euler(0.5, 0.2, 0.1)..normalize();
      final q = DicePhysics.forceLandingOnFace(start, 6, 0.0);
      expect((q.x - start.x).abs(), lessThan(1e-9));
    });

    test('la progression est monotone vers la cible', () {
      final start = Quaternion.euler(1.0, 1.0, 1.0)..normalize();
      final target = DiceFaceOrientation.forFace(4);
      double prev = double.infinity;
      for (final t in [0.25, 0.5, 0.75, 1.0]) {
        final q = DicePhysics.forceLandingOnFace(start, 4, t);
        final d = (q.x - target.x).abs() + (q.w - target.w).abs();
        expect(d, lessThan(prev));
        prev = d;
      }
    });
  });
}

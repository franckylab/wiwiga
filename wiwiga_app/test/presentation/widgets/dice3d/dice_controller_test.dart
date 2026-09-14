// Tests : Dice3DController (anti double-clic, anti rejeu, tumbling
// provisoire, retarget serveur, repos sans animation).
// Le transport (WS/REST) est testé côté backend (ExUnit : channel e2e).

import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_controller.dart';

void main() {
  group('Dice3DController', () {
    test('roll valide démarre, notifySettled termine', () {
      final c = Dice3DController();
      expect(c.isRolling, isFalse);
      expect(c.roll(3, rollId: 'r1'), isTrue);
      expect(c.isRolling, isTrue);
      expect(c.face, 3);
      expect(c.hasServerTarget, isTrue);
      c.notifySettled();
      expect(c.isRolling, isFalse);
      c.dispose();
    });

    test('double-clic refusé pendant l\'animation', () {
      final c = Dice3DController();
      expect(c.roll(3, rollId: 'r1'), isTrue);
      expect(c.roll(5, rollId: 'r2'), isFalse); // en cours
      expect(c.beginTumble(rollId: 'r3'), isFalse); // en cours aussi
      expect(c.face, 3); // la 1re face est conservée
      c.dispose();
    });

    test('rejeu du même roll_id refusé après fin', () {
      final c = Dice3DController();
      expect(c.roll(3, rollId: 'dup'), isTrue);
      c.notifySettled();
      expect(c.roll(5, rollId: 'dup'), isFalse); // anti rejeu
      expect(c.beginTumble(rollId: 'dup'), isFalse); // anti rejeu aussi
      expect(c.roll(5, rollId: 'fresh'), isTrue);
      c.dispose();
    });

    test('faces invalides et roll_id vide refusés', () {
      final c = Dice3DController();
      expect(c.roll(0, rollId: 'a'), isFalse);
      expect(c.roll(7, rollId: 'a'), isFalse);
      expect(c.roll(3, rollId: ''), isFalse);
      expect(c.beginTumble(rollId: ''), isFalse);
      expect(c.isRolling, isFalse);
      c.dispose();
    });

    test('beginTumble démarre sans cible (pas de face fabriquée)', () {
      final c = Dice3DController();
      expect(c.beginTumble(rollId: 'prov-1'), isTrue);
      expect(c.isRolling, isTrue);
      expect(c.face, isNull); // aucune cible : rien à figer
      expect(c.hasServerTarget, isFalse);
      c.dispose();
    });

    test('retarget confirme la face serveur pendant le tumbling', () {
      final c = Dice3DController();
      expect(c.retarget(5), isFalse); // pas en cours : refusé
      expect(c.beginTumble(rollId: 'prov-2'), isTrue);
      expect(c.retarget(0), isFalse); // invalide
      expect(c.retarget(7), isFalse); // invalide
      expect(c.retarget(5), isTrue);
      expect(c.face, 5); // le blend final utilisera la face serveur
      expect(c.hasServerTarget, isTrue);
      c.notifySettled();
      expect(c.restingFace, 5);
      c.dispose();
    });

    test('setRestingFace fige sans animation (sync REST)', () {
      final c = Dice3DController();
      expect(c.restingFace, 0); // vide initial
      c.setRestingFace(4);
      expect(c.restingFace, 4);
      expect(c.isRolling, isFalse); // aucune animation démarrée
      c.setRestingFace(9); // hors borne : ignoré
      expect(c.restingFace, 4);
      c.dispose();
    });

    test('reset vide le tatami même mid-anim', () {
      final c = Dice3DController();
      expect(c.beginTumble(rollId: 'rs-1'), isTrue);
      c.reset();
      expect(c.restingFace, 0);
      expect(c.isRolling, isFalse);
      expect(c.face, isNull);
      expect(c.hasServerTarget, isFalse);
      c.dispose();
    });
  });
}

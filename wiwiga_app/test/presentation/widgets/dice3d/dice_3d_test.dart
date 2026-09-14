// Tests widget Dice3D : face finale = face serveur, tumbling provisoire
// sans face fabriquée, reset mid-anim, callbacks, pas de fuite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_3d.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_controller.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_pips.dart';
import 'package:wiwiga/presentation/widgets/game/dice3d/dice_theme.dart';

Widget _harness({
  required Dice3DController controller,
  Duration duration = const Duration(milliseconds: 300),
  ValueChanged<int>? onRollEnd,
  VoidCallback? onRollStart,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Dice3D(
        controller: controller,
        duration: duration,
        onRollEnd: onRollEnd,
        onRollStart: onRollStart,
      ),
    ),
  );
}

void main() {
  group('Dice3D widget', () {
    testWidgets('se termine exactement sur la face serveur', (t) async {
      final controller = Dice3DController();
      int? endedWith;
      await t.pumpWidget(
        _harness(controller: controller, onRollEnd: (f) => endedWith = f),
      );
      expect(controller.isRolling, isFalse);

      controller.roll(5, rollId: 'w1');
      await t.pump(); // démarre l'anim
      expect(controller.isRolling, isTrue);
      await t.pumpAndSettle();
      expect(endedWith, 5);
      expect(controller.isRolling, isFalse);
      controller.dispose();
    });

    testWidgets('onRollStart appelé une fois par lancer', (t) async {
      final controller = Dice3DController();
      var starts = 0;
      await t.pumpWidget(
        _harness(controller: controller, onRollStart: () => starts++),
      );
      controller.roll(2, rollId: 'w2');
      await t.pumpAndSettle();
      expect(starts, 1);
      controller.dispose();
    });

    testWidgets('100 lancers sans fuite ni erreur', (t) async {
      final controller = Dice3DController();
      await t.pumpWidget(_harness(controller: controller));
      for (var i = 1; i <= 100; i++) {
        expect(controller.roll((i % 6) + 1, rollId: 'bulk-$i'), isTrue);
        await t.pumpAndSettle();
        expect(controller.isRolling, isFalse);
      }
      controller.dispose();
    });

    testWidgets('rejet d\'un 2e roll pendant l\'anim (UI)', (t) async {
      final controller = Dice3DController();
      await t.pumpWidget(_harness(controller: controller));
      expect(controller.roll(1, rollId: 'u1'), isTrue);
      expect(controller.roll(6, rollId: 'u2'), isFalse);
      await t.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('beginTumble + retarget : fin sur la face serveur', (t) async {
      final controller = Dice3DController();
      int? endedWith;
      await t.pumpWidget(
        _harness(controller: controller, onRollEnd: (f) => endedWith = f),
      );
      // dice_rolling : tumbling SANS cible (rien à figer).
      expect(controller.beginTumble(rollId: 'prov-x#0'), isTrue);
      await t.pump(const Duration(milliseconds: 100));
      // dice_rolled : le serveur impose 6 -> re-cible avant le blend.
      expect(controller.retarget(6), isTrue);
      await t.pumpAndSettle();
      expect(endedWith, 6);
      expect(controller.restingFace, 6);
      controller.dispose();
    });

    testWidgets('sans cible serveur : pas de onRollEnd, retour au repos',
        (t) async {
      final controller = Dice3DController();
      var ends = 0;
      controller.setRestingFace(4); // dernier état serveur connu
      await t.pumpWidget(
        _harness(controller: controller, onRollEnd: (_) => ends++),
      );
      expect(controller.beginTumble(rollId: 'prov-silent'), isTrue);
      await t.pumpAndSettle(); // 1 + 3 boucles puis abandon
      expect(ends, 0); // AUCUN résultat validé sans serveur
      expect(controller.isRolling, isFalse);
      final state = t.state<Dice3DState>(find.byType(Dice3D));
      expect(state.shownFace, 4); // retombe sur le repos serveur connu
      controller.dispose();
    });

    testWidgets('reset mid-anim : annule, pas de snap périmé', (t) async {
      final controller = Dice3DController();
      int? endedWith;
      await t.pumpWidget(
        _harness(controller: controller, onRollEnd: (f) => endedWith = f),
      );
      expect(controller.beginTumble(rollId: 'prov-r'), isTrue);
      await t.pump(const Duration(milliseconds: 100));
      expect(controller.retarget(6), isTrue);
      await t.pump(const Duration(milliseconds: 100));
      controller.reset(); // nouveau set avant la fin de l'anim
      await t.pumpAndSettle();
      expect(endedWith, isNull); // pas de résultat validé
      expect(controller.isRolling, isFalse);
      final state = t.state<Dice3DState>(find.byType(Dice3D));
      expect(state.shownFace, 0); // tatami vidé
      controller.dispose();
    });

    testWidgets('setRestingFace affiche sans animer', (t) async {
      final controller = Dice3DController();
      await t.pumpWidget(_harness(controller: controller));
      controller.setRestingFace(3); // sync REST : pas d'anim
      await t.pump();
      expect(controller.isRolling, isFalse);
      final state = t.state<Dice3DState>(find.byType(Dice3D));
      expect(state.shownFace, 3);
      controller.dispose();
    });
  });

  group('DicePips', () {
    testWidgets('affiche chaque face 1..6 sans erreur', (t) async {
      for (var v = 1; v <= 6; v++) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicePips(
                value: v,
                size: 64,
                theme: const DiceTheme.ivory(),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('thème néon accepté', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DicePips(value: 6, size: 64, theme: DiceTheme.neon()),
          ),
        ),
      );
      expect(t.takeException(), isNull);
    });
  });
}

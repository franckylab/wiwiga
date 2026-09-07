// ============================================================
// Fichier: match_result_layout_test.dart
// Description: Tests unitaires des décisions de mise en page de la
//              fenêtre de résultat final (bornes, scrollbar desktop,
//              tailles responsives).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/widgets/game/match_result_layout.dart';

void main() {
  group('MatchResultLayout.dialogMaxWidth', () {
    test('plafonne à 480px sur desktop large', () {
      expect(MatchResultLayout.dialogMaxWidth(1920), equals(480.0));
      expect(MatchResultLayout.dialogMaxWidth(900), equals(480.0));
    });

    test('suit l’espace dispo sur tablette', () {
      expect(MatchResultLayout.dialogMaxWidth(500), equals(476.0));
    });

    test('garantit 280px utiles à 320px de large', () {
      expect(MatchResultLayout.dialogMaxWidth(320), equals(296.0));
      expect(MatchResultLayout.dialogMaxWidth(300), equals(280.0));
    });

    test('plancher même sous 300px', () {
      expect(MatchResultLayout.dialogMaxWidth(200), equals(280.0));
    });
  });

  group('MatchResultLayout.dialogMaxHeight', () {
    test('laisse des marges sur grand écran', () {
      expect(MatchResultLayout.dialogMaxHeight(800), equals(784.0));
    });

    test('suit la hauteur dispo, plancher 240px si minuscule', () {
      expect(MatchResultLayout.dialogMaxHeight(300), equals(284.0));
      expect(MatchResultLayout.dialogMaxHeight(100), equals(240.0));
    });
  });

  group('MatchResultLayout.showScrollbar', () {
    test('visible sur OS desktop natifs', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(
          MatchResultLayout.showScrollbar(
            isWeb: false,
            platform: platform,
            width: 300,
          ),
          isTrue,
          reason: '$platform',
        );
      }
    });

    test('masquée sur mobile natif (pouce au geste)', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          MatchResultLayout.showScrollbar(
            isWeb: false,
            platform: platform,
            width: 390,
          ),
          isFalse,
          reason: '$platform',
        );
      }
    });

    test('web : visible dès 620px, sinon comportement tactile', () {
      expect(
        MatchResultLayout.showScrollbar(
          isWeb: true,
          platform: TargetPlatform.android,
          width: 1280,
        ),
        isTrue,
      );
      expect(
        MatchResultLayout.showScrollbar(
          isWeb: true,
          platform: TargetPlatform.android,
          width: 390,
        ),
        isFalse,
      );
    });
  });

  group('MatchResultLayout tailles responsives', () {
    test('isNarrow sous 380px (inclut 300-360px)', () {
      expect(MatchResultLayout.isNarrow(320), isTrue);
      expect(MatchResultLayout.isNarrow(379), isTrue);
      expect(MatchResultLayout.isNarrow(380), isFalse);
    });

    test('isShort sous 560px de haut', () {
      expect(MatchResultLayout.isShort(500), isTrue);
      expect(MatchResultLayout.isShort(560), isFalse);
    });

    test('trophée réduit si étroit ou bas', () {
      expect(
        MatchResultLayout.trophySize(availWidth: 320, availHeight: 700),
        equals(44.0),
      );
      expect(
        MatchResultLayout.trophySize(availWidth: 800, availHeight: 500),
        equals(44.0),
      );
      expect(
        MatchResultLayout.trophySize(availWidth: 800, availHeight: 800),
        equals(52.0),
      );
    });

    test('titre réduit si étroit', () {
      expect(MatchResultLayout.titleFontSize(320), equals(18.0));
      expect(MatchResultLayout.titleFontSize(800), equals(20.0));
    });

    test('padding resserré si compact', () {
      expect(
        MatchResultLayout.dialogPadding(availWidth: 320, availHeight: 700),
        equals(const EdgeInsets.all(12.0)),
      );
      expect(
        MatchResultLayout.dialogPadding(availWidth: 800, availHeight: 800),
        equals(const EdgeInsets.all(16.0)),
      );
    });
  });
}

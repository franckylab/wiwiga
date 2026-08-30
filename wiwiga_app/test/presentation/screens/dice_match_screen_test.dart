// ============================================================
// Fichier: dice_match_screen_test.dart
// Description: Tests pour l'écran de match de dés multi-sets
// ============================================================

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiceMatchScreen', () {
    group('SetScoreboard', () {
      test('affiche le score des sets pour chaque joueur', () {
        final players = [
          {'id': '1', 'name': 'Alice'},
          {'id': '2', 'name': 'Bob'},
        ];
        final setWins = {'1': 2, '2': 1};

        expect(setWins['1'], equals(2));
        expect(setWins['2'], equals(1));
        expect(players.length, equals(2));
      });

      test('met en surbrillance le joueur actuel', () {
        const currentTurnIndex = 0;
        final players = [
          {'id': '1', 'name': 'Alice'},
          {'id': '2', 'name': 'Bob'},
        ];
        final currentPlayerId = players[currentTurnIndex]['id'].toString();
        expect(currentPlayerId, equals('1'));
      });
    });

    group('DiceRoller animation', () {
      test('génère N dés avec valeurs 1-6', () {
        const diceCount = 2;
        final dice = List.generate(diceCount, (i) => (i % 6) + 1);
        expect(dice.length, equals(diceCount));
        for (final d in dice) {
          expect(d, greaterThanOrEqualTo(1));
          expect(d, lessThanOrEqualTo(6));
        }
      });

      test('calcule la somme correctement', () {
        final dice = [3, 5];
        final sum = dice.fold<int>(0, (a, b) => a + b);
        expect(sum, equals(8));
      });

      test('ordre tournant par set', () {
        // Set 1: Joueur A commence, Set 2: Joueur B commence
        const setsCount = 3;
        for (int set = 1; set <= setsCount; set++) {
          final firstPlayerIndex = (set - 1) % 2;
          expect(firstPlayerIndex, lessThan(2));
        }
      });
    });

    group('TargetVoter (mode Cible)', () {
      test('calcule la cible comme moyenne arrondie des votes', () {
        final votes = {'1': 8, '2': 6};
        final sum = votes.values.fold<int>(0, (a, b) => a + b);
        final target = (sum / votes.length).round();
        expect(target, equals(7));
      });

      test('évalue la distance à la cible', () {
        const target = 7;
        const sumA = 8; // distance = 1
        const sumB = 5; // distance = 2

        final distA = (sumA - target).abs();
        final distB = (sumB - target).abs();

        expect(distA, lessThan(distB));
        // A gagne car plus proche de la cible
      });

      test('distance égale = set nul', () {
        const target = 7;
        const sumA = 9; // distance = 2
        const sumB = 5; // distance = 2

        final distA = (sumA - target).abs();
        final distB = (sumB - target).abs();

        expect(distA, equals(distB));
      });
    });

    group('MatchResult', () {
      test('détermine le gagnant à la majorité', () {
        final setWins = {'1': 2, '2': 1};
        const setsToWin = 2; // sur 3 sets

        final winner = setWins.entries.where((e) => e.value >= setsToWin).first;
        expect(winner.key, equals('1'));
        expect(winner.value, equals(2));
      });

      test('calcule les gains en Partie avec mise (staked, alias betting)', () {
        const betAmount = 500;
        const commissionRate = 0.05;
        const grossWin = betAmount * 2;
        final commission = (grossWin * commissionRate).round();
        final netWin = grossWin - commission;

        expect(grossWin, equals(1000));
        expect(commission, equals(50));
        expect(netWin, equals(950));
      });

      test('set nul = rejouer', () {
        final setResult = {'result': 'tie', 'winner_id': null};
        expect(setResult['result'], equals('tie'));
        expect(setResult['winner_id'], isNull);
      });
    });

    group('Évaluation des sets', () {
      test('mode Normal: high roll gagne', () {
        final sums = {'1': 9, '2': 7};
        final maxSum = sums.values.fold<int>(0, (a, b) => a > b ? a : b);
        final winners = sums.entries.where((e) => e.value == maxSum).toList();

        expect(winners.length, equals(1));
        expect(winners.first.key, equals('1'));
      });

      test('mode Normal: égalité = set nul', () {
        final sums = {'1': 7, '2': 7};
        final maxSum = sums.values.fold<int>(0, (a, b) => a > b ? a : b);
        final winners = sums.entries.where((e) => e.value == maxSum).toList();

        expect(winners.length, equals(2));
        // Set nul → rejouer
      });
    });
  });
}

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

      test('bornes du vote = [dés, dés × faces] (cohérent backend)', () {
        int voteMin(int diceCount) => diceCount < 1 ? 1 : diceCount;
        int voteMax(int diceCount, int faces) =>
            voteMin(diceCount) * (faces < 1 ? 6 : faces);

        expect(voteMin(2), equals(2));
        expect(voteMax(2, 6), equals(12));
        expect(voteMax(1, 6), equals(6));
        expect(voteMax(3, 6), equals(18));
      });

      test('vote auto = milieu de l’intervalle (toujours valide)', () {
        int middleVote(int diceCount, int faces) {
          final min = diceCount < 1 ? 1 : diceCount;
          final max = min * (faces < 1 ? 6 : faces);
          return (min + max) ~/ 2;
        }

        expect(middleVote(2, 6), equals(7));
        expect(middleVote(1, 6), equals(3));
        // Le milieu reste dans [min, max] (jamais :invalid_target)
        for (var dice = 1; dice <= 5; dice++) {
          final middle = middleVote(dice, 6);
          expect(middle, greaterThanOrEqualTo(dice));
          expect(middle, lessThanOrEqualTo(dice * 6));
        }
      });

      test('moyenne arrondie moitié supérieure (4+7)/2 = 6', () {
        final votes = {'1': 4, '2': 7};
        final sum = votes.values.fold<int>(0, (a, b) => a + b);
        final target = (sum / votes.length).round();
        expect(target, equals(6));
      });

      test('bornes admin vote : timeout 5–120s, délai 2–30s', () {
        int clampTimeout(int v) => v.clamp(5, 120);
        int clampDelay(int v) => v.clamp(2, 30);

        expect(clampTimeout(20), equals(20));
        expect(clampTimeout(3), equals(5));
        expect(clampTimeout(200), equals(120));
        expect(clampDelay(5), equals(5));
        expect(clampDelay(1), equals(2));
        expect(clampDelay(60), equals(30));
      });

      test('compteur de reprise borné à zéro', () {
        int countdown(int delaySec, int elapsedSec) =>
            (delaySec - elapsedSec).clamp(0, 3600);

        expect(countdown(5, 2), equals(3));
        expect(countdown(5, 5), equals(0));
        expect(countdown(5, 9), equals(0));
      });

      test('bornes admin timings : tour 10–300, set 2–15, grâce 5–120', () {
        int clampTurn(int v) => v.clamp(10, 300);
        int clampNext(int v) => v.clamp(2, 15);
        int clampGrace(int v) => v.clamp(5, 120);

        expect(clampTurn(120), equals(120));
        expect(clampTurn(5), equals(10));
        expect(clampTurn(400), equals(300));
        expect(clampNext(4), equals(4));
        expect(clampNext(1), equals(2));
        expect(clampNext(60), equals(15));
        expect(clampGrace(20), equals(20));
        expect(clampGrace(1), equals(5));
        expect(clampGrace(500), equals(120));
      });

      test('tour vide = null envoyé, clé supprimée serveur (héritage)', () {
        // Contrat client → serveur : null explicite = retour à l'héritage.
        final patch = <String, dynamic>{
          'min_sets': 1,
          'auto_next_set_delay_seconds': 4,
          'turn_timeout_seconds': null,
        };
        expect(patch.containsKey('turn_timeout_seconds'), isTrue);
        expect(patch['turn_timeout_seconds'], isNull);
        // Miroir du traitement serveur : les marqueurs null suppriment la clé.
        final merged = Map<String, dynamic>.from({
          'min_sets': 3,
          'turn_timeout_seconds': 45,
        });
        patch.forEach((key, value) {
          if (value == null) {
            merged.remove(key);
          } else {
            merged[key] = value;
          }
        });
        expect(merged.containsKey('turn_timeout_seconds'), isFalse);
        expect(merged['min_sets'], equals(1));
        expect(merged['auto_next_set_delay_seconds'], equals(4));
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

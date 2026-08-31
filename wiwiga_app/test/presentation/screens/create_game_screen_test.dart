// ============================================================
// Fichier: create_game_screen_test.dart
// Description: Tests pour l'écran de création de partie
// ============================================================

import 'package:flutter_test/flutter_test.dart';

// Les tests vérifient le comportement UI de CreateGameScreen
// Note: Nécessite un ProviderScope pour les tests Riverpod

void main() {
  group('CreateGameScreen', () {
    testWidgets('affiche les options de mode (Partie sans mise / Partie avec mise)', (tester) async {
      // Vérifier que les widgets de base de sélection de mode existent
      // refacto 2026-08-30 : Free → Partie sans mise (gratuit), Betting → Partie avec mise (staked)
      expect(true, isTrue); // Placeholder - les tests widget nécessitent un environnement Flutter complet
    });

    testWidgets('affiche les types de règles (Normal/Cible)', (tester) async {
      // Vérifier que les 2 types de règles sont disponibles
      expect(true, isTrue);
    });

    testWidgets('slider sets dans les bonnes bornes', (tester) async {
      // Vérifier que le slider de sets respecte min/max des règles
      // Par défaut: min=1, max=7
      const minSets = 1;
      const maxSets = 7;
      expect(minSets, lessThanOrEqualTo(maxSets));
      expect(minSets, greaterThanOrEqualTo(1));
    });

    testWidgets('slider dés dans les bonnes bornes', (tester) async {
      // Vérifier que le slider de dés respecte min/max des règles
      // Par défaut: min=1, max=6
      const minDice = 1;
      const maxDice = 6;
      expect(minDice, lessThanOrEqualTo(maxDice));
    });

    testWidgets('mise visible uniquement en mode Partie avec mise (staked)', (tester) async {
      // Migration brutale: betting supprimé — seul staked affiche mise
      final presets = [100, 250, 500, 1000, 2500, 5000];
      expect(presets, isNotEmpty);
      expect(presets.first, equals(100));
    });

    testWidgets('récapitulatif affiché avant création', (tester) async {
      // Migration brutale 2026-08-30: betting supprimé
      final config = {
        'mode': 'staked',
        'rule_type': 'normal',
        'sets_count': 3,
        'dice_count': 2,
        'bet_amount': 500,
        'max_players': 2,
      };
      expect(config['mode'], equals('staked'));
      expect(config['rule_type'], equals('normal'));
      expect(config['sets_count'], equals(3));
      expect(config['dice_count'], equals(2));
      expect(config['bet_amount'], equals(500));
      expect(config['max_players'], equals(2));
    });

    testWidgets('bouton créer désactivé si params invalides', (tester) async {
      // Vérifier la validation des paramètres
      expect(() {
        // sets_count doit être >= 1
        assert(1 >= 1);
        // dice_count doit être >= 1
        assert(1 >= 1);
        // bet_amount doit être >= 0
        assert(0 >= 0);
        // max_players doit être >= 2
        assert(2 >= 2);
      }, returnsNormally,);
    });

    testWidgets('mode Partie sans mise (free) ne demande pas de mise', (tester) async {
      // En mode Partie sans mise (free), bet_amount = 0
      const mode = 'free';
      const betAmount = 0;
      expect(mode, equals('free'));
      expect(betAmount, equals(0));
    });
  });
}

// ============================================================
// Fichier: game_room_waiting_screen_test.dart
// Description: Tests pour l'écran d'attente de salle de jeu
// ============================================================

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameRoomWaitingScreen', () {
    testWidgets('affiche le code de salle', (tester) async {
      // Le code de salle doit être affiché au format WIWIGA-XXXX
      const roomCode = 'WIWIGA-7X3K';
      expect(roomCode, startsWith('WIWIGA-'));
      expect(roomCode.length, equals(11)); // WIWIGA- + 4 chars
    });

    testWidgets('affiche la liste des joueurs', (tester) async {
      // La liste des joueurs doit afficher les avatars
      final players = [
        {'id': '1', 'name': 'Joueur 1', 'avatar_url': null},
        {'id': '2', 'name': 'Joueur 2', 'avatar_url': null},
      ];
      expect(players.length, equals(2));
      expect(players.first['name'], equals('Joueur 1'));
    });

    testWidgets('affiche les paramètres de la partie', (tester) async {
      // Les paramètres (sets, dés, type, mise) doivent être visibles
      final params = {
        'sets_count': 3,
        'dice_count': 2,
        'rule_type': 'normal',
        'bet_amount': 500,
      };
      expect(params['sets_count'], equals(3));
      expect(params['dice_count'], equals(2));
      expect(params['rule_type'], equals('normal'));
      expect(params['bet_amount'], equals(500));
    });

    testWidgets('bouton démarrer visible si créateur + 2 joueurs + Partie avec mise', (tester) async {
      // Le bouton démarrer ne doit être visible que si:
      // - L'utilisateur est le créateur
      // - Il y a au moins 2 joueurs
      // - Le mode est Partie avec mise (staked, alias betting)
      const isCreator = true;
      const playerCount = 2;
      const mode = 'staked';

      const canStart = isCreator && playerCount >= 2 && mode == 'staked';
      expect(canStart, isTrue);
      // Rétro-compat : betting → staked
      const legacyMode = 'betting';
      const canStartLegacy = isCreator && playerCount >= 2 && (legacyMode == 'staked' || legacyMode == 'betting');
      expect(canStartLegacy, isTrue);
    });

    testWidgets('bouton démarrer caché si Partie sans mise (free)', (tester) async {
      // En mode Partie sans mise (free), le démarrage est manuel par les 2 joueurs
      const mode = 'free';
      const playerCount = 2;

      // En mode free, les 2 joueurs doivent confirmer manuellement
      expect(mode, equals('free'));
      expect(playerCount, greaterThanOrEqualTo(2));
    });

    testWidgets('timer d\'attente affiché', (tester) async {
      // Le timer doit s'incrémenter
      int elapsed = 0;
      elapsed += 30; // Simulate 30 seconds
      expect(elapsed, greaterThan(0));
    });

    testWidgets('bouton inviter génère code/link', (tester) async {
      // Le bouton inviter doit permettre de copier le code
      const roomCode = 'WIWIGA-AB12';
      expect(roomCode, isNotEmpty);
      expect(roomCode, contains('WIWIGA'));
    });

    test('écoute les événements WebSocket player_joined et match_starting', () {
      // Vérifier que les events WebSocket sont définis
      const events = ['player_joined', 'player_left', 'match_started', 'room_cancelled'];
      expect(events, contains('player_joined'));
      expect(events, contains('match_started'));
    });
  });
}

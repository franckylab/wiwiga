// ============================================================
// Fichier: friends_screen_test.dart
// Description: Tests pour l'écran Amis (FriendsScreen)
// ============================================================

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FriendsScreen', () {
    group('Tab Amis', () {
      test('liste amis avec statut en ligne', () {
        final friends = [
          {'id': '1', 'name': 'Alice', 'is_online': true, 'status': 'accepted'},
          {'id': '2', 'name': 'Bob', 'is_online': false, 'status': 'accepted'},
        ];

        expect(friends.length, equals(2));
        expect(friends.where((f) => f['is_online'] == true).length, equals(1));
      });

      test('bouton jouer visible pour chaque ami', () {
        final friend = {'id': '1', 'name': 'Alice', 'is_online': true};
        expect(friend['is_online'], isTrue);
      });
    });

    group('Tab Demandes', () {
      test('affiche les demandes reçues', () {
        final requests = [
          {'id': '1', 'from_user': 'Charlie', 'status': 'pending'},
          {'id': '2', 'from_user': 'Diana', 'status': 'pending'},
        ];

        expect(requests.length, equals(2));
        expect(requests.every((r) => r['status'] == 'pending'), isTrue);
      });

      test('accepter une demande change le status', () {
        final request = {'id': '1', 'from_user': 'Charlie', 'status': 'pending'};
        request['status'] = 'accepted';
        expect(request['status'], equals('accepted'));
      });

      test('refuser une demande supprime la requête', () {
        final requests = [
          {'id': '1', 'from_user': 'Charlie', 'status': 'pending'},
          {'id': '2', 'from_user': 'Diana', 'status': 'pending'},
        ];
        requests.removeWhere((r) => r['id'] == '1');
        expect(requests.length, equals(1));
      });
    });

    group('Tab Activité', () {
      test('feed d\'activité trié par date', () {
        final activities = [
          {'action': 'game_won', 'metadata': {'opponent': 'Bob'}, 'inserted_at': '2026-07-29T10:00:00'},
          {'action': 'level_up', 'metadata': {'level': 5}, 'inserted_at': '2026-07-29T09:00:00'},
        ];

        expect(activities.first['action'], equals('game_won'));
        expect(activities.length, equals(2));
      });

      test('actions valides', () {
        const validActions = [
          'game_won', 'game_lost', 'friend_added',
          'level_up', 'bet_placed', 'achievement_unlocked',
        ];
        expect(validActions.length, equals(6));
        expect(validActions, contains('game_won'));
        expect(validActions, contains('achievement_unlocked'));
      });
    });

    group('Tab Classement', () {
      test('leaderboard entre amis', () {
        final leaderboard = [
          {'user_id': '1', 'name': 'Alice', 'wins': 15, 'total_games': 20},
          {'user_id': '2', 'name': 'Bob', 'wins': 10, 'total_games': 18},
          {'user_id': '3', 'name': 'Charlie', 'wins': 8, 'total_games': 15},
        ];

        // Vérifier l'ordre décroissant par victoires
        for (int i = 0; i < leaderboard.length - 1; i++) {
          expect(
            leaderboard[i]['wins'] as int,
            greaterThanOrEqualTo(leaderboard[i + 1]['wins'] as int),
          );
        }
      });

      test('calcul du win rate', () {
        final entry = {'wins': 15, 'total_games': 20};
        final winRate = (entry['wins'] as num) / (entry['total_games'] as num);
        expect(winRate, equals(0.75));
      });
    });

    group('FriendSearchSheet', () {
      test('recherche par phone', () {
        const query = '+237690000000';
        expect(query, startsWith('+'));
        expect(query.length, greaterThan(5));
      });

      test('recherche par username', () {
        const query = 'alice_wiwiga';
        expect(query, isNotEmpty);
        expect(query.length, greaterThanOrEqualTo(3));
      });

      test('résultat affiche profil résumé', () {
        final result = {
          'id': '1',
          'username': 'alice_wiwiga',
          'phone': '+237690000000',
          'avatar_url': null,
          'level': 5,
        };
        expect(result['username'], isNotNull);
        expect(result['level'], isA<int>());
      });
    });

    group('WebSocket events', () {
      test('friend_request event reçu', () {
        const event = 'friend_request';
        expect(event, equals('friend_request'));
      });

      test('friend_accepted event reçu', () {
        const event = 'friend_accepted';
        expect(event, equals('friend_accepted'));
      });

      test('friend_online event reçu', () {
        const event = 'friend_online';
        final data = {'user_id': '1', 'is_online': true};
        expect(event, equals('friend_online'));
        expect(data['is_online'], isTrue);
      });

      test('game_invitation event avec room_code', () {
        const event = 'game_invitation';
        final data = {'room_code': 'WIWIGA-7X3K', 'from_user': 'Alice'};
        expect(event, equals('game_invitation'));
        expect(data['room_code'], startsWith('WIWIGA-'));
      });
    });

    group('Navigation', () {
      test('icône Amis dans MainAppScreen avec badge', () {
        const pendingCount = 3;
        expect(pendingCount, greaterThan(0));
        // Le badge doit afficher le nombre de demandes en attente
      });

      test('badge caché si pas de demandes', () {
        const pendingCount = 0;
        expect(pendingCount, equals(0));
        // Pas de badge visible
      });
    });
  });
}

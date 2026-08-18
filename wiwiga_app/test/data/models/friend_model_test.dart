import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/models/friend_model.dart';

void main() {
  group('FriendModel', () {
    test('fromJson parse correctement', () {
      final friend = FriendModel.fromJson({
        'id': 42,
        'name': 'TestUser',
        'phone': '+237690000000',
        'status': 'online',
      });

      expect(friend.id, 42);
      expect(friend.name, 'TestUser');
      expect(friend.isOnline, true);
      expect(friend.isInGame, false);
    });

    test('valeurs par défaut si champs manquants', () {
      final friend = FriendModel.fromJson({
        'id': 1,
      });

      expect(friend.name, 'Inconnu');
      expect(friend.isOnline, false);
      expect(friend.isInGame, false);
    });
  });

  group('FriendRequestModel', () {
    test('fromJson parse correctement', () {
      final request = FriendRequestModel.fromJson({
        'id': 10,
        'from_user': {
          'id': 5,
          'name': 'Sender',
          'phone': '+237690000001',
        },
        'created_at': '2026-08-17T10:00:00Z',
      });

      expect(request.id, 10);
      expect(request.fromUser.name, 'Sender');
    });
  });

  group('FriendLeaderboardEntry', () {
    test('fromJson parse correctement', () {
      final entry = FriendLeaderboardEntry.fromJson({
        'id': 7,
        'name': 'Champion',
        'wins': 50,
      });

      expect(entry.name, 'Champion');
      expect(entry.wins, 50);
    });
  });
}

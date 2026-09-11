import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/models/notification_model.dart';

void main() {
  group('NotificationModel', () {
    test('fromJson parse correctement', () {
      final notif = NotificationModel.fromJson({
        'id': 7,
        'event_type': 'wallet_credit',
        'title': 'Jetons reçus',
        'body': '+500 jetons : gain test',
        'category': 'transactional',
        'priority': 'normal',
        'status': 'sent',
        'is_read': false,
        'read_at': null,
        'inserted_at': '2026-09-08T10:00:00Z',
      });

      expect(notif.id, 7);
      expect(notif.eventType, 'wallet_credit');
      expect(notif.title, 'Jetons reçus');
      expect(notif.body, '+500 jetons : gain test');
      expect(notif.isRead, false);
    });

    test('valeurs par défaut si champs manquants', () {
      final notif = NotificationModel.fromJson({'id': 1});

      expect(notif.title, 'Notification');
      expect(notif.body, '');
      expect(notif.category, 'transactional');
      expect(notif.isRead, false);
    });

    test('toJson sérialise les champs inbox', () {
      const notif = NotificationModel(
        id: 3,
        eventType: 'friend_request',
        title: "Demande d'ami",
        body: 'Ali vous a envoyé une demande',
        category: 'social',
        priority: 'normal',
        status: 'sent',
        isRead: true,
        insertedAt: '2026-09-08T10:00:00Z',
      );

      final json = notif.toJson();
      expect(json['event_type'], 'friend_request');
      expect(json['is_read'], true);
    });
  });

  group('safeAction', () {
    NotificationModel withAction(String? action) {
      return NotificationModel(
        id: 1,
        eventType: 'wallet_credit',
        title: 'T',
        body: 'B',
        category: 'transactional',
        priority: 'normal',
        status: 'sent',
        isRead: false,
        insertedAt: '',
        action: action,
      );
    }

    test('accepte les routes autorisées', () {
      expect(withAction('/transactions').safeAction, '/transactions');
      expect(withAction('/friends').safeAction, '/friends');
    });

    test('rejette les routes inconnues ou admin', () {
      expect(withAction(null).safeAction, isNull);
      expect(withAction('').safeAction, isNull);
      expect(withAction('/admin/users').safeAction, isNull);
      expect(withAction('https://evil.test').safeAction, isNull);
    });
  });

  group('fromJson action', () {
    test('parse le deep-link serveur', () {
      final notif = NotificationModel.fromJson({'id': 9, 'action': '/games'});
      expect(notif.action, '/games');
      expect(notif.safeAction, '/games');
    });
  });

  group('NotificationPreferenceModel', () {    test('fromJson parse correctement', () {
      const pref = NotificationPreferenceModel(id: 1, category: 'marketing', channel: 'push', enabled: false);
      expect(pref.enabled, false);

      final parsed = NotificationPreferenceModel.fromJson({'id': 2, 'category': 'game', 'channel': 'sms'});
      expect(parsed.enabled, true);
    });
  });
}

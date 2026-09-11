import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/models/notification_model.dart';
import 'package:wiwiga/data/providers/notification_provider.dart';
import 'package:wiwiga/data/repositories/notification_repository.dart';
import 'package:wiwiga/data/services/api_service.dart';
import 'package:wiwiga/presentation/screens/notifications/notifications_screen.dart';

NotificationModel _item(int id, {bool read = false}) {
  return NotificationModel(
    id: id,
    eventType: 'wallet_credit',
    title: 'Jetons reçus #$id',
    body: '+500 jetons : gain test',
    category: 'transactional',
    priority: 'normal',
    status: 'sent',
    isRead: read,
    insertedAt: '2026-09-08T10:00:00Z',
  );
}

/// Faux repository : 2 pages (20 + 5), suppression locale.
class _FakeNotificationRepository extends NotificationRepository {
  final List<NotificationModel> items = List.generate(25, (i) => _item(i + 1));

  _FakeNotificationRepository() : super(ApiService());

  @override
  Future<({List<NotificationModel> items, int total})> listNotifications({
    int page = 1,
    int limit = 20,
    String? isRead,
    String? category,
    String? query,
  }) async {
    Iterable<NotificationModel> all = items;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      all = all.where(
        (n) =>
            n.title.toLowerCase().contains(q) ||
            n.body.toLowerCase().contains(q),
      );
    }
    final list = all.toList();
    final start = (page - 1) * limit;
    final slice = list.skip(start).take(limit).toList();
    return (items: slice, total: list.length);
  }

  @override
  Future<int> getUnreadCount() async => 25;

  @override
  Future<void> markAsRead(int id) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> deleteNotification(int id) async {
    items.removeWhere((n) => n.id == id);
  }
}

Widget _harness(_FakeNotificationRepository repo) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWith((ref) => repo),
      unreadNotificationsCountProvider.overrideWith((ref) async => 25),
    ],
    child: const MaterialApp(home: NotificationsScreen()),
  );
}

void main() {
  test('NotificationsScreen widget class exists', () {
    const screen = NotificationsScreen();
    expect(screen, isA<NotificationsScreen>());
  });

  testWidgets('affiche la première page et propose Charger plus',
      (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness(_FakeNotificationRepository()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Jetons reçus #1'), findsOneWidget);
    expect(find.textContaining('Charger plus (20/25)'), findsOneWidget);

    // Page 2 → 25 éléments, plus de bouton
    await tester.dragUntilVisible(
      find.textContaining('Charger plus'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.tap(find.textContaining('Charger plus'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Jetons reçus #25'), findsOneWidget);
    expect(find.textContaining('Charger plus'), findsNothing);
  });

  testWidgets('suppression via poubelle + confirmation', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = _FakeNotificationRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Jetons reçus #1'), findsOneWidget);

    // Bouton poubelle de la première carte → dialogue → confirmer
    await tester.tap(find.byTooltip('Supprimer').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Supprimer ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer').last);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Jetons reçus #1'), findsNothing);
    expect(repo.items.length, 24);
  });

  testWidgets('affiche l\'état vide avec CTA jeux', (tester) async {
    final repo = _FakeNotificationRepository()..items.clear();
    await tester.pumpWidget(_harness(repo));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Aucune notification'), findsOneWidget);
    expect(find.text('Découvrir les jeux'), findsOneWidget);
  });

  testWidgets('recherche filtre la liste', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness(_FakeNotificationRepository()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Jetons reçus #1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '#2');
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Jetons reçus #1'), findsNothing);
    expect(find.textContaining('Jetons reçus #2'), findsWidgets);
  });
}

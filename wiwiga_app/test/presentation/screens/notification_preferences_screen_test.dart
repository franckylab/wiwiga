import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/models/notification_model.dart';
import 'package:wiwiga/data/providers/notification_provider.dart';
import 'package:wiwiga/presentation/screens/notifications/notification_preferences_screen.dart';

const _prefs = [
  NotificationPreferenceModel(id: 1, category: 'security', channel: 'sms', enabled: true),
  NotificationPreferenceModel(id: 2, category: 'marketing', channel: 'push', enabled: false),
];

void main() {
  test('NotificationPreferencesScreen widget class exists', () {
    const screen = NotificationPreferencesScreen();
    expect(screen, isA<NotificationPreferencesScreen>());
  });

  testWidgets('affiche la matrice avec verrou sécurité', (tester) async {
    // Surface haute : les 5 catégories sont visibles sans scroll
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPreferencesProvider.overrideWith((ref) async => _prefs),
        ],
        child: const MaterialApp(home: NotificationPreferencesScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 5 catégories visibles + verrou sécurité
    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Jetons'), findsOneWidget);
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    // Heures creuses
    expect(find.text('Heures creuses'), findsOneWidget);
    // Canaux affichés
    expect(find.text('Push'), findsWidgets);
    expect(find.text('SMS'), findsWidgets);
  });
}

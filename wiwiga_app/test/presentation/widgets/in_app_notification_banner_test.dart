import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/providers/notification_provider.dart';
import 'package:wiwiga/presentation/widgets/notifications/in_app_notification_banner.dart';

/// Hôte minimal avec Scaffold (la bannière utilise ScaffoldMessenger).
Widget _host(void Function(BuildContext context) onReady) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onReady(context));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  setUp(resetInAppBannerDedupForTest);

  test('durée selon priorité (urgent > high > normal > low)', () {
    expect(inAppBannerDurationFor('urgent'), const Duration(seconds: 10));
    expect(inAppBannerDurationFor('high'), const Duration(seconds: 8));
    expect(inAppBannerDurationFor('normal'), const Duration(seconds: 6));
    expect(inAppBannerDurationFor('low'), const Duration(seconds: 5));
    expect(inAppBannerDurationFor('exotique'), const Duration(seconds: 6));
  });

  test('parse tolérant (clés FCM et WS, valeurs invalides rejetées)', () {
    expect(parseInAppNotificationId({'notification_id': 12}), 12);
    expect(parseInAppNotificationId({'id': '34'}), 34);
    expect(parseInAppNotificationId({'id': 0}), isNull);
    expect(parseInAppNotificationId({}), isNull);
    expect(parseInAppCategory('security'), 'security');
    expect(parseInAppCategory('exotique'), 'transactional');
    expect(parseInAppCategory(null), 'transactional');
    expect(parseInAppPriority('URGENT'), 'urgent');
    expect(parseInAppPriority('exotique'), 'normal');
  });

  testWidgets('affiche Voir + Fermer, sans Supprimer quand id absent',
      (tester) async {
    var viewed = false;
    await tester.pumpWidget(
      _host((context) {
      showInAppNotificationBanner(
        context,
        data: (
          id: null,
          title: 'Gain crédité',
          body: '+500 jetons',
          category: 'transactional',
          priority: 'normal',
        ),
        onView: () => viewed = true,
      );
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Gain crédité'), findsOneWidget);
    expect(find.text('+500 jetons'), findsOneWidget);
    expect(find.text('Voir'), findsOneWidget);
    // Fermer explicite (le correctif demandé) : icône + sémantique.
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
      find.bySemanticsLabel('Fermer cette notification'),
      findsOneWidget,
    );
    // Pas d'id → pas de bouton Supprimer (jamais de bouton mort).
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

    // Tap Voir → callback puis bannière masquée.
    await tester.tap(find.text('Voir'));
    await tester.pump();
    expect(viewed, isTrue);
  });

  testWidgets('Supprimer appelle onDelete puis masque la bannière',
      (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      _host((context) {
      showInAppNotificationBanner(
        context,
        data: (
          id: 7,
          title: 'Invitation',
          body: 'Un ami vous invite',
          category: 'social',
          priority: 'normal',
        ),
        onView: () {},
        onDelete: () async => deleted = true,
      );
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    // Laisse l'animation de sortie du SnackBar se terminer.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(deleted, isTrue);
    expect(find.text('Invitation'), findsNothing);
  });

  testWidgets('Fermer masque sans effet serveur', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      _host((context) {
      showInAppNotificationBanner(
        context,
        data: (
          id: 9,
          title: 'Alerte sécurité',
          body: 'Nouvelle connexion',
          category: 'security',
          priority: 'urgent',
        ),
        onView: () {},
        onDelete: () async => deleted = true,
      );
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.close_rounded));
    // Laisse l'animation de sortie du SnackBar se terminer.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Alerte sécurité'), findsNothing);
    expect(deleted, isFalse);
  });

  testWidgets('doublon immédiat ignoré (FCM + WS)', (tester) async {
    var views = 0;
    await tester.pumpWidget(
      _host((context) {
      const data = (
        id: 42,
        title: 'Doublon',
        body: 'Même événement',
        category: 'game',
        priority: 'normal',
      );
      showInAppNotificationBanner(
        context,
        data: data,
        onView: () => views++,
      );
      // Seconde source du même événement < 4 s → ignorée.
      showInAppNotificationBanner(
        context,
        data: data,
        onView: () => views++,
      );
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Doublon'), findsOneWidget);
    expect(lastShownInAppNotificationId, 42);
  });
}

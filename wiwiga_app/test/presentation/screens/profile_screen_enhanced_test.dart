import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/presentation/screens/profile/profile_screen_enhanced.dart';

void main() {
  group('ProfileScreenEnhanced', () {
    testWidgets('affiche le username', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('Franck_CH'), findsOneWidget);
    });

    testWidgets('affiche le numéro de téléphone', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('+237 699 999 999'), findsOneWidget);
    });

    testWidgets('affiche le solde', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('350 000'), findsOneWidget);
      expect(find.text('FCFA'), findsOneWidget);
    });

    testWidgets('affiche les stats rapides', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('156'), findsOneWidget); // games played
      expect(find.text('97'), findsOneWidget); // wins
      expect(find.text('62%'), findsOneWidget); // win rate
      expect(find.text('5'), findsOneWidget); // current streak
    });

    testWidgets('affiche la section ACHIEVEMENTS', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('4/6'), findsOneWidget);
    });

    testWidgets('affiche les achievements débloqués', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('Première Victoire'), findsOneWidget);
      expect(find.text('En Feu'), findsOneWidget);
      expect(find.text('Gros Gain'), findsOneWidget);
      expect(find.text('Vétéran'), findsOneWidget);
    });

    testWidgets('affiche les achievements à débloquer', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('À débloquer'), findsOneWidget);
      expect(find.text('Roulage de Diamant'), findsOneWidget);
      expect(find.text('Champion'), findsOneWidget);
    });

    testWidgets('affiche la section PARTIES RÉCENTES', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      await tester.scrollUntilVisible(find.text('PARTIES RÉCENTES'), 300);
      expect(find.text('PARTIES RÉCENTES'), findsOneWidget);
    });

    testWidgets('affiche les résultats des parties', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      // Scroll down to see recent games
      await tester.scrollUntilVisible(find.text('PARTIES RÉCENTES'), 300);
      // Victoire and Défaite appear in the list
      expect(find.text('Victoire'), findsWidgets);
    });

    testWidgets('affiche la barre XP', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.text('XP: 8450'), findsOneWidget);
    });

    testWidgets('affiche le bouton DÉCONNEXION', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      await tester.scrollUntilVisible(find.text('DÉCONNEXION'), 300);
      expect(find.text('DÉCONNEXION'), findsOneWidget);
    });

    testWidgets('affiche le badge vérifié', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );

      expect(find.byIcon(Icons.verified), findsOneWidget);
    });
  });
}

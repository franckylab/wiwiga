import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/presentation/screens/leaderboard/leaderboard_screen.dart';

void main() {
  group('LeaderboardScreen', () {
    testWidgets('affiche le header avec titre CLASSEMENT', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      expect(find.text('CLASSEMENT'), findsOneWidget);
      expect(find.text('SAISON 1'), findsOneWidget);
    });

    testWidgets('affiche les sélecteurs de période', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Semaine'), findsOneWidget);
      expect(find.text('Mois'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('affiche le podium Top 3', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      // Les noms du top 3 apparaissent dans le podium + la liste
      expect(find.text('ProGamer_CM'), findsWidgets);
      expect(find.text('DiceKing'), findsWidgets);
      expect(find.text('LuckyHand'), findsWidgets);
    });

    testWidgets('affiche la liste complète des joueurs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      // Scroll pour voir les autres joueurs
      await tester.scrollUntilVisible(find.text('Newbie237'), 200);
      expect(find.text('Newbie237'), findsOneWidget);
    });

    testWidgets('affiche le badge VOUS pour le joueur courant', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      await tester.scrollUntilVisible(find.text('Vous'), 200);
      expect(find.text('Vous'), findsOneWidget);
      expect(find.text('VOUS'), findsOneWidget);
    });

    testWidgets('change de période quand on tape sur un filtre', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      // Taper sur "Mois"
      await tester.tap(find.text('Mois'));
      await tester.pump();

      // L'écran reste fonctionnel
      expect(find.text('CLASSEMENT'), findsOneWidget);
    });

    testWidgets('affiche les pourcentages win rate', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LeaderboardScreen()),
        ),
      );

      expect(find.text('87%'), findsOneWidget); // ProGamer
      expect(find.text('82%'), findsOneWidget); // DiceKing
    });
  });
}

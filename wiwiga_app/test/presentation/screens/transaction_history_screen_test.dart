import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/presentation/screens/transaction_history/transaction_history_screen.dart';

void main() {
  group('TransactionHistoryScreen', () {
    testWidgets('affiche le header HISTORIQUE', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      expect(find.text('HISTORIQUE'), findsOneWidget);
    });

    testWidgets('affiche les filtres', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('Dépôts'), findsOneWidget);
      expect(find.text('Retraits'), findsOneWidget);
      expect(find.text('Jeu'), findsOneWidget);
    });

    testWidgets('affiche le résumé financier', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      expect(find.text('Déposé'), findsOneWidget);
      expect(find.text('Retiré'), findsOneWidget);
      expect(find.text('Gagné'), findsOneWidget);
    });

    testWidgets('affiche les transactions', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      // Vérifier les types de transactions
      expect(find.text('Gain'), findsWidgets);
      expect(find.text('Mise'), findsWidgets);
      expect(find.text('Dépôt'), findsWidgets);
    });

    testWidgets('affiche les références de transaction', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      expect(find.text('WIN_001'), findsOneWidget);
      expect(find.text('BET_042'), findsOneWidget);
    });

    testWidgets('affiche le badge EN ATTENTE pour les retraits en cours', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      expect(find.text('EN ATTENTE'), findsOneWidget);
    });

    testWidgets('filtre par dépôts', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      await tester.tap(find.text('Dépôts'));
      await tester.pump();

      // Seuls les dépôts sont visibles
      expect(find.text('Dépôt'), findsWidgets);
    });

    testWidgets('filtre par jeu', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      await tester.tap(find.text('Jeu'));
      await tester.pump();

      // Les transactions de jeu sont visibles
      expect(find.text('Dice Game'), findsWidgets);
    });

    testWidgets('affiche le nom du jeu pour les transactions liées', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );

      expect(find.text('Dice Game'), findsWidgets);
    });
  });
}

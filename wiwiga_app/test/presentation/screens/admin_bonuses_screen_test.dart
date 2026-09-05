import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/presentation/screens/admin/admin_bonuses_screen.dart';

void main() {
  group('AdminBonusesScreen', () {
    testWidgets('le widget existe', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AdminBonusesScreen()),
        ),
      );
      expect(find.byType(AdminBonusesScreen), findsOneWidget);
    });

    testWidgets('affiche le titre Bonus et Promotions', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AdminBonusesScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Bonus et Promotions'), findsOneWidget);
    });

    testWidgets('a un bouton créer', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AdminBonusesScreen()),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}

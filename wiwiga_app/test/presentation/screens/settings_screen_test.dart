import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/presentation/screens/settings/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('affiche le header PARAMÈTRES', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('PARAMÈTRES'), findsOneWidget);
    });

    testWidgets('affiche la section COMPTE', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('COMPTE'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Numéro Mobile Money'), findsOneWidget);
      expect(find.text('Vérification KYC'), findsOneWidget);
    });

    testWidgets('affiche la section JEU', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('JEU'), findsOneWidget);
      expect(find.text('Sons'), findsOneWidget);
      expect(find.text('Vibrations'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('affiche la section JEU RESPONSABLE après scroll', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      // Scroll pour trouver la section
      await tester.scrollUntilVisible(find.text('JEU RESPONSABLE'), 300);
      expect(find.text('JEU RESPONSABLE'), findsOneWidget);
      expect(find.text('Limite de mise / jour'), findsOneWidget);
    });

    testWidgets('affiche la section SÉCURITÉ après scroll', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.scrollUntilVisible(find.text('SÉCURITÉ'), 300);
      expect(find.text('SÉCURITÉ'), findsOneWidget);
      expect(find.text('Changer le code PIN'), findsOneWidget);
    });

    testWidgets('affiche la section À PROPOS après scroll', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.scrollUntilVisible(find.text('À PROPOS'), 300);
      expect(find.text('À PROPOS'), findsOneWidget);
      expect(find.text('Conditions générales'), findsOneWidget);
    });

    testWidgets('affiche le bouton Déconnexion après scroll', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.scrollUntilVisible(find.text('Déconnexion'), 300);
      expect(find.text('Déconnexion'), findsOneWidget);
    });

    testWidgets('affiche le badge KYC OK', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('affiche la limite de mise par défaut après scroll', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.scrollUntilVisible(find.text('Limite de mise / jour'), 300);
      expect(find.text('50 000 FCFA'), findsOneWidget);
    });
  });
}

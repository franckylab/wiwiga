import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/providers/app_providers.dart';
import 'package:wiwiga/data/repositories/admin_repository.dart';
import 'package:wiwiga/data/services/api_service.dart';
import 'package:wiwiga/presentation/screens/admin/admin_settings_screen.dart';

/// Faux repository : catégories email/notification présentes côté serveur
/// (masquées côté UI — source unique = section NOTIFICATIONS).
class _FakeSettingsRepository extends AdminRepository {
  _FakeSettingsRepository() : super(apiService: ApiService());

  @override
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'general': [],
      'email': [
        {'key': 'smtp_host', 'value': '', 'description': 'legacy'},
      ],
      'notification': [
        {'key': 'email_notifications', 'value': 'true', 'description': 'legacy'},
      ],
      'security': [],
    };
  }
}

void main() {
  testWidgets('onglets email/notification supprimés (section NOTIFICATIONS unique)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWith((ref) => _FakeSettingsRepository()),
        ],
        child: const MaterialApp(home: AdminSettingsScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Onglets conservés visibles
    expect(find.text('Général'), findsOneWidget);
    expect(find.text('Sécurité'), findsOneWidget);

    // Doublons historiques absents (ni onglet, ni champ)
    expect(find.text('Email'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('smtp_host'), findsNothing);
    expect(find.text('Réglages déplacés'), findsNothing);
  });
}

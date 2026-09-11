import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/providers/app_providers.dart';
import 'package:wiwiga/data/repositories/admin_repository.dart';
import 'package:wiwiga/data/services/api_service.dart';
import 'package:wiwiga/presentation/screens/admin/admin_platform_config_screen.dart';

/// Faux repository : catégorie notification présente côté serveur (masquée UI).
class _FakePlatformRepository extends AdminRepository {
  _FakePlatformRepository() : super(apiService: ApiService());

  @override
  Future<Map<String, dynamic>> getPlatformConfig() async {
    // Même forme que l'API réelle (data + categories au même niveau)
    return {
      'data': {
        'payment': [],
        'notification': [
          {'key': 'enable_push_notifications', 'value': 'true'},
        ],
        'gaming': [],
      },
      'categories': ['payment', 'notification', 'gaming'],
    };
  }

  @override
  Future<List<dynamic>> getPlatformConfigByCategory(String category) async {
    return [];
  }
}

void main() {
  testWidgets('catégorie notification masquée (source unique NOTIFICATIONS)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider
              .overrideWith((ref) => _FakePlatformRepository()),
        ],
        child: const MaterialApp(home: AdminPlatformConfigScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Onglets utiles visibles, doublon historique absent
    expect(find.text('Paiements'), findsOneWidget);
    expect(find.text('Jeux'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('enable_push_notifications'), findsNothing);
  });
}

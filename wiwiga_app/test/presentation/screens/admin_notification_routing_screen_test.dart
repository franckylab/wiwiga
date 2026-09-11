import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/providers/app_providers.dart';
import 'package:wiwiga/data/repositories/admin_repository.dart';
import 'package:wiwiga/data/services/api_service.dart';
import 'package:wiwiga/presentation/screens/admin/admin_notification_routing_screen.dart';

/// Faux repository admin : routage en mémoire.
class _FakeAdminRepository extends AdminRepository {
  List<Map<String, dynamic>> rules = [
    {'event_key': 'wallet_credit', 'channels': ['in_app', 'push'], 'is_active': true, 'customized': true},
    {'event_key': 'promo_broadcast', 'channels': ['in_app'], 'is_active': false, 'customized': false},
  ];

  _FakeAdminRepository() : super(apiService: ApiService());

  @override
  Future<List<Map<String, dynamic>>> listNotificationRouting() async => List.of(rules);

  @override
  Future<Map<String, dynamic>> upsertNotificationRouting(
    String eventKey, {
    required List<String> channels,
    required bool isActive,
  }) async {
    final index = rules.indexWhere((r) => r['event_key'] == eventKey);
    final updated = {'event_key': eventKey, 'channels': channels, 'is_active': isActive, 'customized': true};
    if (index >= 0) {
      rules[index] = updated;
    } else {
      rules.add(updated);
    }
    return updated;
  }
}

void main() {
  test('AdminNotificationRoutingScreen widget class exists', () {
    const screen = AdminNotificationRoutingScreen();
    expect(screen, isA<AdminNotificationRoutingScreen>());
  });

  testWidgets('affiche les règles avec kill-switch', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = _FakeAdminRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: const MaterialApp(home: AdminNotificationRoutingScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('wallet_credit'), findsOneWidget);
    expect(find.text('promo_broadcast'), findsOneWidget);
    expect(find.text('perso'), findsOneWidget);
    expect(
      find.text('Événement désactivé : aucun envoi (même inbox).'),
      findsOneWidget,
    );
  });
}

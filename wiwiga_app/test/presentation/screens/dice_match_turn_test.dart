// ============================================================
// Test: bascule de tour déterministe sur DiceMatchScreen
// Reproduit le bug "zone active pour le mauvais joueur" en pilotant les
// VRAIS callbacks WebSocket avec des payloads au format serveur live.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wiwiga/data/models/user_model.dart';
import 'package:wiwiga/data/providers/app_providers.dart';
import 'package:wiwiga/data/repositories/auth_repository.dart';
import 'package:wiwiga/data/repositories/game_repository.dart';
import 'package:wiwiga/data/services/api_service.dart';
import 'package:wiwiga/presentation/screens/dice_game/dice_match_screen.dart';
import 'package:wiwiga/presentation/widgets/game/player_zone.dart';

class MockApiService extends Mock implements ApiService {}

class MockGameRepository extends Mock implements GameRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

/// Snapshot serveur réaliste (format constaté en live) : set 1 en cours.
Map<String, dynamic> serverMatch({
  required int turnIndex,
  Map<String, dynamic>? rolls,
  String status = 'set_in_progress',
}) {
  return {
    'match_id': 'test_match_1',
    'status': status,
    'current_set': 1,
    'sets_count': 3,
    'dice_count': 2,
    'bet_amount': 0,
    'rule_type': 'normal',
    'game_type': 'dice',
    'max_players': 2,
    'set_scores': {'111': 0, '222': 0},
    'sets': [],
    'current_set_state': {
      'set_number': 1,
      'status': 'in_progress',
      'turn_order': ['111', '222'],
      'current_turn_index': turnIndex,
      'rolls': rolls ?? {},
      'target_value': null,
      'votes': {},
      'vote_phase': false,
      'turn_remaining_seconds': 25,
    },
    'eliminated_players': [],
    'turn_timeout_ms': 30000,
    'players': [
      {'id': '111', 'name': 'Alice'},
      {'id': '222', 'name': 'Bob'},
    ],
  };
}

Map<String, bool> zonesActives(WidgetTester tester) {
  final zones = tester.widgetList<PlayerZone>(find.byType(PlayerZone));
  return {for (final z in zones) z.data.id: z.data.isActiveTurn};
}

void main() {
  late MockApiService mockApi;
  late MockGameRepository mockRepo;
  late ProviderContainer container;

  UserModel testUser() => UserModel(
        id: '111',
        username: 'Alice',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  setUp(() {
    mockApi = MockApiService();
    mockRepo = MockGameRepository();
    when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
    when(
      () => mockRepo.getMatchStateRest(any(), compact: any(named: 'compact')),
    ).thenAnswer((_) async => serverMatch(turnIndex: 0));
    final authNotifier = AuthNotifier(MockAuthRepository())
      ..state = AuthState(
        status: AuthStatus.authenticated,
        user: testUser(),
      );
    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApi),
        gameRepositoryProvider.overrideWithValue(mockRepo),
        authProvider.overrideWith((ref) => authNotifier),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpMatch(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiceMatchScreen(
            matchId: 'test_match_1',
            players: [
              {'id': '111', 'name': 'Alice'},
              {'id': '222', 'name': 'Bob'},
            ],
          ),
        ),
      ),
    );
    // Laisse l'init (fetch 700ms + intro 900ms) se terminer
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 1200));
  }

  /// Démonte l'écran (annule ses timers) avant la fin du test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(milliseconds: 100));
    // Coupe aussi le service WS (timers de reconnexion/heartbeat).
    try {
      container.read(gameWebSocketServiceProvider).disconnect();
    } catch (_) {}
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('tour initial : Alice active, Bob inactif', (tester) async {
    await pumpMatch(tester);
    final actives = zonesActives(tester);
    expect(actives['111'], isTrue, reason: 'Alice doit être active au tour 0');
    expect(actives['222'], isFalse, reason: 'Bob ne doit pas être actif');
    await unmount(tester);
  });

  testWidgets('après le lancer d\'Alice : Bob actif, Alice inactive',
      (tester) async {
    await pumpMatch(tester);

    // Event serveur réel : Alice a lancé [5,1], tour passé à Bob (index 1)
    final match = serverMatch(
      turnIndex: 1,
      rolls: {
        '111': {
          'player_id': '111',
          'dice': [5, 1],
          'sum': 6,
        },
      },
    );
    container.read(gameWebSocketServiceProvider).onDiceRolled?.call({
      'seq': 200,
      'roll': {
        'player_id': '111',
        'dice': [5, 1],
        'sum': 6,
      },
      'match': match,
    });
    await tester.pump(const Duration(milliseconds: 100));

    // Vue Alice : sa zone se désactive, celle de Bob s'active.
    // (Le bouton dé n'existe que sur SA propre zone : null des deux côtés
    // ici, c'est normal — voir le test suivant pour la vue Bob.)
    final actives = zonesActives(tester);
    expect(
      actives['111'],
      isFalse,
      reason: 'Alice a joué : sa zone ne doit plus être active',
    );
    expect(
      actives['222'],
      isTrue,
      reason: 'Bob doit être actif après le lancer d\'Alice',
    );
    await unmount(tester);
  });

  testWidgets('vue Bob : son bouton est cliquable à son tour uniquement',
      (tester) async {
    // Même match, vu par Bob (auth 222)
    final bobAuth = AuthNotifier(MockAuthRepository())
      ..state = AuthState(
        status: AuthStatus.authenticated,
        user: testUser().copyWith(id: '222', username: 'Bob'),
      );
    final bobContainer = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApi),
        gameRepositoryProvider.overrideWithValue(mockRepo),
        authProvider.overrideWith((ref) => bobAuth),
      ],
    );
    addTearDown(bobContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: bobContainer,
        child: const MaterialApp(
          home: DiceMatchScreen(
            matchId: 'test_match_1',
            players: [
              {'id': '111', 'name': 'Alice'},
              {'id': '222', 'name': 'Bob'},
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 1200));

    Map<String, bool> bobZones() {
      final zones = tester.widgetList<PlayerZone>(find.byType(PlayerZone));
      return {for (final z in zones) z.data.id: z.data.isActiveTurn};
    }

    // Tour 0 (Alice) : Bob inactif, pas de bouton
    expect(bobZones()['222'], isFalse);
    var zones = tester.widgetList<PlayerZone>(find.byType(PlayerZone));
    expect(zones.firstWhere((z) => z.data.id == '222').onTapDice, isNull);

    // Tour 1 (Bob) : actif + bouton cliquable, Alice verrouillée
    bobContainer.read(gameWebSocketServiceProvider).onDiceRolled?.call({
      'seq': 200,
      'roll': {
        'player_id': '111',
        'dice': [5, 1],
        'sum': 6,
      },
      'match': serverMatch(
        turnIndex: 1,
        rolls: {
          '111': {
            'player_id': '111',
            'dice': [5, 1],
            'sum': 6,
          },
        },
      ),
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      bobZones()['222'],
      isTrue,
      reason: 'Bob doit se voir actif à son tour',
    );
    expect(bobZones()['111'], isFalse);
    zones = tester.widgetList<PlayerZone>(find.byType(PlayerZone));
    expect(
      zones.firstWhere((z) => z.data.id == '222').onTapDice,
      isNotNull,
      reason: 'le bouton de Bob doit être actif à son tour',
    );
    expect(zones.firstWhere((z) => z.data.id == '111').onTapDice, isNull);

    await tester.pumpWidget(Container());
    await tester.pump(const Duration(milliseconds: 100));
    try {
      bobContainer.read(gameWebSocketServiceProvider).disconnect();
    } catch (_) {}
  });

  testWidgets('event périmé (vieux seq) ne fait pas reculer le tour',
      (tester) async {
    await pumpMatch(tester);

    // Tour 1 d'abord (seq récent)
    container.read(gameWebSocketServiceProvider).onDiceRolled?.call({
      'seq': 200,
      'roll': {
        'player_id': '111',
        'dice': [5, 1],
        'sum': 6,
      },
      'match': serverMatch(
        turnIndex: 1,
        rolls: {
          '111': {
            'player_id': '111',
            'dice': [5, 1],
            'sum': 6,
          },
        },
      ),
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(zonesActives(tester)['222'], isTrue);

    // Puis un event PÉRIMÉ (seq 150 < 200) rejouant l'ancien tour 0
    container.read(gameWebSocketServiceProvider).onTurnChanged?.call({
      'seq': 150,
      'current_turn_index': 0,
      'match': serverMatch(turnIndex: 0),
    });
    await tester.pump(const Duration(milliseconds: 100));

    final actives = zonesActives(tester);
    expect(
      actives['222'],
      isTrue,
      reason: 'un event périmé ne doit pas reculer le tour',
    );
    expect(actives['111'], isFalse);
    await unmount(tester);
  });
}

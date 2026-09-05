import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wiwiga/data/services/game_websocket_service.dart';
import 'package:wiwiga/data/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late GameWebSocketService service;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    service = GameWebSocketService(apiService: mockApiService);
  });

  tearDown(() {
    service.disconnect();
  });

  group('GameWebSocketService', () {
    group('état initial', () {
      test('commence déconnecté', () {
        expect(service.connectionStatus, GameConnectionStatus.disconnected);
        expect(service.isConnected, false);
        expect(service.isFallbackMode, false);
        expect(service.currentGameId, isNull);
        expect(service.phase, GamePhase.waitingForPlayers);
        expect(service.gameState, isNull);
        expect(service.events, isEmpty);
      });
    });

    group('setAuthToken', () {
      test('stocke le token', () {
        service.setAuthToken('test_token_123');
        // Pas de getter direct, mais on vérifie que ça ne crash pas
        expect(service.connectionStatus, GameConnectionStatus.disconnected);
      });
    });

    group('disconnect', () {
      test('réinitialise l état', () {
        service.disconnect();
        expect(service.connectionStatus, GameConnectionStatus.disconnected);
        expect(service.currentGameId, isNull);
      });
    });

    group('joinGame', () {
      test('définit le gameId et réinitialise la phase', () {
        service.joinGame('game_123');
        expect(service.currentGameId, 'game_123');
        expect(service.phase, GamePhase.waitingForPlayers);
      });
    });

    group('leaveGame', () {
      test('réinitialise gameId et phase', () {
        service.joinGame('game_123');
        service.leaveGame();
        expect(service.currentGameId, isNull);
        expect(service.phase, GamePhase.waitingForPlayers);
      });
    });

    group('matchmaking fallback REST', () {
      test('utilise REST quand WebSocket déconnecté', () async {
        when(
          () => mockApiService.post(
            any(),
            body: any(named: 'body'),
            requiresAuth: any(named: 'requiresAuth'),
          ),
        ).thenAnswer((_) async => {'status': 'queued', 'position': 3});

        final result = await service.joinMatchmaking(
          gameType: 'dice',
          betAmount: 500,
        );

        expect(result['status'], 'queued');
        verify(
          () => mockApiService.post(
            '/api/games/dice/join',
            body: {'bet_amount': 500, 'rule_type': 'normal'},
            requiresAuth: true,
          ),
        ).called(1);
      });
    });

    group('placeBet fallback REST', () {
      test('utilise REST quand WebSocket déconnecté', () async {
        when(
          () => mockApiService.post(
            any(),
            body: any(named: 'body'),
            requiresAuth: any(named: 'requiresAuth'),
          ),
        ).thenAnswer((_) async => {'status': 'bet_placed'});

        final result = await service.placeBet(
          gameId: 'game_123',
          betAmount: 500,
          predictedSum: 7,
        );

        expect(result['status'], 'bet_placed');
        verify(
          () => mockApiService.post(
            '/api/games/game_123/bet',
            body: {'bet_amount': 500, 'predicted_sum': 7},
            requiresAuth: true,
          ),
        ).called(1);
      });
    });

    group('fetchGameState', () {
      test('récupère l état via REST', () async {
        when(
          () => mockApiService.get(
            any(),
            requiresAuth: any(named: 'requiresAuth'),
          ),
        ).thenAnswer(
          (_) async => {
            'game_id': 'game_123',
            'status': 'playing',
            'total_pot': 1000,
          },
        );

        final state = await service.fetchGameState('game_123');

        expect(state['game_id'], 'game_123');
        expect(state['status'], 'playing');
      });
    });

    group('callbacks', () {
      test('onGameMatched est appelé quand défini', () {
        Map<String, dynamic>? receivedPayload;
        service.onGameMatched = (payload) {
          receivedPayload = payload;
        };

        // Simule un appel callback
        service.onGameMatched?.call({'game_id': 'game_456'});

        expect(receivedPayload, isNotNull);
        expect(receivedPayload!['game_id'], 'game_456');
      });

      test('onBetPlaced est appelé quand défini', () {
        Map<String, dynamic>? receivedPayload;
        service.onBetPlaced = (payload) {
          receivedPayload = payload;
        };

        service.onBetPlaced?.call({'amount': 500, 'predicted_sum': 7});

        expect(receivedPayload!['amount'], 500);
      });

      test('onTurnExecuted est appelé quand défini', () {
        Map<String, dynamic>? receivedPayload;
        service.onTurnExecuted = (payload) {
          receivedPayload = payload;
        };

        service.onTurnExecuted?.call({
          'dice_results': [3, 4],
          'total_sum': 7,
        });

        expect(receivedPayload!['total_sum'], 7);
      });

      test('expose le callback de changement de tour', () {
        Map<String, dynamic>? receivedPayload;
        service.onTurnChanged = (payload) {
          receivedPayload = payload;
        };

        service.onTurnChanged?.call({
          'current_player_id': 'player_2',
          'current_turn_index': 1,
        });

        expect(receivedPayload!['current_player_id'], 'player_2');
        expect(receivedPayload!['current_turn_index'], 1);
      });

      test('onGameResult est appelé quand défini', () {
        Map<String, dynamic>? receivedPayload;
        service.onGameResult = (payload) {
          receivedPayload = payload;
        };

        service.onGameResult?.call({'winner': 'player_1', 'result': 'win'});

        expect(receivedPayload!['result'], 'win');
      });

      test('onPlayerJoined est appelé quand défini', () {
        Map<String, dynamic>? receivedPayload;
        service.onPlayerJoined = (payload) {
          receivedPayload = payload;
        };

        service.onPlayerJoined?.call({'user_id': 'player_2'});

        expect(receivedPayload!['user_id'], 'player_2');
      });
    });

    group('GameConnectionStatus', () {
      test('valeurs enum correctes', () {
        expect(GameConnectionStatus.values.length, 5);
        expect(
          GameConnectionStatus.values,
          contains(GameConnectionStatus.disconnected),
        );
        expect(
          GameConnectionStatus.values,
          contains(GameConnectionStatus.connecting),
        );
        expect(
          GameConnectionStatus.values,
          contains(GameConnectionStatus.connected),
        );
        expect(
          GameConnectionStatus.values,
          contains(GameConnectionStatus.reconnecting),
        );
        expect(
          GameConnectionStatus.values,
          contains(GameConnectionStatus.fallbackRest),
        );
      });
    });

    group('GamePhase', () {
      test('valeurs enum correctes', () {
        expect(GamePhase.values.length, 6);
        expect(GamePhase.values, contains(GamePhase.waitingForPlayers));
        expect(GamePhase.values, contains(GamePhase.betting));
        expect(GamePhase.values, contains(GamePhase.rolling));
        expect(GamePhase.values, contains(GamePhase.result));
        expect(GamePhase.values, contains(GamePhase.finished));
      });
    });
  });
}

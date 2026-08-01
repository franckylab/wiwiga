import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wiwiga/data/repositories/game_repository.dart';
import 'package:wiwiga/data/services/api_service.dart';
import 'package:wiwiga/data/models/game_model.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late GameRepository repository;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    repository = GameRepository(apiService: mockApiService);
  });

  group('GameRepository', () {
    group('getGames', () {
      test('retourne une liste de jeux depuis l API', () async {
        // Arrange - format backend {success: true, data: [...]}
        when(() => mockApiService.get(any())).thenAnswer((_) async => {
          'success': true,
          'data': [
            {
              'id': '1',
              'name': 'Dice Game',
              'description': 'Jeu de dés',
              'type': 'dice',
              'min_bet': 100,
              'max_bet': 10000,
              'house_edge': 5.0,
              'is_active': true,
              'max_players': 5,
            },
            {
              'id': '2',
              'name': 'Ludo',
              'description': 'Jeu de plateau',
              'type': 'board',
              'min_bet': 50,
              'max_bet': 5000,
              'house_edge': 3.0,
              'is_active': true,
              'max_players': 4,
            },
          ],
        },);

        // Act
        final games = await repository.getGames();

        // Assert
        expect(games.length, 2);
        expect(games[0].id, '1');
        expect(games[0].name, 'Dice Game');
        expect(games[0].type, 'dice');
        expect(games[0].minBet, 100.0);
        expect(games[0].maxPlayers, 5);
        expect(games[1].id, '2');
        expect(games[1].name, 'Ludo');
        verify(() => mockApiService.get('/api/games')).called(1);
      });

      test('retourne liste vide si pas de clé data', () async {
        when(() => mockApiService.get(any())).thenAnswer((_) async => {'success': true});

        final games = await repository.getGames();

        expect(games, isEmpty);
      });

      test('propage les erreurs API', () async {
        when(() => mockApiService.get(any()))
            .thenThrow(Exception('Network error'));

        expect(repository.getGames(), throwsException);
      });
    });

    group('joinGame', () {
      test('envoie POST avec bet_amount et retourne data', () async {
        when(() => mockApiService.post(any(), body: any(named: 'body'), requiresAuth: any(named: 'requiresAuth')))
            .thenAnswer((_) async => {
              'success': true,
              'data': {'status': 'joined', 'game_id': '123'},
            },);

        final result = await repository.joinGame(gameId: '123', betAmount: 500);

        expect(result['status'], 'joined');
        expect(result['game_id'], '123');
        verify(() => mockApiService.post(
          '/api/games/123/join',
          body: {'bet_amount': 500},
          requiresAuth: true,
        ),).called(1);
      });
    });

    group('getGameState', () {
      test('retourne l état du jeu depuis data', () async {
        when(() => mockApiService.get(any(), requiresAuth: any(named: 'requiresAuth')))
            .thenAnswer((_) async => {
              'success': true,
              'data': {
                'game_id': '123',
                'status': 'playing',
                'players': 2,
                'total_pot': 1000,
              },
            },);

        final state = await repository.getGameState('123');

        expect(state['game_id'], '123');
        expect(state['status'], 'playing');
        expect(state['total_pot'], 1000);
      });
    });

    group('getWaitingGames', () {
      test('retourne les parties en attente depuis data', () async {
        when(() => mockApiService.get(any(), requiresAuth: any(named: 'requiresAuth')))
            .thenAnswer((_) async => {
              'success': true,
              'data': [
                {'id': '1', 'status': 'waiting', 'bet_amount': 500},
                {'id': '2', 'status': 'waiting', 'bet_amount': 1000},
              ],
            },);

        final games = await repository.getWaitingGames();

        expect(games.length, 2);
        expect(games[0]['id'], '1');
      });

      test('filtre par gameType si fourni', () async {
        when(() => mockApiService.get(any(), requiresAuth: any(named: 'requiresAuth')))
            .thenAnswer((_) async => {'success': true, 'data': []});

        await repository.getWaitingGames(gameType: 'dice');

        verify(() => mockApiService.get(
          '/api/games?type=dice&status=waiting',
          requiresAuth: true,
        ),).called(1);
      });
    });
  });
}

import '../models/game_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant les jeux et sessions
class GameRepository {
  final ApiService _apiService;
  
  GameRepository({required ApiService apiService})
      : _apiService = apiService;
  
  /// Récupère la liste des jeux disponibles
  Future<List<GameModel>> getGames() async {
    final response = await _apiService.get(ApiEndpoints.gamesList);
    
    // Backend retourne {success: true, data: [...], meta: {...}}
    final games = response['data'] as List? ?? [];
    return games.map((json) => GameModel.fromJson(json)).toList();
  }
  
  /// Rejoint une partie (via REST - fallback)
  Future<Map<String, dynamic>> joinGame({
    required String gameId,
    required int betAmount,
  }) async {
    final response = await _apiService.post(
      '${ApiEndpoints.joinGame}/$gameId/join',
      body: {
        'bet_amount': betAmount,
      },
      requiresAuth: true,
    );
    
    // Backend retourne {success: true, data: {status: "...", game_id: "..."}}
    return response['data'] as Map<String, dynamic>? ?? {};
  }
  
  /// Récupère l'état d'une partie
  Future<Map<String, dynamic>> getGameState(String gameId) async {
    final response = await _apiService.get(
      '${ApiEndpoints.gameState}/$gameId/state',
      requiresAuth: true,
    );
    
    return response['data'] as Map<String, dynamic>? ?? {};
  }
  
  /// Récupère la liste des parties en attente (via REST)
  Future<List<Map<String, dynamic>>> getWaitingGames({
    String? gameType,
  }) async {
    final endpoint = gameType != null
        ? '${ApiEndpoints.gamesList}?type=$gameType&status=waiting'
        : '${ApiEndpoints.gamesList}?status=waiting';
    
    final response = await _apiService.get(
      endpoint,
      requiresAuth: true,
    );
    
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  /// Rejoint une file de matchmaking
  Future<Map<String, dynamic>> joinQueue({
    required String gameId,
    required double betAmount,
  }) async {
    return await _apiService.post(
      '${ApiEndpoints.joinGame}/$gameId/join',
      body: {'bet_amount': betAmount},
      requiresAuth: true,
    );
  }

  /// Place une mise
  Future<Map<String, dynamic>> placeBet({
    required String sessionId,
    required double amount,
    required Map<String, dynamic> betData,
  }) async {
    return await _apiService.post(
      '${ApiEndpoints.joinGame}/$sessionId/bet',
      body: {
        'bet_amount': amount,
        ...betData,
      },
      requiresAuth: true,
    );
  }
}

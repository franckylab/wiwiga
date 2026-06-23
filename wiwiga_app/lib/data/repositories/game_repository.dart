// ============================================================
// Fichier: game_repository.dart
// Description: Repository des jeux
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

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
    
    final games = response['games'] as List;
    return games.map((json) => GameModel.fromJson(json)).toList();
  }
  
  /// Rejoint une file de matchmaking
  Future<GameSessionModel> joinQueue({
    required String gameId,
    required double betAmount,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.joinGame,
      body: {
        'game_id': gameId,
        'bet_amount': betAmount,
      },
      requiresAuth: true,
    );
    
    return GameSessionModel.fromJson(response['session']);
  }
  
  /// Place une mise pendant une session
  Future<Map<String, dynamic>> placeBet({
    required String sessionId,
    required double amount,
    required Map<String, dynamic> betData,
  }) async {
    final response = await _apiService.post(
      '${ApiEndpoints.placeBet}/$sessionId',
      body: {
        'amount': amount,
        'bet_data': betData,
      },
      requiresAuth: true,
    );
    
    return response;
  }
  
  /// Récupère l'historique des parties
  Future<List<GameSessionModel>> getGameHistory({
    String? gameId,
    int limit = 20,
  }) async {
    String endpoint = '${ApiEndpoints.gameHistory}?limit=$limit';
    if (gameId != null) {
      endpoint += '&game_id=$gameId';
    }
    
    final response = await _apiService.get(
      endpoint,
      requiresAuth: true,
    );
    
    final sessions = response['sessions'] as List;
    return sessions.map((json) => GameSessionModel.fromJson(json)).toList();
  }
}

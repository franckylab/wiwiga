import '../models/game_model.dart';
import '../models/game_stats_models.dart';
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
  
  /// Récupère le détail d'un jeu (avec tips, config)
  Future<GameModel> getGame(String gameType) async {
    final response = await _apiService.get('${ApiEndpoints.gameShow}/$gameType');
    return GameModel.fromJson(response['data'] as Map<String, dynamic>? ?? {});
  }

  /// Stats globales d'un jeu
  Future<GameGlobalStats> getGameStats(String gameType) async {
    final response = await _apiService
        .get('${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameStats}');
    return GameGlobalStats.fromJson(
        response['data'] as Map<String, dynamic>? ?? {});
  }

  /// Classement d'un jeu (metric × period)
  Future<GameLeaderboard> getLeaderboard(
    String gameType, {
    String metric = 'wins',
    String period = 'all',
    int limit = 20,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameLeaderboard}',
      queryParams: {
        'metric': metric,
        'period': period,
        'limit': '$limit',
      },
    );
    return GameLeaderboard.fromJson(
        response['data'] as Map<String, dynamic>? ?? {});
  }

  /// Mes statistiques personnelles sur un jeu
  Future<MyGameStats> getMyStats(String gameType) async {
    final response = await _apiService
        .get('${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameMyStats}');
    return MyGameStats.fromJson(
        response['data'] as Map<String, dynamic>? ?? {});
  }

  /// Flux d'activité récent (victoires publiques)
  Future<List<GameActivityEvent>> getActivity(
    String gameType, {
    int limit = 20,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameActivity}',
      queryParams: {'limit': '$limit'},
    );
    final events = response['data'] as List? ?? [];
    return events
        .map((e) => GameActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Règles du jeu (Normal/Cible)
  Future<List<GameRuleInfo>> getRules(String gameType) async {
    final response = await _apiService
        .get('${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameRules}');
    final rules = response['data'] as List? ?? [];
    return rules
        .map((r) => GameRuleInfo.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Astuces du jeu
  Future<List<GameTip>> getTips(String gameType) async {
    final response = await _apiService
        .get('${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameTips}');
    final tips = response['data'] as List? ?? [];
    return tips
        .map((t) => GameTip.fromJson(t as Map<String, dynamic>))
        .toList();
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

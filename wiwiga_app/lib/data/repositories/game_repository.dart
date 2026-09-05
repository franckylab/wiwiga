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
        response['data'] as Map<String, dynamic>? ?? {},);
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
        response['data'] as Map<String, dynamic>? ?? {},);
  }

  /// Mes statistiques personnelles sur un jeu
  Future<MyGameStats> getMyStats(String gameType) async {
    final response = await _apiService
        .get('${ApiEndpoints.gameShow}/$gameType${ApiEndpoints.gameMyStats}');
    return MyGameStats.fromJson(
        response['data'] as Map<String, dynamic>? ?? {},);
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

  /// Rejoint une partie — Partie rapide unifiée (mise+rule) avec hybrid Room+Queue (V3)
  Future<Map<String, dynamic>> joinGame({
    required String gameId,
    required int betAmount,
    String ruleType = 'normal',
  }) async {
    final response = await _apiService.post(
      '${ApiEndpoints.joinGame}/$gameId/join',
      body: {
        'bet_amount': betAmount,
        'rule_type': ruleType,
      },
      requiresAuth: true,
    );
    
    // Backend retourne {success: true, data: {status: "...", game_id: "...", rule_type: "..."}}
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Annule la recherche en file (bloquant)
  Future<void> leaveQueue({
    required String gameId,
    required String ruleType,
    required int betAmount,
  }) async {
    await _apiService.delete(
      '${ApiEndpoints.leaveQueue}/$gameId/queue',
      queryParams: {'rule_type': ruleType, 'bet_amount': '$betAmount'},
      requiresAuth: true,
    );
  }

  /// Statut file d'attente (polling fallback)
  Future<Map<String, dynamic>> getQueueStatus({
    required String gameId,
    required String ruleType,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.queueStatus}/$gameId/queue/status',
      queryParams: {'rule_type': ruleType},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Lobby synchronisé — état complet (joueurs, prêts, places)
  Future<Map<String, dynamic>> getQuickLobby({
    required String gameId,
    required String ruleType,
    required int betAmount,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.quickLobby}/$gameId/quick-lobby',
      queryParams: {'rule_type': ruleType, 'bet_amount': '$betAmount'},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Toggle prêt pour démarrage anticipé (tous doivent valider)
  Future<Map<String, dynamic>> toggleQuickReady({
    required String gameId,
    required String ruleType,
    required int betAmount,
  }) async {
    final response = await _apiService.post(
      '${ApiEndpoints.quickReady}/$gameId/quick-ready',
      body: {'rule_type': ruleType, 'bet_amount': betAmount},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Partie active pour redirection auto (room/match/quick_lobby)
  Future<Map<String, dynamic>> getActiveGame() async {
    final response = await _apiService.get(
      ApiEndpoints.activeGame,
      requiresAuth: true,
    );
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
    String ruleType = 'normal',
  }) async {
    final res = await _apiService.post(
      '${ApiEndpoints.joinGame}/$gameId/join',
      body: {'bet_amount': betAmount, 'rule_type': ruleType},
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? res;
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

  /// Lance les dés via REST fallback (si WebSocket indisponible)
  Future<Map<String, dynamic>> rollDice({required String matchId}) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/roll',
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Vote cible via REST fallback
  Future<Map<String, dynamic>> voteTarget({
    required String matchId,
    required int targetValue,
  }) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/vote',
      body: {'target_value': targetValue},
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Démarre le set suivant via REST fallback
  Future<Map<String, dynamic>> startSet({required String matchId}) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/start_set',
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Récupère l'état complet d'un match (REST)
  Future<Map<String, dynamic>> getMatchStateRest(String matchId) async {
    final res = await _apiService.get(
      '${ApiEndpoints.gameShow}/$matchId/state',
      requiresAuth: true,
    );
    // fallback debug si state est room
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Propose une revanche après fin de partie (idempotent)
  Future<Map<String, dynamic>> proposeRematch({required String matchId}) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/${ApiEndpoints.rematchPropose}',
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Répond à une revanche proposée
  Future<Map<String, dynamic>> respondRematch({
    required String matchId,
    required bool accept,
  }) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/${ApiEndpoints.rematchRespond}',
      body: {'accept': accept},
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Démarre la revanche (proposant) — retourne le nouveau match
  Future<Map<String, dynamic>> startRematch({required String matchId}) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/${ApiEndpoints.rematchStart}',
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Annule une revanche proposée (proposant)
  Future<Map<String, dynamic>> cancelRematch({required String matchId}) async {
    final res = await _apiService.post(
      '${ApiEndpoints.gameShow}/$matchId/${ApiEndpoints.rematchCancel}',
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Signale la sortie de l'interface de fin de partie (idempotent)
  Future<void> leaveMatch({required String matchId}) async {
    try {
      await _apiService.post(
        '${ApiEndpoints.gameShow}/$matchId/${ApiEndpoints.matchLeave}',
        requiresAuth: true,
      );
    } catch (_) {}
  }
}

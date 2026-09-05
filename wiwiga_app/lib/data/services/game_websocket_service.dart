import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

/// États de connexion du service jeu
enum GameConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  fallbackRest, // WebSocket down, utilise REST
}

/// Phases d'une partie côté client
enum GamePhase {
  waitingForPlayers,
  betting,
  allBetsPlaced,
  rolling,
  result,
  finished,
}

/// Service WebSocket dédié au jeu avec fallback REST automatique
class GameWebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  GameConnectionStatus _connectionStatus = GameConnectionStatus.disconnected;
  final ApiService _apiService;

  // Game state
  String? _currentGameId;
  GamePhase _phase = GamePhase.waitingForPlayers;
  Map<String, dynamic>? _gameState;
  final List<Map<String, dynamic>> _events = [];

  // Reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  String? _authToken;
  // Pending joins pour reconnexion auto (garantit synchro tour après WS drop)
  final Set<String> _pendingGameJoins = {};
  final Set<String> _pendingUserChannels = {};
  // Protocole Phoenix V2 : ref + join_ref monotones (évite joins rejetés)
  int _refCounter = 0;
  int _joinRefCounter = 0;
  final Map<String, String> _joinRefs = {};
  // Dernier ref envoyé par topic/event pour corréler les phx_reply d'erreur
  final Map<String, String> _lastRefByTopicEvent = {};

  // Callbacks
  void Function(Map<String, dynamic>)? onGameMatched;
  void Function(Map<String, dynamic>)? onBetPlaced;
  void Function(Map<String, dynamic>)? onTurnExecuted;
  void Function(Map<String, dynamic>)? onGameResult;
  void Function(Map<String, dynamic>)? onPlayerJoined;

  // Room callbacks
  void Function(Map<String, dynamic>)? onRoomUpdated;
  void Function(Map<String, dynamic>)? onPlayerLeftRoom;
  void Function(Map<String, dynamic>)? onMatchStarted;
  void Function(Map<String, dynamic>)? onRoomCancelled;

  // Friend callbacks
  void Function(Map<String, dynamic>)? onFriendRequest;
  void Function(Map<String, dynamic>)? onFriendAccepted;
  void Function(Map<String, dynamic>)? onFriendOnline;
  void Function(Map<String, dynamic>)? onGameInvitation;
  void Function(Map<String, dynamic>)? onActivityUpdate;

  // Match callbacks
  void Function(Map<String, dynamic>)? onSetStarted;
  void Function(Map<String, dynamic>)? onDiceRolling;
  void Function(Map<String, dynamic>)? onDiceRolled;
  void Function(Map<String, dynamic>)? onTurnChanged;
  void Function(Map<String, dynamic>)? onSetResult;
  void Function(Map<String, dynamic>)? onMatchResult;
  void Function(Map<String, dynamic>)? onTargetVoted;
  void Function(Map<String, dynamic>)? onPlayerForfeited;
  void Function(Map<String, dynamic>)? onMatchForfeit;
  void Function(Map<String, dynamic>)? onMatchState;
  // Revanche opt-out (fin de partie)
  void Function(Map<String, dynamic>)? onRematchProposed;
  void Function(Map<String, dynamic>)? onRematchUpdated;
  void Function(Map<String, dynamic>)? onRematchReady;
  void Function(Map<String, dynamic>)? onRematchCancelled;
  // Erreurs temps réel (ex: not_your_turn) — remonte au lanceur sans attendre le fallback
  void Function(Map<String, dynamic>)? onChannelError;

  // Wallet / Stats temps réel
  void Function(Map<String, dynamic>)? onWalletUpdate;
  void Function(Map<String, dynamic>)? onStatsUpdate;

  GameWebSocketService({required ApiService apiService})
      : _apiService = apiService;

  // === Getters ===

  GameConnectionStatus get connectionStatus => _connectionStatus;
  String? get currentGameId => _currentGameId;
  GamePhase get phase => _phase;
  Map<String, dynamic>? get gameState => _gameState;
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  bool get isConnected => _connectionStatus == GameConnectionStatus.connected;
  bool get isFallbackMode =>
      _connectionStatus == GameConnectionStatus.fallbackRest;

  // === Connection ===

  /// Définit le token d'authentification
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Connecte au WebSocket Phoenix — récupère automatiquement le token si non défini
  Future<void> connect() async {
    if (_connectionStatus == GameConnectionStatus.connected) return;

    // Récupération auto du token depuis ApiService (évite guest id → not_your_turn)
    if (_authToken == null) {
      try {
        final t = await _apiService.getAccessToken();
        if (t != null && t.isNotEmpty) _authToken = t;
      } catch (_) {}
    }

    _setConnectionStatus(GameConnectionStatus.connecting);

    try {
      final wsUrl = '${AppConfig.websocketUrl}/socket/websocket';
      final uri = _authToken != null
          ? Uri.parse('$wsUrl?token=$_authToken')
          : Uri.parse(wsUrl);

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setConnectionStatus(GameConnectionStatus.connected);
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Re-join automatique des channels précédents (tour synchrone)
      if (_pendingGameJoins.isNotEmpty) {
        for (final gid in _pendingGameJoins.toList()) {
          _sendToChannel(
            topic: '${WebSocketChannels.gamePrefix}$gid',
            event: WebSocketEvents.phxJoin,
            payload: {'game_id': gid},
          );
        }
      } else if (_currentGameId != null) {
        _sendToChannel(
          topic: '${WebSocketChannels.gamePrefix}$_currentGameId',
          event: WebSocketEvents.phxJoin,
          payload: {'game_id': _currentGameId},
        );
      }
      for (final uid in _pendingUserChannels.toList()) {
        _sendToChannel(
          topic: 'user:$uid',
          event: WebSocketEvents.phxJoin,
          payload: {},
        );
        _sendToChannel(
          topic: 'user:$uid:wallet',
          event: WebSocketEvents.phxJoin,
          payload: {},
        );
      }

      debugPrint('✓ Game WebSocket connecté');
    } catch (e) {
      debugPrint('✗ Game WebSocket erreur: $e');
      _setConnectionStatus(GameConnectionStatus.fallbackRest);
      _scheduleReconnect();
    }
  }

  /// Déconnecte proprement
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _currentGameId = null;
    _setConnectionStatus(GameConnectionStatus.disconnected);
  }

  // === Matchmaking V3 — Partie rapide unifiée (mise+rule) ===

  /// Rejoint la file de matchmaking via WebSocket (ou REST en fallback)
  /// V3.1: rejoint d'abord le topic `matchmaking:{gameType}` en temps réel, puis envoie `join_queue`
  Future<Map<String, dynamic>> joinMatchmaking({
    required String gameType,
    required int betAmount,
    String ruleType = 'normal',
  }) async {
    if (isConnected) {
      final topic = 'matchmaking:$gameType';
      // 1) Rejoindre le channel pour recevoir lobby_update / game_matched en temps réel
      _sendToChannel(topic: topic, event: WebSocketEvents.phxJoin, payload: {});
      // Petit délai pour laisser le serveur traiter le join
      await Future.delayed(const Duration(milliseconds: 120));
      _sendToChannel(
        topic: topic,
        event: WebSocketEvents.joinQueue,
        payload: {
          'game_type': gameType,
          'bet_amount': betAmount,
          'rule_type': ruleType,
        },
      );
      return {'status': 'queued'};
    } else {
      // Fallback REST — hybrid Room+Queue côté serveur
      final res = await _apiService.post(
        '${ApiEndpoints.joinGame}/$gameType/join',
        body: {'bet_amount': betAmount, 'rule_type': ruleType},
        requiresAuth: true,
      );
      return res['data'] as Map<String, dynamic>? ?? res;
    }
  }

  /// Rejoint le channel matchmaking pour recevoir les updates lobby sans forcément rejoindre la file
  void joinMatchmakingChannel(String gameType) {
    if (isConnected) {
      _sendToChannel(
        topic: 'matchmaking:$gameType',
        event: WebSocketEvents.phxJoin,
        payload: {},
      );
    }
  }

  /// Rejoint le lobby rapide spécifique (V3.1) pour recevoir lobby_update / game_matched en temps réel
  void joinQuickLobby({
    required String gameType,
    required String ruleType,
    required int betAmount,
  }) {
    if (isConnected) {
      final topic = 'qm:lobby:$gameType:$ruleType:$betAmount';
      _sendToChannel(topic: topic, event: WebSocketEvents.phxJoin, payload: {});
      // Aussi rejoindre le canal générique matchmaking et user pour fallback
      _sendToChannel(
        topic: 'matchmaking:$gameType',
        event: WebSocketEvents.phxJoin,
        payload: {},
      );
    }
  }

  void leaveQuickLobby({
    required String gameType,
    required String ruleType,
    required int betAmount,
  }) {
    if (isConnected) {
      final topic = 'qm:lobby:$gameType:$ruleType:$betAmount';
      _sendToChannel(
        topic: topic,
        event: WebSocketEvents.phxLeave,
        payload: {},
      );
    }
  }

  /// Quitte la file de matchmaking (WS + REST fallback退款)
  Future<void> leaveMatchmaking({
    required String gameType,
    String ruleType = 'normal',
    int? betAmount,
  }) async {
    if (isConnected) {
      final topic = 'matchmaking:$gameType';
      _sendToChannel(
        topic: topic,
        event: WebSocketEvents.leaveQueue,
        payload: {
          'rule_type': ruleType,
          if (betAmount != null) 'bet_amount': betAmount,
        },
      );
      // Optionnel: quitter le topic
      _sendToChannel(
        topic: topic,
        event: WebSocketEvents.phxLeave,
        payload: {},
      );
    }
    // Toujours REST pour remboursement idempotent
    try {
      await _apiService.delete(
        '${ApiEndpoints.leaveQueue}/$gameType/queue',
        queryParams: {
          'rule_type': ruleType,
          if (betAmount != null) 'bet_amount': '$betAmount',
        },
        requiresAuth: true,
      );
    } catch (_) {}
  }

  /// Poll statut file (REST) — utilisé si WS down
  Future<Map<String, dynamic>> getQueueStatus({
    required String gameType,
    String ruleType = 'normal',
  }) async {
    final res = await _apiService.get(
      '${ApiEndpoints.queueStatus}/$gameType/queue/status',
      queryParams: {'rule_type': ruleType},
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // Quick lobby synchro
  void Function(Map<String, dynamic>)? onLobbyUpdate;

  Future<Map<String, dynamic>> getQuickLobby({
    required String gameType,
    required String ruleType,
    required int betAmount,
  }) async {
    final res = await _apiService.get(
      '${ApiEndpoints.quickLobby}/$gameType/quick-lobby',
      queryParams: {'rule_type': ruleType, 'bet_amount': '$betAmount'},
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> toggleQuickReady({
    required String gameType,
    required String ruleType,
    required int betAmount,
  }) async {
    if (isConnected) {
      _sendToChannel(
        topic: WebSocketChannels.matchmaking,
        event: 'toggle_ready',
        payload: {
          'game_type': gameType,
          'rule_type': ruleType,
          'bet_amount': betAmount,
        },
      );
    }
    final res = await _apiService.post(
      '${ApiEndpoints.quickReady}/$gameType/quick-ready',
      body: {'rule_type': ruleType, 'bet_amount': betAmount},
      requiresAuth: true,
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // === Game Actions ===

  /// Rejoint une partie spécifique
  void joinGame(String gameId) {
    _currentGameId = gameId;
    _phase = GamePhase.waitingForPlayers;
    _pendingGameJoins.add(gameId);

    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$gameId',
        event: WebSocketEvents.phxJoin,
        payload: {'game_id': gameId},
      );
    }
  }

  /// Place un pari (prédiction somme)
  Future<Map<String, dynamic>> placeBet({
    required String gameId,
    required int betAmount,
    required int predictedSum,
  }) async {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$gameId',
        event: WebSocketEvents.placeBet,
        payload: {
          'bet_amount': betAmount,
          'predicted_sum': predictedSum,
        },
      );
      return {'status': 'bet_placed'};
    } else {
      // Fallback REST
      return await _apiService.post(
        '${ApiEndpoints.joinGame}/$gameId/bet',
        body: {
          'bet_amount': betAmount,
          'predicted_sum': predictedSum,
        },
        requiresAuth: true,
      );
    }
  }

  /// Demande l'exécution du tour (lancer dés)
  Future<Map<String, dynamic>> requestExecuteTurn(String gameId) async {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$gameId',
        event: WebSocketEvents.executeTurn,
      );
      return {'status': 'rolling'};
    } else {
      // Fallback REST - polling du state
      return await _apiService.get(
        '${ApiEndpoints.gameState}/$gameId',
        requiresAuth: true,
      );
    }
  }

  /// Récupère l'état du jeu (REST fallback)
  Future<Map<String, dynamic>> fetchGameState(String gameId) async {
    return await _apiService.get(
      '${ApiEndpoints.gameState}/$gameId',
      requiresAuth: true,
    );
  }

  /// Quitte la partie
  void leaveGame() {
    if (_currentGameId != null) {
      if (isConnected) {
        _sendToChannel(
          topic: '${WebSocketChannels.gamePrefix}$_currentGameId',
          event: WebSocketEvents.phxLeave,
        );
      }
      _pendingGameJoins.remove(_currentGameId);
    }
    _currentGameId = null;
    _phase = GamePhase.waitingForPlayers;
    _gameState = null;
  }

  // === Room Actions ===

  /// Rejoint une salle de jeu
  void joinRoom(String roomId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.roomPrefix}$roomId',
        event: WebSocketEvents.phxJoin,
        payload: {},
      );
    }
  }

  /// Quitte une salle
  void leaveRoom(String roomId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.roomPrefix}$roomId',
        event: WebSocketEvents.phxLeave,
      );
    }
  }

  /// Démarre le match dans la salle
  void startRoomMatch(String roomId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.roomPrefix}$roomId',
        event: WebSocketEvents.matchStarted,
      );
    }
  }

  /// Signale que le joueur est prêt
  void playerReady(String roomId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.roomPrefix}$roomId',
        event: WebSocketEvents.playerReady,
      );
    }
  }

  // === Friend Actions ===

  /// Rejoint le canal de notifications amis
  void joinFriendChannel() {
    if (isConnected) {
      _sendToChannel(
        topic: WebSocketChannels.friendNotif,
        event: WebSocketEvents.phxJoin,
      );
    }
  }

  /// Envoie une invitation de jeu à un ami
  void sendGameInvite({required String friendId, required String roomCode}) {
    if (isConnected) {
      _sendToChannel(
        topic: WebSocketChannels.friendNotif,
        event: 'send_game_invite',
        payload: {
          'friend_id': friendId,
          'room_code': roomCode,
        },
      );
    }
  }

  /// Envoie un message chat à un ami
  void sendChatMessage({required String friendId, required String content}) {
    if (isConnected) {
      _sendToChannel(
        topic: WebSocketChannels.friendNotif,
        event: WebSocketEvents.chatMessage,
        payload: {
          'friend_id': friendId,
          'content': content,
        },
      );
    }
  }

  // === Match Actions ===

  /// Vote pour la cible (mode Cible)
  void voteTarget(String matchId, int targetValue) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'vote_target',
        payload: {'target_value': targetValue},
      );
    }
  }

  /// Lance les dés
  void rollDice(String matchId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: WebSocketEvents.diceRolled,
      );
    }
  }

  /// Démarre le set suivant (après résultat)
  void startSet(String matchId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'start_set',
      );
    }
  }

  // === Revanche opt-out (fin de partie) ===

  /// Propose une revanche aux joueurs restants
  void proposeRematch(String matchId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'propose_rematch',
      );
    }
  }

  /// Répond à une revanche proposée
  void respondRematch(String matchId, bool accept) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'respond_rematch',
        payload: {'accept': accept},
      );
    }
  }

  /// Démarre la revanche (proposant) avec les acceptants
  void startRematch(String matchId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'start_rematch',
      );
    }
  }

  /// Annule une revanche proposée (proposant)
  void cancelRematch(String matchId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'cancel_rematch',
      );
    }
  }

  /// Signale la sortie de l'interface de fin de partie (exclu des revanches)
  void leaveMatch(String matchId) {
    if (isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$matchId',
        event: 'leave_match',
      );
    }
  }

  // === User Channel (wallet/stats temps réel) ===
  void joinUserChannel(String userId) {
    if (userId.isNotEmpty) _pendingUserChannels.add(userId);
    if (isConnected && userId.isNotEmpty) {
      _sendToChannel(
        topic: 'user:$userId',
        event: WebSocketEvents.phxJoin,
        payload: {},
      );
      _sendToChannel(
        topic: 'user:$userId:wallet',
        event: WebSocketEvents.phxJoin,
        payload: {},
      );
    }
  }

  void leaveUserChannel(String userId) {
    if (isConnected && userId.isNotEmpty) {
      _sendToChannel(
        topic: 'user:$userId',
        event: WebSocketEvents.phxLeave,
        payload: {},
      );
    }
  }

  // === Message Handling ===

  void _sendToChannel({
    required String topic,
    required String event,
    Map<String, dynamic>? payload,
  }) {
    if (_channel == null) return;

    // Protocole Phoenix V2 : join_ref stable par topic, ref monotone par message.
    // Sans join_ref le serveur peut ignorer le join → aucun event temps réel.
    final isJoin = event == WebSocketEvents.phxJoin;
    if (isJoin) {
      _joinRefCounter++;
      _joinRefs[topic] = '$_joinRefCounter';
    }
    _refCounter++;
    final ref = '$_refCounter';
    final joinRef = _joinRefs[topic];
    _lastRefByTopicEvent['$topic:$event'] = ref;

    final message = jsonEncode({
      'topic': topic,
      'event': event,
      'payload': payload ?? {},
      'ref': ref,
      if (joinRef != null) 'join_ref': joinRef,
    });

    _channel!.sink.add(message);
    debugPrint('→ Game WS: $topic:$event');
  }

  void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);
      // Supporte Phoenix V2 (map) ET V1 (array [join_ref, ref, topic, event, payload])
      String? event;
      Map<String, dynamic> payload = {};
      String? topic;

      if (decoded is List && decoded.length >= 5) {
        topic = decoded[2]?.toString();
        event = decoded[3]?.toString();
        final rawPayload = decoded[4];
        if (rawPayload is Map) {
          payload = Map<String, dynamic>.from(rawPayload);
        }
      } else if (decoded is Map<String, dynamic>) {
        final msg = decoded;
        event = msg['event'] as String?;
        topic = msg['topic'] as String?;
        final rawPayload = msg['payload'];
        if (rawPayload is Map) {
          payload = Map<String, dynamic>.from(rawPayload);
        }
      } else if (decoded is Map) {
        final msg = Map<String, dynamic>.from(decoded);
        event = msg['event']?.toString();
        topic = msg['topic']?.toString();
        final rawPayload = msg['payload'];
        if (rawPayload is Map) {
          payload = Map<String, dynamic>.from(rawPayload);
        }
      } else {
        return;
      }

      if (event == null) return;

      _events.add({'topic': topic, 'event': event, 'payload': payload});
      if (_events.length > 200) _events.removeAt(0);

      debugPrint('← Game WS: $event${topic != null ? ' ($topic)' : ''}');

      // Dispatch events
      switch (event) {
        case 'phx_reply':
          _handleReply(payload);
          break;
        case WebSocketEvents.gameMatched:
          _currentGameId = payload['game_id'] as String?;
          onGameMatched?.call(payload);
          break;
        case WebSocketEvents.playerJoined:
          _phase = GamePhase.waitingForPlayers;
          onPlayerJoined?.call(payload);
          break;
        case WebSocketEvents.gameStarted:
          _phase = GamePhase.betting;
          _gameState = payload;
          notifyListeners();
          break;
        case WebSocketEvents.betPlaced:
          _gameState = {...?_gameState, ...payload};
          onBetPlaced?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.turnExecuted:
          _phase = GamePhase.result;
          _gameState = {...?_gameState, ...payload};
          onTurnExecuted?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.gameResult:
          _phase = GamePhase.finished;
          _gameState = {...?_gameState, ...payload};
          onGameResult?.call(payload);
          notifyListeners();
          break;
        // Room events
        case WebSocketEvents.roomUpdated:
          onRoomUpdated?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.playerLeft:
          onPlayerLeftRoom?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.matchStarted:
          onMatchStarted?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.roomCancelled:
          onRoomCancelled?.call(payload);
          notifyListeners();
          break;
        // Friend events
        case WebSocketEvents.friendRequest:
          onFriendRequest?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.friendAccepted:
          onFriendAccepted?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.friendOnline:
          onFriendOnline?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.gameInvitation:
          onGameInvitation?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.activityUpdate:
          onActivityUpdate?.call(payload);
          notifyListeners();
          break;
        // Match events
        case WebSocketEvents.setStarted:
          onSetStarted?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.diceRolling:
          onDiceRolling?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.diceRolled:
          onDiceRolled?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.turnChanged:
          onTurnChanged?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.setResult:
          onSetResult?.call(payload);
          notifyListeners();
          break;
        case WebSocketEvents.matchResult:
          onMatchResult?.call(payload);
          notifyListeners();
          break;
        case 'target_voted':
        case 'target_calculated':
        case 'vote_progress':
          onTargetVoted?.call(payload);
          notifyListeners();
          break;
        case 'player_forfeited':
          onPlayerForfeited?.call(payload);
          notifyListeners();
          break;
        case 'match_forfeit':
          onMatchForfeit?.call(payload);
          onPlayerForfeited?.call(payload);
          notifyListeners();
          break;
        case 'match_state':
          onMatchState?.call(payload);
          notifyListeners();
          break;
        case 'rematch_proposed':
          onRematchProposed?.call(payload);
          notifyListeners();
          break;
        case 'rematch_updated':
          onRematchUpdated?.call(payload);
          notifyListeners();
          break;
        case 'rematch_ready':
          onRematchReady?.call(payload);
          notifyListeners();
          break;
        case 'rematch_cancelled':
          onRematchCancelled?.call(payload);
          notifyListeners();
          break;
        case 'lobby_update':
          onLobbyUpdate?.call(payload);
          notifyListeners();
          break;
        case 'wallet_update':
          onWalletUpdate?.call(payload);
          notifyListeners();
          break;
        case 'stats_update':
          onStatsUpdate?.call(payload);
          notifyListeners();
          break;
      }
    } catch (e) {
      debugPrint('✗ Game WS parse error: $e');
    }
  }

  void _handleReply(Map<String, dynamic> payload) {
    // Phoenix phx_reply : {status: ok|error, response: {...}}
    final status = payload['status']?.toString();
    final response = payload['response'];
    if (status == 'error') {
      final err = response is Map
          ? Map<String, dynamic>.from(response)
          : {'reason': response?.toString() ?? 'unknown'};
      debugPrint('✗ Game WS reply error: $err');
      onChannelError?.call(err);
      notifyListeners();
      return;
    }
    if (response is Map) {
      final respMap = Map<String, dynamic>.from(response);
      _gameState = {...?_gameState, ...respMap};
      notifyListeners();
    }
  }

  void _handleError(error) {
    debugPrint('✗ Game WS error: $error');
    _setConnectionStatus(GameConnectionStatus.fallbackRest);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    debugPrint('⚠ Game WS disconnected');
    _setConnectionStatus(GameConnectionStatus.fallbackRest);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '✗ Game WS: max reconnections reached, staying in REST fallback',
      );
      _setConnectionStatus(GameConnectionStatus.fallbackRest);
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    _setConnectionStatus(GameConnectionStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _setConnectionStatus(GameConnectionStatus newStatus) {
    _connectionStatus = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

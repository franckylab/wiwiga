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
  void Function(Map<String, dynamic>)? onDiceRolled;
  void Function(Map<String, dynamic>)? onSetResult;
  void Function(Map<String, dynamic>)? onMatchResult;
  void Function(Map<String, dynamic>)? onTargetVoted;
  void Function(Map<String, dynamic>)? onPlayerForfeited;
  void Function(Map<String, dynamic>)? onMatchForfeit;
  
  GameWebSocketService({required ApiService apiService})
      : _apiService = apiService;
  
  // === Getters ===
  
  GameConnectionStatus get connectionStatus => _connectionStatus;
  String? get currentGameId => _currentGameId;
  GamePhase get phase => _phase;
  Map<String, dynamic>? get gameState => _gameState;
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  bool get isConnected => _connectionStatus == GameConnectionStatus.connected;
  bool get isFallbackMode => _connectionStatus == GameConnectionStatus.fallbackRest;
  
  // === Connection ===
  
  /// Définit le token d'authentification
  void setAuthToken(String token) {
    _authToken = token;
  }
  
  /// Connecte au WebSocket Phoenix
  Future<void> connect() async {
    if (_connectionStatus == GameConnectionStatus.connected) return;
    
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
  
  // === Matchmaking ===
  
  /// Rejoint la file de matchmaking via WebSocket (ou REST en fallback)
  Future<Map<String, dynamic>> joinMatchmaking({
    required String gameType,
    required int betAmount,
  }) async {
    if (isConnected) {
      _sendToChannel(
        topic: WebSocketChannels.matchmaking,
        event: WebSocketEvents.joinQueue,
        payload: {
          'game_type': gameType,
          'bet_amount': betAmount,
        },
      );
      return {'status': 'queued'};
    } else {
      // Fallback REST
      return await _apiService.post(
        '${ApiEndpoints.joinGame}/$gameType',
        body: {'bet_amount': betAmount},
        requiresAuth: true,
      );
    }
  }
  
  /// Quitte la file de matchmaking
  void leaveMatchmaking() {
    if (isConnected) {
      _sendToChannel(
        topic: WebSocketChannels.matchmaking,
        event: WebSocketEvents.leaveQueue,
      );
    }
  }
  
  // === Game Actions ===
  
  /// Rejoint une partie spécifique
  void joinGame(String gameId) {
    _currentGameId = gameId;
    _phase = GamePhase.waitingForPlayers;
    
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
    if (_currentGameId != null && isConnected) {
      _sendToChannel(
        topic: '${WebSocketChannels.gamePrefix}$_currentGameId',
        event: WebSocketEvents.phxLeave,
      );
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
  
  // === Message Handling ===
  
  void _sendToChannel({
    required String topic,
    required String event,
    Map<String, dynamic>? payload,
  }) {
    if (_channel == null) return;
    
    final message = jsonEncode({
      'topic': topic,
      'event': event,
      'payload': payload ?? {},
      'ref': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    
    _channel!.sink.add(message);
    debugPrint('→ Game WS: $topic:$event');
  }
  
  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final event = msg['event'] as String?;
      final payload = msg['payload'] as Map<String, dynamic>? ?? {};
      
      _events.add(msg);
      if (_events.length > 200) _events.removeAt(0);
      
      debugPrint('← Game WS: $event');
      
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
        case WebSocketEvents.diceRolled:
          onDiceRolled?.call(payload);
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
      }
    } catch (e) {
      debugPrint('✗ Game WS parse error: $e');
    }
  }
  
  void _handleReply(Map<String, dynamic> payload) {
    final response = payload['response'] as Map<String, dynamic>?;
    if (response != null) {
      _gameState = {...?_gameState, ...response};
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
      debugPrint('✗ Game WS: max reconnections reached, staying in REST fallback');
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

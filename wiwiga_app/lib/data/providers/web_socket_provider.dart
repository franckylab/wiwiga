// ============================================================
// Fichier: web_socket_provider.dart
// Description: Provider WebSocket pour communication temps réel
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/app_config.dart';
import '../constants/api_constants.dart';

/// États de la connexion WebSocket
enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Provider WebSocket avec gestion automatique de connexion
class WebSocketProvider extends ChangeNotifier {
  WebSocketChannel? _channel;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  final List<Map<String, dynamic>> _messages = [];
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  
  WebSocketStatus get status => _status;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  
  /// Connecte au serveur WebSocket
  Future<void> connect() async {
    if (_status == WebSocketStatus.connected) return;
    
    _setStatus(WebSocketStatus.connecting);
    
    try {
      final uri = Uri.parse('${AppConfig.websocketUrl}/socket/websocket');
      
      _channel = WebSocketChannel.connect(uri);
      
      await _channel!.ready;
      
      _setStatus(WebSocketStatus.connected);
      _reconnectAttempts = 0;
      
      // Écoute les messages entrants
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
      
      debugPrint('✓ WebSocket connecté');
    } catch (e) {
      debugPrint('✗ Erreur connexion WebSocket: $e');
      _setStatus(WebSocketStatus.error);
      _scheduleReconnect();
    }
  }
  
  /// Déconnecte du serveur
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _setStatus(WebSocketStatus.disconnected);
    debugPrint('✓ WebSocket déconnecté');
  }
  
  /// Envoie un message au serveur
  void send({
    required String topic,
    required String event,
    Map<String, dynamic>? payload,
  }) {
    if (_channel == null || _status != WebSocketStatus.connected) {
      debugPrint('⚠ WebSocket non connecté');
      return;
    }
    
    final message = {
      'topic': topic,
      'event': event,
      'payload': payload ?? {},
    };
    
    _channel!.sink.add(jsonEncode(message));
    debugPrint('→ Message envoyé: $topic:$event');
  }
  
  /// Rejoindre un canal (join)
  void joinChannel(String topic, Map<String, dynamic>? params) {
    send(
      topic: topic,
      event: 'phx_join',
      payload: params,
    );
  }
  
  /// Quitter un canal (leave)
  void leaveChannel(String topic) {
    send(
      topic: topic,
      event: 'phx_leave',
    );
  }
  
  /// Traite un message entrant
  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      _messages.add(message);
      
      // Limite l'historique à 100 messages
      if (_messages.length > 100) {
        _messages.removeAt(0);
      }
      
      debugPrint('← Message reçu: ${message['topic']}:${message['event']}');
      notifyListeners();
    } catch (e) {
      debugPrint('✗ Erreur traitement message: $e');
    }
  }
  
  /// Gère les erreurs WebSocket
  void _handleError(error) {
    debugPrint('✗ Erreur WebSocket: $error');
    _setStatus(WebSocketStatus.error);
    _scheduleReconnect();
  }
  
  /// Gère la déconnexion
  void _handleDisconnect() {
    debugPrint('⚠ WebSocket déconnecté');
    _setStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }
  
  /// Planifie une reconnexion automatique
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('✗ Trop de tentatives de reconnexion');
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    
    debugPrint('↻ Reconnexion dans ${delay.inSeconds}s (tentative $_reconnectAttempts)');
    
    _setStatus(WebSocketStatus.reconnecting);
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }
  
  /// Met à jour le statut et notifie les écouteurs
  void _setStatus(WebSocketStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }
  
  /// Nettoie les ressources
  @override
  void dispose() {
    disconnect();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

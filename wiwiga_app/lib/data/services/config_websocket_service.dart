import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../presentation/providers/config_provider.dart';
import '../config/app_config.dart';

/// Service d'écoute WebSocket pour les mises à jour de configuration en temps réel
class ConfigWebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;

  // Callbacks pour les updates
  Function(ThemeConfigModel)? onThemeUpdate;
  Function(FeatureConfigModel)? onFeatureUpdate;
  Function(String, Map<String, dynamic>)? onGameConfigUpdate;
  Function(String, Map<String, dynamic>)? onPaymentConfigUpdate;

  bool get isConnected => _isConnected;

  /// Initialise et connecte le WebSocket pour la config
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final uri = Uri.parse('${AppConfig.websocketUrl}/socket/websocket');

      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;

      _isConnected = true;
      _reconnectAttempts = 0;

      // Écoute les messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      debugPrint('✅ ConfigWebSocket connecté');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur connexion ConfigWebSocket: $e');
      _scheduleReconnect();
    }
  }

  /// Déconnecte le WebSocket
  void disconnect() {
    _channel?.sink.close(1000, 'Client disconnected');
    _channel = null;
    _isConnected = false;
    _reconnectTimer?.cancel();
    debugPrint('🔌 ConfigWebSocket déconnecté');
    notifyListeners();
  }

  /// Traite les messages reçus
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final event = data['event'] as String?;

      if (event == null) return;

      switch (event) {
        case 'theme:update':
          _handleThemeUpdate(data);
          break;
        case 'feature:update':
          _handleFeatureUpdate(data);
          break;
        case 'game_config:update':
          _handleGameConfigUpdate(data);
          break;
        case 'payment_config:update':
          _handlePaymentConfigUpdate(data);
          break;
        default:
          debugPrint('⚠️ Événement config non reconnu: $event');
      }
    } catch (e) {
      debugPrint('❌ Erreur traitement message WebSocket: $e');
    }
  }

  /// Handle update thème
  void _handleThemeUpdate(Map<String, dynamic> data) {
    try {
      final configData = data['config'] as Map<String, dynamic>;
      final themeConfig = ThemeConfigModel.fromJson(configData);

      debugPrint('🎨 Thème mis à jour via WebSocket');

      if (onThemeUpdate != null) {
        onThemeUpdate!(themeConfig);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur update thème: $e');
    }
  }

  /// Handle update features
  void _handleFeatureUpdate(Map<String, dynamic> data) {
    try {
      final configData = data['config'] as Map<String, dynamic>;
      final featureConfig = FeatureConfigModel.fromJson(configData);

      debugPrint('⚙️ Features mises à jour via WebSocket');

      if (onFeatureUpdate != null) {
        onFeatureUpdate!(featureConfig);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur update features: $e');
    }
  }

  /// Handle update config jeu
  void _handleGameConfigUpdate(Map<String, dynamic> data) {
    try {
      final gameType = data['game_type'] as String;
      final configData = data['config'] as Map<String, dynamic>;

      debugPrint('🎲 Config jeu $gameType mise à jour via WebSocket');

      if (onGameConfigUpdate != null) {
        onGameConfigUpdate!(gameType, configData);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur update config jeu: $e');
    }
  }

  /// Handle update config paiement
  void _handlePaymentConfigUpdate(Map<String, dynamic> data) {
    try {
      final provider = data['provider'] as String;
      final configData = data['config'] as Map<String, dynamic>;

      debugPrint('💳 Config paiement $provider mise à jour via WebSocket');

      if (onPaymentConfigUpdate != null) {
        onPaymentConfigUpdate!(provider, configData);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur update config paiement: $e');
    }
  }

  /// Handle erreur
  void _handleError(error) {
    debugPrint('❌ Erreur WebSocket: $error');
    _scheduleReconnect();
  }

  /// Handle déconnexion
  void _handleDisconnect() {
    _isConnected = false;
    debugPrint('🔌 WebSocket déconnecté');
    _scheduleReconnect();
    notifyListeners();
  }

  /// Planifie la reconnexion
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('⚠️ Maximum de tentatives de reconnexion atteint');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    debugPrint('🔄 Reconnexion dans ${delay.inSeconds}s (tentative $_reconnectAttempts/$maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  @override
  void dispose() {
    disconnect();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

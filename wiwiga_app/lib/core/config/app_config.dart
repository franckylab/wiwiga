// ============================================================
// Fichier: app_config.dart
// Description: Configuration globale de l'application WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/foundation.dart';

/// Configuration centrale de l'application
class AppConfig {
  // URL de l'API backend
  static late final String baseUrl;

  // URL WebSocket pour temps réel
  static late final String websocketUrl;

  // Clé API Campay (optionnel)
  static late final String? campayApiKey;

  // Timeout des requêtes HTTP (ms)
  static const int requestTimeout = 15000;

  // Version de l'app
  static const String version = '1.0.0';

  /// Initialise la configuration selon l'environnement
  static void initialize() {
    // Surcharge possible via --dart-define=API_BASE_URL=... / WS_BASE_URL=...
    const overrideApi = String.fromEnvironment('API_BASE_URL');
    const overrideWs = String.fromEnvironment('WS_BASE_URL');

    if (overrideApi.isNotEmpty) {
      // URL explicite passée au build (Docker, CI, etc.)
      baseUrl = overrideApi;
      websocketUrl = overrideWs.isNotEmpty
          ? overrideWs
          : overrideApi.replaceFirst('http', 'ws');
      campayApiKey = null;
    } else if (kIsWeb && kDebugMode) {
      // Le serveur Flutter de debug ne proxyfie pas les routes API.
      baseUrl = _buildDebugBackendUrl('http');
      websocketUrl = _buildDebugBackendUrl('ws');
      campayApiKey = null;
    } else if (kIsWeb) {
      // En mode web production, utiliser la même origine (proxy nginx)
      baseUrl = _buildOrigin();
      websocketUrl = _buildWebSocketUrl();
      campayApiKey = null;
    } else if (kDebugMode) {
      // Debug natif (mobile/desktop en dev)
      baseUrl = 'http://localhost:8000';
      websocketUrl = 'ws://localhost:8000';
      campayApiKey = null;
    } else {
      // Production native (fallback)
      baseUrl = 'https://api.wiwiga.com';
      websocketUrl = 'wss://api.wiwiga.com';
      campayApiKey = const String.fromEnvironment('CAMPAY_API_KEY');
    }

    debugPrint('✓ WIWIGA App v$version initialisée');
    debugPrint('  API: $baseUrl');
    debugPrint('  WebSocket: $websocketUrl');
  }

  /// Construit l'URL d'origine depuis le navigateur
  static String _buildOrigin() {
    try {
      final uri = Uri.base;
      final scheme = uri.scheme;
      final host = uri.host;
      final port = uri.port;
      if (port == 80 || port == 443 || port == 0) {
        return '$scheme://$host';
      }
      return '$scheme://$host:$port';
    } catch (_) {
      return 'http://localhost:8003';
    }
  }

  /// Construit l'URL WebSocket depuis l'origine courante
  static String _buildWebSocketUrl() {
    try {
      final uri = Uri.base;
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final host = uri.host;
      final port = uri.port;
      if (port == 80 || port == 443 || port == 0) {
        return '$scheme://$host';
      }
      return '$scheme://$host:$port';
    } catch (_) {
      return 'ws://localhost:8000';
    }
  }

  /// Construit l'URL du backend direct pour le serveur Flutter de debug.
  static String _buildDebugBackendUrl(String scheme) {
    try {
      final uri = Uri.base;
      final host = uri.host.isNotEmpty ? uri.host : 'localhost';
      return '$scheme://$host:8000';
    } catch (_) {
      return '$scheme://localhost:8000';
    }
  }

  /// Vérifie si l'app est en mode développement
  static bool get isDevelopment => kDebugMode;

  /// Vérifie si l'app est en mode production
  static bool get isProduction => !kDebugMode;
}

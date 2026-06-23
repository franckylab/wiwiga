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
    if (kDebugMode) {
      baseUrl = 'http://localhost:8000';
      websocketUrl = 'ws://localhost:8000';
      campayApiKey = null;
    } else {
      baseUrl = 'https://api.wiwiga.com';
      websocketUrl = 'wss://api.wiwiga.com';
      campayApiKey = const String.fromEnvironment('CAMPAY_API_KEY');
    }
    
    debugPrint('✓ WIWIGA App v$version initialisée');
    debugPrint('  API: $baseUrl');
    debugPrint('  WebSocket: $websocketUrl');
  }
  
  /// Vérifie si l'app est en mode développement
  static bool get isDevelopment => kDebugMode;
  
  /// Vérifie si l'app est en mode production
  static bool get isProduction => !kDebugMode;
}

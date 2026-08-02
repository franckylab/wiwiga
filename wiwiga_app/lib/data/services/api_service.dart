// ============================================================
// Fichier: api_service.dart
// Description: Service HTTP avec refresh token automatique
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';

/// Service centralisé pour les requêtes HTTP
/// 
/// Fonctionnalités avancées :
/// - Stockage sécurisé des tokens (access + refresh)
/// - Refresh token automatique (silent retry)
/// - Device ID unique par appareil
/// - Gestion des erreurs 401 avec retry
class ApiService {
  final http.Client _client;
  final FlutterSecureStorage _storage;
  
  // Clés de stockage sécurisé
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyDeviceId = 'device_id';
  static const _keyLegacyToken = 'jwt_token'; // Migration depuis l'ancien système
  
  // État du refresh pour éviter les refresh simultanés
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;
  
  ApiService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  
  // ========================================
  // TOKENS — Gestion secure storage
  // ========================================
  
  /// Récupère l'access token
  Future<String?> getAccessToken() async {
    // D'abord vérifier la nouvelle clé
    String? token = await _storage.read(key: _keyAccessToken);
    
    // Migration depuis l'ancien système (jwt_token)
    if (token == null) {
      token = await _storage.read(key: _keyLegacyToken);
      if (token != null) {
        await _storage.write(key: _keyAccessToken, value: token);
        await _storage.delete(key: _keyLegacyToken);
      }
    }
    
    return token;
  }
  
  /// Récupère le refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }
  
  /// Sauvegarde les tokens après authentification
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
    // Nettoyer l'ancienne clé si elle existe
    await _storage.delete(key: _keyLegacyToken);
  }
  
  /// Compatibilité: getToken() retourne l'access token
  Future<String?> getToken() async => getAccessToken();
  
  /// Compatibilité: saveToken() sauvegarde comme access token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }
  
  /// Supprime tous les tokens (logout)
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyLegacyToken),
    ]);
  }
  
  /// Compatibilité: clearToken()
  Future<void> clearToken() async => clearTokens();
  
  /// Vérifie si l'utilisateur a des tokens
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }
  
  // ========================================
  // DEVICE ID — Identification appareil
  // ========================================
  
  /// Récupère ou génère le Device ID unique
  Future<String> getDeviceId() async {
    String? deviceId = await _storage.read(key: _keyDeviceId);
    
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _storage.write(key: _keyDeviceId, value: deviceId);
    }
    
    return deviceId;
  }
  
  // ========================================
  // HEADERS — Construction
  // ========================================
  
  /// Construit les headers avec authentification et device ID
  Future<Map<String, String>> _getHeaders({
    bool requiresAuth = false,
    bool includeDeviceId = false,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    if (includeDeviceId) {
      headers['X-Device-ID'] = await getDeviceId();
    }
    
    return headers;
  }
  
  // ========================================
  // REQUÊTES HTTP avec refresh automatique
  // ========================================
  
  /// Requête GET
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    final headers = await _getHeaders(
      requiresAuth: requiresAuth,
      includeDeviceId: requiresAuth,
    );
    
    var uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    
    final response = await _client.get(uri, headers: headers).timeout(
      const Duration(milliseconds: AppConfig.requestTimeout),
    );
    
    // Si 401 et auth requise, tenter refresh et retry
    if (response.statusCode == 401 && requiresAuth) {
      final retryResponse = await _handle401AndRetry(
        () async => _client.get(uri, headers: await _getHeaders(
          requiresAuth: true,
          includeDeviceId: true,
        ),).timeout(
          const Duration(milliseconds: AppConfig.requestTimeout),
        ),
      );
      if (retryResponse != null) return _handleResponse(retryResponse);
    }
    
    return _handleResponse(response);
  }
  
  /// Requête POST
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final headers = await _getHeaders(
      requiresAuth: requiresAuth,
      includeDeviceId: requiresAuth,
    );
    
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: headers,
      body: body is String ? body : (body != null ? jsonEncode(body) : null),
    ).timeout(
      const Duration(milliseconds: AppConfig.requestTimeout),
    );
    
    // Si 401 et auth requise, tenter refresh et retry
    if (response.statusCode == 401 && requiresAuth) {
      final retryResponse = await _handle401AndRetry(
        () async => _client.post(
          Uri.parse('${AppConfig.baseUrl}$endpoint'),
          headers: await _getHeaders(requiresAuth: true, includeDeviceId: true),
          body: body is String ? body : (body != null ? jsonEncode(body) : null),
        ).timeout(
          const Duration(milliseconds: AppConfig.requestTimeout),
        ),
      );
      if (retryResponse != null) return _handleResponse(retryResponse);
    }
    
    return _handleResponse(response);
  }
  
  /// Requête PUT
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    
    final response = await _client.put(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(
      const Duration(milliseconds: AppConfig.requestTimeout),
    );
    
    return _handleResponse(response);
  }
  
  /// Requête DELETE
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    
    final response = await _client.delete(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: headers,
    ).timeout(
      const Duration(milliseconds: AppConfig.requestTimeout),
    );
    
    return _handleResponse(response);
  }
  
  // ========================================
  // REFRESH TOKEN — Silent retry
  // ========================================
  
  /// Gère le refresh token automatique sur 401
  Future<http.Response?> _handle401AndRetry(
    Future<http.Response> Function() retryRequest,
  ) async {
    if (_isRefreshing) {
      // Attendre que le refresh en cours se termine
      if (_refreshCompleter != null) {
        await _refreshCompleter!.future;
      }
      // Retry avec le nouveau token
      return retryRequest();
    }
    
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        // Pas de refresh token, l'utilisateur doit se reconnecter
        _refreshCompleter!.complete(false);
        return null;
      }
      
      final deviceId = await getDeviceId();
      
      // Appeler l'endpoint de refresh
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}${ApiEndpoints.refreshToken}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
          'device_id': deviceId,
        }),
      ).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>;
        
        final newAccessToken = responseData['access_token'] as String;
        final newRefreshToken = responseData['refresh_token'] as String;
        
        // Sauvegarder les nouveaux tokens
        await saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );
        
        _refreshCompleter!.complete(true);
        
        // Retry la requête originale avec le nouveau token
        return retryRequest();
      } else {
        // Refresh échoué, l'utilisateur doit se reconnecter
        await clearTokens();
        _refreshCompleter!.complete(false);
        return null;
      }
    } catch (e) {
      _refreshCompleter!.complete(false);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
  
  // ========================================
  // RÉPONSE — Traitement
  // ========================================
  
  /// Traite la réponse HTTP
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else if (response.statusCode == 401) {
      throw Exception(ApiErrors.unauthorized);
    } else if (response.statusCode == 429) {
      throw Exception('Trop de tentatives. Veuillez réessayer plus tard.');
    } else if (response.statusCode == 422) {
      throw Exception(data['error'] ?? ApiErrors.invalidResponse);
    } else {
      final error = data['error'];
      if (error is Map) {
        throw Exception(error['message'] ?? ApiErrors.serverError);
      }
      throw Exception(error is String ? error : ApiErrors.serverError);
    }
  }
  
  /// Libère les ressources
  void dispose() {
    _client.close();
  }
}

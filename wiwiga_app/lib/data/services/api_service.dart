// ============================================================
// Fichier: api_service.dart
// Description: Service HTTP avec refresh token automatique
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/api_exception.dart';
import '../../core/storage/app_storage.dart';

/// Service centralisé pour les requêtes HTTP
/// 
/// Fonctionnalités avancées :
/// - Stockage sécurisé des tokens (access + refresh)
/// - Refresh token automatique (silent retry)
/// - Device ID unique par appareil
/// - Gestion des erreurs 401 avec retry
/// - Notification quand la session est expirée (tokens effacés)
class ApiService {
  final http.Client _client;
  final AppStorage _storage;
  
  // Clés de stockage sécurisé
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyDeviceId = 'device_id';
  static const _keyLegacyToken = 'jwt_token'; // Migration depuis l'ancien système
  
  // État du refresh pour éviter les refresh simultanés
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;
  
  // Stream pour notifier quand les tokens sont effacés (session expirée)
  final _sessionExpiredController = StreamController<bool>.broadcast();
  
  /// Stream qui émet `true` quand les tokens sont effacés (session expirée)
  /// Les listeners peuvent utiliser cela pour rediriger vers /auth
  Stream<bool> get onSessionExpired => _sessionExpiredController.stream;
  
  ApiService({http.Client? client, AppStorage? storage, FlutterSecureStorage? secureStorage})
      : _client = client ?? http.Client(),
        _storage = storage ??
            AppStorage(secure: secureStorage ?? const FlutterSecureStorage());
  
  // ========================================
  // TOKENS — Gestion secure storage
  // ========================================
  
  /// Récupère l'access token (résilient LAN insecure context)
  Future<String?> getAccessToken() async {
    try {
      String? token = await _storage.read(key: _keyAccessToken);
      if (token == null) {
        token = await _storage.read(key: _keyLegacyToken);
        if (token != null) {
          try {
            await _storage.write(key: _keyAccessToken, value: token);
            await _storage.delete(key: _keyLegacyToken);
          } catch (_) {}
        }
      }
      return token;
    } catch (e) {
      debugPrint('[ApiService] getAccessToken error (LAN fallback): $e');
      return null;
    }
  }
  
  /// Récupère le refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('[ApiService] getRefreshToken error: $e');
      return null;
    }
  }
  
  /// Sauvegarde les tokens après authentification (LAN-resilient)
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyAccessToken, value: accessToken),
        _storage.write(key: _keyRefreshToken, value: refreshToken),
      ]);
      try {
        await _storage.delete(key: _keyLegacyToken);
      } catch (_) {}
      if (kDebugMode) debugPrint('[ApiService] tokens saved OK (LAN fallback capable)');
    } catch (e) {
      debugPrint('[ApiService] saveTokens FAILED: $e');
      rethrow;
    }
  }
  
  /// Compatibilité: getToken() retourne l'access token
  Future<String?> getToken() async => getAccessToken();
  
  /// Compatibilité: saveToken() sauvegarde comme access token
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _keyAccessToken, value: token);
    } catch (e) {
      debugPrint('[ApiService] saveToken failed: $e');
      rethrow;
    }
  }
  
  /// Supprime tous les tokens (logout)
  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyAccessToken),
        _storage.delete(key: _keyRefreshToken),
        _storage.delete(key: _keyLegacyToken),
      ]);
    } catch (e) {
      debugPrint('[ApiService] clearTokens error (non-bloquant): $e');
    }
    // Notifier les listeners que la session est expirée
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(true);
    }
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
  
  /// Récupère ou génère le Device ID unique (LAN-resilient)
  Future<String> getDeviceId() async {
    try {
      String? deviceId = await _storage.read(key: _keyDeviceId);
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        try {
          await _storage.write(key: _keyDeviceId, value: deviceId);
        } catch (e) {
          debugPrint('[ApiService] getDeviceId write failed, returning ephemeral: $e');
        }
      }
      return deviceId;
    } catch (e) {
      debugPrint('[ApiService] getDeviceId read failed, ephemeral: $e');
      return const Uuid().v4();
    }
  }

  /// Diagnostic stockage (pour debug LAN)
  Future<Map<String, dynamic>> diagnoseStorage() => _storage.diagnose();
  
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
  
  /// Wraps a network request to catch transport errors (timeout, socket)
  /// and convert them to [ApiException.network].
  /// Ajout diagnostic LAN: loggue baseUrl et origine pour debug CORS 192.168
  Future<T> _wrapNetwork<T>(Future<T> Function() request, {String? url}) async {
    try {
      return await request();
    } on TimeoutException catch (_) {
      if (kDebugMode) debugPrint('[ApiService] Timeout for $url (baseUrl=${AppConfig.baseUrl})');
      throw ApiException.network('Délai d\'attente dépassé. Vérifiez votre connexion.', url: url);
    } catch (e, st) {
      if (e is ApiException) rethrow;
      // SocketException, HttpException, CORS TypeError (Failed to fetch) sur Web
      if (kDebugMode) {
        debugPrint('[ApiService] Network error for $url -> $e');
        debugPrint('[ApiService] baseUrl=${AppConfig.baseUrl} isWeb=$kIsWeb');
        debugPrint('$st');
      }
      throw ApiException.network('Erreur de connexion. Vérifiez votre réseau. ($e)', url: url);
    }
  }
  
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
    
    final response = await _wrapNetwork(
      () => _client.get(uri, headers: headers).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      ),
      url: uri.toString(),
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
    
    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
    
    final response = await _wrapNetwork(
      () => _client.post(uri, headers: headers, body: encodedBody).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      ),
      url: uri.toString(),
    );
    
    // Si 401 et auth requise, tenter refresh et retry
    if (response.statusCode == 401 && requiresAuth) {
      final retryResponse = await _handle401AndRetry(
        () async => _client.post(
          uri,
          headers: await _getHeaders(requiresAuth: true, includeDeviceId: true),
          body: encodedBody,
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
    bool requiresAuth = true,
  }) async {
    final encodedBody = body != null ? jsonEncode(body) : null;
    final headers = await _getHeaders(requiresAuth: requiresAuth, includeDeviceId: requiresAuth);
    
    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final response = await _wrapNetwork(
      () => _client.put(uri, headers: headers, body: encodedBody).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      ),
      url: uri.toString(),
    );

    if (response.statusCode == 401 && requiresAuth) {
      final retryResponse = await _handle401AndRetry(
        () async => _client.put(
          uri,
          headers: await _getHeaders(requiresAuth: true, includeDeviceId: true),
          body: encodedBody,
        ).timeout(const Duration(milliseconds: AppConfig.requestTimeout)),
      );
      if (retryResponse != null) return _handleResponse(retryResponse);
    }
    
    return _handleResponse(response);
  }
  
  /// Requête DELETE
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth, includeDeviceId: requiresAuth);
    
    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final response = await _wrapNetwork(
      () => _client.delete(uri, headers: headers).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      ),
      url: uri.toString(),
    );

    if (response.statusCode == 401 && requiresAuth) {
      final retryResponse = await _handle401AndRetry(
        () async => _client.delete(
          uri,
          headers: await _getHeaders(requiresAuth: true, includeDeviceId: true),
        ).timeout(const Duration(milliseconds: AppConfig.requestTimeout)),
      );
      if (retryResponse != null) return _handleResponse(retryResponse);
    }
    
    return _handleResponse(response);
  }
  
  /// Upload multipart (fichier)
  Future<Map<String, dynamic>> uploadMultipart(
    String endpoint, {
    required String fieldName,
    required String filePath,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);
    
    // Ajouter le token si requis
    if (requiresAuth) {
      final token = await getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    
    // Ajouter le fichier
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    
    final streamedResponse = await _wrapNetwork(
      () => request.send().timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      ),
      url: uri.toString(),
    );
    
    final response = await http.Response.fromStream(streamedResponse);
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
  
  /// Traite la réponse HTTP et lève une [ApiException] typée en cas d'erreur.
  ///
  /// Gestion des codes statut :
  /// - 2xx : succès → retourne le JSON décodé
  /// - 400 : bad request (paramètres invalides)
  /// - 401 : non autorisé → déclenche le refresh token
  /// - 403 : accès refusé
  /// - 404 : ressource non trouvée
  /// - 409 : conflit (ex: déjà dans une partie)
  /// - 422 : validation échouée
  /// - 429 : rate limit
  /// - 500+ : erreur serveur
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Parser le corps de réponse de manière robuste
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded == null) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return {'data': null};
        }
        throw _errorFromStatus(response.statusCode, null, url: response.request?.url.toString());
      }
      if (decoded is! Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return {'data': decoded};
        }
        throw _errorFromStatus(response.statusCode, null, url: response.request?.url.toString());
      }
      data = decoded;
    } catch (e) {
      if (e is ApiException) rethrow;
      // Le body n'est pas du JSON valide
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'data': response.body};
      }
      // Erreur serveur sans body JSON
      throw _errorFromStatus(response.statusCode, null, url: response.request?.url.toString());
    }

    // Succès
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    // Erreur : extraire le message et le code depuis la réponse
    final url = response.request?.url.toString();
    final error = data['error'];
    final errorCode = data['error_code'] as String?;
    final details = data['details'] as Map<String, dynamic>?;

    String message;
    if (error is Map) {
      message = (error['message'] as String?) ?? _defaultMessageForStatus(response.statusCode);
    } else if (error is String) {
      message = error;
    } else {
      message = _defaultMessageForStatus(response.statusCode);
    }

    throw _errorFromStatus(response.statusCode, message, url: url, errorCode: errorCode, details: details);
  }

  /// Crée une [ApiException] appropriée selon le code statut HTTP.
  ApiException _errorFromStatus(
    int statusCode,
    String? message, {
    String? url,
    String? errorCode,
    Map<String, dynamic>? details,
  }) {
    final msg = message ?? _defaultMessageForStatus(statusCode);

    switch (statusCode) {
      case 400:
        return ApiException.badRequest(msg, errorCode: errorCode, details: details, url: url);
      case 401:
        return ApiException.unauthorized(url: url);
      case 403:
        return ApiException.forbidden(msg, url: url);
      case 404:
        return ApiException.notFound(msg, url: url);
      case 409:
        return ApiException.conflict(msg, errorCode: errorCode, details: details, url: url);
      case 422:
        return ApiException.validation(msg, details: details, url: url);
      case 429:
        return ApiException.rateLimited(url: url);
      case >= 500:
        return ApiException.serverError(url: url);
      default:
        return ApiException(statusCode: statusCode, message: msg, errorCode: errorCode, details: details, requestUrl: url);
    }
  }

  /// Message d'erreur par défaut pour un code statut.
  String _defaultMessageForStatus(int status) {
    switch (status) {
      case 400:
        return 'Requête invalide. Vérifiez les informations saisies.';
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 403:
        return 'Accès refusé. Permissions insuffisantes.';
      case 404:
        return 'Ressource introuvable.';
      case 409:
        return 'Conflit. Cette ressource est déjà utilisée.';
      case 422:
        return 'Données invalides. Vérifiez le formulaire.';
      case 429:
        return 'Trop de tentatives. Veuillez patienter.';
      case 500:
        return 'Erreur serveur. Veuillez réessayer.';
      case 502:
      case 503:
        return 'Service temporairement indisponible.';
      default:
        return 'Erreur inattendue (code $status).';
    }
  }
  
  /// Libère les ressources
  void dispose() {
    _sessionExpiredController.close();
    _client.close();
  }
}

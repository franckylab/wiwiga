// ============================================================
// Fichier: api_service.dart
// Description: Service HTTP pour communication avec l'API WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../constants/api_constants.dart';

/// Service centralisé pour les requêtes HTTP
class ApiService {
  final http.Client _client;
  final FlutterSecureStorage _storage;
  
  ApiService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  
  /// Récupère le token JWT stocké
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
  
  /// Stocke le token JWT
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }
  
  /// Supprime le token (logout)
  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }
  
  /// Construit les headers avec authentification
  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  /// Requête GET
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      ).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw Exception(ApiErrors.networkError);
    }
  }
  
  /// Requête POST
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw Exception(ApiErrors.networkError);
    }
  }
  
  /// Requête PUT
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client.put(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(
        const Duration(milliseconds: AppConfig.requestTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw Exception(ApiErrors.networkError);
    }
  }
  
  /// Traite la réponse HTTP
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else if (response.statusCode == 401) {
      throw Exception(ApiErrors.unauthorized);
    } else if (response.statusCode == 422) {
      throw Exception(data['error'] ?? ApiErrors.invalidResponse);
    } else {
      throw Exception(data['error'] ?? ApiErrors.serverError);
    }
  }
  
  /// Libère les ressources
  void dispose() {
    _client.close();
  }
}

// ============================================================
// Fichier: auth_repository.dart
// Description: Repository d'authentification OTP + JWT
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import '../data/models/user_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant l'authentification
class AuthRepository {
  final ApiService _apiService;
  
  AuthRepository({required ApiService apiService})
      : _apiService = apiService;
  
  /// Envoie un code OTP au numéro de téléphone
  Future<void> sendOtp(String phoneNumber) async {
    await _apiService.post(
      ApiEndpoints.login,
      body: {'phone': phoneNumber},
    );
  }
  
  /// Vérifie le code OTP et retourne le token JWT + utilisateur
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.verifyOtp,
      body: {
        'phone': phoneNumber,
        'otp': otpCode,
      },
    );
    
    // Sauvegarder le token
    final token = response['token'] as String;
    await _apiService.saveToken(token);
    
    // Retourner token + utilisateur
    return {
      'token': token,
      'user': UserModel.fromJson(response['user']),
    };
  }
  
  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    try {
      await _apiService.post(
        ApiEndpoints.logout,
        requiresAuth: true,
      );
    } finally {
      await _apiService.clearToken();
    }
  }
  
  /// Vérifie si l'utilisateur est connecté (token présent)
  Future<bool> isAuthenticated() async {
    final token = await _apiService.getToken();
    return token != null && token.isNotEmpty;
  }
  
  /// Récupère le profil utilisateur
  Future<UserModel> getProfile() async {
    final response = await _apiService.get(
      ApiEndpoints.profile,
      requiresAuth: true,
    );
    
    return UserModel.fromJson(response['user']);
  }
}

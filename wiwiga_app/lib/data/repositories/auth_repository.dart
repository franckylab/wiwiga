// ============================================================
// Fichier: auth_repository.dart
// Description: Repository authentification avec refresh tokens
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant l'authentification OTP + JWT avec refresh tokens
class AuthRepository {
  final ApiService _apiService;
  
  AuthRepository({required ApiService apiService})
      : _apiService = apiService;
  
  /// Envoie un code OTP au numéro de téléphone
  Future<void> sendOtp(String phoneNumber) async {
    final deviceId = await _apiService.getDeviceId();
    
    await _apiService.post(
      ApiEndpoints.sendOtp,
      body: {
        'phone': phoneNumber,
        'device_id': deviceId,
      },
      requiresAuth: false,
    );
  }
  
  /// Envoie un code OTP par email
  Future<void> sendOtpByEmail(String email) async {
    final deviceId = await _apiService.getDeviceId();
    
    await _apiService.post(
      ApiEndpoints.sendOtp,
      body: {
        'email': email,
        'device_id': deviceId,
      },
      requiresAuth: false,
    );
  }
  
  /// Connexion par mot de passe (phone/email + password)
  /// 
  /// Retourne:
  /// - `{'otp_required': false, 'access_token': ..., 'refresh_token': ..., 'user': ...}` si connexion directe
  /// - `{'otp_required': true, 'user': ...}` si OTP requis
  Future<Map<String, dynamic>> loginWithPassword({
    String? phone,
    String? email,
    required String password,
  }) async {
    final deviceId = await _apiService.getDeviceId();
    
    final body = <String, dynamic>{
      'password': password,
      'device_id': deviceId,
    };
    
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    } else if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }
    
    final response = await _apiService.post(
      ApiEndpoints.login,
      body: body,
      requiresAuth: false,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    final otpRequired = data['otp_required'] as bool? ?? false;
    
    if (otpRequired) {
      // OTP requis: pas de tokens, juste l'user
      return {
        'otp_required': true,
        'user': UserModel.fromJson(data['user'] as Map<String, dynamic>),
      };
    }
    
    // Connexion directe avec tokens
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    
    await _apiService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    
    return {
      'otp_required': false,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': UserModel.fromJson(data['user'] as Map<String, dynamic>),
    };
  }
  
  /// Définit ou change le mot de passe (utilisateur authentifié)
  Future<void> setPassword(String newPassword) async {
    await _apiService.post(
      ApiEndpoints.setPassword,
      body: {'password': newPassword},
      requiresAuth: true,
    );
  }
  
  /// Inscription (création de compte)
  Future<Map<String, dynamic>> register({
    String? phone,
    String? email,
    required String username,
    String? avatarType,
  }) async {
    final body = <String, dynamic>{
      'username': username,
    };
    
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    }
    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }
    if (avatarType != null) {
      body['avatar_type'] = avatarType;
    }
    
    final response = await _apiService.post(
      ApiEndpoints.register,
      body: body,
      requiresAuth: false,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    return {
      'user': UserModel.fromJson(data['user'] as Map<String, dynamic>),
      'message': data['message'] as String?,
    };
  }
  
  /// Vérifie la disponibilité d'un phone/email
  Future<bool> checkAvailability({String? phone, String? email}) async {
    try {
      await _apiService.post(
        ApiEndpoints.checkAvailability,
        body: {
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
        },
        requiresAuth: false,
      );
      return true; // available
    } catch (_) {
      return false; // taken
    }
  }
  
  /// Complète l'inscription (username + avatar après OTP)
  Future<UserModel> completeRegistration({
    required String username,
    String? avatarType,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.completeRegistration,
      body: {
        'username': username,
        if (avatarType != null) 'avatar_type': avatarType,
      },
      requiresAuth: true,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }
  
  /// Récupère la liste des avatars prédéfinis
  Future<List<Map<String, dynamic>>> getAvatars() async {
    final response = await _apiService.get(
      ApiEndpoints.avatars,
      requiresAuth: false,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    final avatars = data['avatars'] as List;
    return avatars.cast<Map<String, dynamic>>();
  }
  
  /// Vérifie le code OTP et retourne les tokens + utilisateur
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final deviceId = await _apiService.getDeviceId();
    
    final response = await _apiService.post(
      ApiEndpoints.verifyOtp,
      body: {
        'phone': phoneNumber,
        'otp': otpCode,
        'device_id': deviceId,
      },
      requiresAuth: false,
    );
    
    // Backend retourne {success: true, data: {access_token, refresh_token, user}}
    final data = response['data'] as Map<String, dynamic>;
    
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    
    // Sauvegarder les tokens en secure storage
    await _apiService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': UserModel.fromJson(data['user']),
    };
  }
  
  /// Vérifie le code OTP par email et retourne les tokens + utilisateur
  Future<Map<String, dynamic>> verifyOtpByEmail({
    required String email,
    required String otpCode,
  }) async {
    final deviceId = await _apiService.getDeviceId();
    
    final response = await _apiService.post(
      ApiEndpoints.verifyOtp,
      body: {
        'email': email,
        'otp': otpCode,
        'device_id': deviceId,
      },
      requiresAuth: false,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    
    await _apiService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': UserModel.fromJson(data['user']),
    };
  }
  
  /// Refresh les tokens (rotation)
  Future<Map<String, dynamic>> refreshTokens() async {
    final refreshToken = await _apiService.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('Pas de refresh token');
    }
    
    final deviceId = await _apiService.getDeviceId();
    
    final response = await _apiService.post(
      ApiEndpoints.refreshToken,
      body: {
        'refresh_token': refreshToken,
        'device_id': deviceId,
      },
      requiresAuth: false,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    
    final newAccessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String;
    
    // Sauvegarder les nouveaux tokens
    await _apiService.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
    
    return {
      'access_token': newAccessToken,
      'refresh_token': newRefreshToken,
    };
  }
  
  /// Récupère le profil utilisateur (vérification de session)
  Future<UserModel> getMe() async {
    final response = await _apiService.get(
      ApiEndpoints.me,
      requiresAuth: true,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user']);
  }
  
  /// Déconnecte l'utilisateur (révoque le refresh token)
  Future<void> logout() async {
    try {
      final refreshToken = await _apiService.getRefreshToken();
      
      if (refreshToken != null) {
        await _apiService.post(
          ApiEndpoints.logout,
          body: {'refresh_token': refreshToken},
          requiresAuth: false,
        );
      }
    } catch (_) {
      // Ignorer les erreurs de logout serveur
    } finally {
      await _apiService.clearTokens();
    }
  }
  
  /// Vérifie si l'utilisateur est connecté (token présent)
  Future<bool> isAuthenticated() async {
    return await _apiService.hasTokens();
  }
  
  /// Récupère le profil utilisateur (legacy)
  Future<UserModel> getProfile() async {
    return getMe();
  }
  
  /// Restaure la session au démarrage de l'app
  /// 
  /// Retourne:
  /// - `UserModel` si la session est valide (après refresh si nécessaire)
  /// - `null` si pas de session ou session expirée
  Future<UserModel?> restoreSession() async {
    final hasTokens = await _apiService.hasTokens();
    if (!hasTokens) return null;
    
    try {
      // Tenter de récupérer le profil (vérifie le token)
      return await getMe();
    } catch (e) {
      // Token invalide, tenter un refresh
      try {
        await refreshTokens();
        return await getMe();
      } catch (_) {
        // Refresh échoué, session expirée
        await _apiService.clearTokens();
        return null;
      }
    }
  }
  
  // ========================================
  // Auth Settings — Préférences OTP
  // ========================================
  
  /// Récupère les préférences d'authentification
  Future<Map<String, dynamic>> getAuthSettings() async {
    final response = await _apiService.get(
      ApiEndpoints.authSettings,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }
  
  /// Met à jour les préférences OTP
  Future<Map<String, dynamic>> updateAuthSettings({
    required bool otpRequiredOnLogin,
  }) async {
    final response = await _apiService.put(
      ApiEndpoints.authSettings,
      body: {'otp_required_on_login': otpRequiredOnLogin},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }
}

// ============================================================
// Fichier: profile_repository.dart
// Description: Repository profil utilisateur (stats, achievements, avatar)
// ============================================================

import 'dart:io';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant le profil utilisateur étendu
class ProfileRepository {
  final ApiService _apiService;

  ProfileRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Met à jour le profil (username, name)
  Future<UserModel> updateProfile({
    String? username,
    String? name,
  }) async {
    final body = <String, dynamic>{};
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (name != null && name.isNotEmpty) body['name'] = name;

    final response = await _apiService.put(
      ApiEndpoints.profileUpdate,
      body: body,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    return UserModel.fromJson(data['user'] as Map<String, dynamic>? ?? {});
  }

  /// Récupère les statistiques du profil
  Future<UserProfile> getStats() async {
    final response = await _apiService.get(
      ApiEndpoints.profileStats,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    return UserProfile.fromJson({
      'id': '',
      'phone': '',
      'balance': 0,
      'is_active': true,
      'is_verified': true,
      'created_at': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  /// Récupère les achievements avec statut unlock
  Future<List<Achievement>> getAchievements() async {
    final response = await _apiService.get(
      ApiEndpoints.achievements,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final list = data['achievements'] as List;
    return list
        .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Upload un avatar personnel (photo)
  Future<String> uploadAvatar(File imageFile) async {
    final response = await _apiService.uploadMultipart(
      ApiEndpoints.avatarUpload,
      fieldName: 'avatar',
      filePath: imageFile.path,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['avatar_url'] as String;
  }

  /// Récupère les sessions actives
  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await _apiService.get(
      ApiEndpoints.sessions,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    return (data['sessions'] as List)
        .map((s) => s as Map<String, dynamic>)
        .toList();
  }

  /// Révoque une session
  Future<void> revokeSession(String sessionId) async {
    await _apiService.delete(
      '${ApiEndpoints.sessions}/$sessionId',
      requiresAuth: true,
    );
  }

  /// Change le mot de passe
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _apiService.post(
      ApiEndpoints.changePassword,
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
      requiresAuth: true,
    );
  }
}

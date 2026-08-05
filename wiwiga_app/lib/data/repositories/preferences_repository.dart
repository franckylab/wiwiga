// ============================================================
// Fichier: preferences_repository.dart
// Description: Repository préférences utilisateur
// ============================================================

import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant les préférences utilisateur
class PreferencesRepository {
  final ApiService _apiService;

  PreferencesRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Récupère les préférences depuis le serveur
  Future<Map<String, dynamic>> getPreferences() async {
    final response = await _apiService.get(
      ApiEndpoints.preferences,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Met à jour les préférences (partial update)
  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> prefs,
  ) async {
    final response = await _apiService.put(
      ApiEndpoints.preferences,
      body: prefs,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }
}

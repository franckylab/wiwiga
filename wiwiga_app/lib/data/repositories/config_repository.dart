import '../services/api_service.dart';
import '../../presentation/providers/config_provider.dart';

/// Repository pour la gestion de la configuration dynamique
class ConfigRepository {
  final ApiService _apiService;

  ConfigRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Récupère la configuration du thème
  Future<ThemeConfigModel> getThemeConfig() async {
    try {
      final response = await _apiService.get(
        '/api/admin/config/theme',
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return ThemeConfigModel.fromJson(response['data']['theme_config']);
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la récupération du thème');
      }
    } catch (e) {
      // Retourne config par défaut en cas d'erreur (offline mode)
      return _getDefaultThemeConfig();
    }
  }

  /// Met à jour la configuration du thème
  Future<ThemeConfigModel> updateThemeConfig(Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put(
        '/api/admin/config/theme',
        body: {'theme_config': updates},
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return ThemeConfigModel.fromJson(response['data']['theme_config']);
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la mise à jour du thème');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Récupère la configuration des features
  Future<FeatureConfigModel> getFeatureConfig() async {
    try {
      final response = await _apiService.get(
        '/api/admin/config/features',
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return FeatureConfigModel.fromJson(response['data']['feature_config']);
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la récupération des features');
      }
    } catch (e) {
      // Retourne config par défaut en cas d'erreur (offline mode)
      return _getDefaultFeatureConfig();
    }
  }

  /// Met à jour la configuration des features
  Future<FeatureConfigModel> updateFeatureConfig(Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put(
        '/api/admin/config/features',
        body: {'feature_config': updates},
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return FeatureConfigModel.fromJson(response['data']['feature_config']);
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la mise à jour des features');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Récupère la configuration d'un jeu
  Future<Map<String, dynamic>> getGameConfig(String gameType) async {
    try {
      final response = await _apiService.get(
        '/api/admin/config/games/$gameType',
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return response['data']['game_config'];
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la récupération de la config jeu');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Met à jour la configuration d'un jeu
  Future<Map<String, dynamic>> updateGameConfig(
    String gameType,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiService.put(
        '/api/admin/config/games/$gameType',
        body: {'game_config': updates},
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return response['data']['game_config'];
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la mise à jour de la config jeu');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Récupère la liste des providers de paiement
  Future<List<Map<String, dynamic>>> getPaymentConfigs() async {
    try {
      final response = await _apiService.get(
        '/api/admin/config/payments',
        requiresAuth: true,
      );

      if (response['success'] == true) {
        final List<dynamic> configs = response['data']['payment_configs'];
        return configs.cast<Map<String, dynamic>>();
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de la récupération des paiements');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Configuration thème par défaut (fallback offline)
  ThemeConfigModel _getDefaultThemeConfig() {
    return ThemeConfigModel(
      primaryColor: '#2DD4BF',
      secondaryColor: '#F59E0B',
      accentColor: '#00D9FF',
      backgroundColor: '#1E293B',
      surfaceColor: '#0F172A',
      borderRadius: 12.0,
      glowIntensity: 0.5,
      animationDuration: 200,
      fontFamilyBody: 'Inter',
      fontFamilyDisplay: 'Orbitron',
    );
  }

  /// Configuration features par défaut (fallback offline)
  FeatureConfigModel _getDefaultFeatureConfig() {
    return FeatureConfigModel(
      maintenanceMode: false,
      maintenanceMessage: 'WIWIGA est en maintenance',
      registrationEnabled: true,
      minDepositAmount: 500,
      maxDepositAmount: 1000000,
      minWithdrawalAmount: 1000,
      maxWithdrawalAmount: 5000000,
      kycRequiredThreshold: 100000,
      maxGamesPerUser: 10,
      websocketTimeoutMs: 30000,
      sessionTimeoutMs: 1800000,
      realityCheckIntervalMs: 1800000,
      selfExclusionOptions: [24, 168, 720],
      supportEmail: 'support@wiwiga.cm',
      supportPhone: '+237 600 000 000',
      termsUrl: 'https://wiwiga.cm/terms',
      privacyUrl: 'https://wiwiga.cm/privacy',
    );
  }
}

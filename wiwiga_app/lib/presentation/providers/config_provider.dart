import 'package:flutter_riverpod/flutter_riverpod.dart';

// ========================================
// Modèles de Configuration
// ========================================

/// Configuration du thème UI
class ThemeConfigModel {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String backgroundColor;
  final String surfaceColor;
  final double borderRadius;
  final double glowIntensity;
  final int animationDuration;
  final String fontFamilyBody;
  final String fontFamilyDisplay;
  final String? logoUrl;
  final String? faviconUrl;

  ThemeConfigModel({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.borderRadius,
    required this.glowIntensity,
    required this.animationDuration,
    required this.fontFamilyBody,
    required this.fontFamilyDisplay,
    this.logoUrl,
    this.faviconUrl,
  });

  factory ThemeConfigModel.fromJson(Map<String, dynamic> json) {
    return ThemeConfigModel(
      primaryColor: json['primary_color'] ?? '#2DD4BF',
      secondaryColor: json['secondary_color'] ?? '#F59E0B',
      accentColor: json['accent_color'] ?? '#00D9FF',
      backgroundColor: json['background_color'] ?? '#1E293B',
      surfaceColor: json['surface_color'] ?? '#0F172A',
      borderRadius: (json['border_radius'] ?? 12.0).toDouble(),
      glowIntensity: (json['glow_intensity'] ?? 0.5).toDouble(),
      animationDuration: json['animation_duration'] ?? 200,
      fontFamilyBody: json['font_family_body'] ?? 'Inter',
      fontFamilyDisplay: json['font_family_display'] ?? 'Orbitron',
      logoUrl: json['logo_url'],
      faviconUrl: json['favicon_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'accent_color': accentColor,
      'background_color': backgroundColor,
      'surface_color': surfaceColor,
      'border_radius': borderRadius,
      'glow_intensity': glowIntensity,
      'animation_duration': animationDuration,
      'font_family_body': fontFamilyBody,
      'font_family_display': fontFamilyDisplay,
      'logo_url': logoUrl,
      'favicon_url': faviconUrl,
    };
  }
}

/// Configuration des features
class FeatureConfigModel {
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool registrationEnabled;
  final int minDepositAmount;
  final int maxDepositAmount;
  final int minWithdrawalAmount;
  final int maxWithdrawalAmount;
  final int kycRequiredThreshold;
  final int maxGamesPerUser;
  final int websocketTimeoutMs;
  final int sessionTimeoutMs;
  final int realityCheckIntervalMs;
  final List<int> selfExclusionOptions;
  final String supportEmail;
  final String supportPhone;
  final String termsUrl;
  final String privacyUrl;

  FeatureConfigModel({
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.registrationEnabled,
    required this.minDepositAmount,
    required this.maxDepositAmount,
    required this.minWithdrawalAmount,
    required this.maxWithdrawalAmount,
    required this.kycRequiredThreshold,
    required this.maxGamesPerUser,
    required this.websocketTimeoutMs,
    required this.sessionTimeoutMs,
    required this.realityCheckIntervalMs,
    required this.selfExclusionOptions,
    required this.supportEmail,
    required this.supportPhone,
    required this.termsUrl,
    required this.privacyUrl,
  });

  factory FeatureConfigModel.fromJson(Map<String, dynamic> json) {
    return FeatureConfigModel(
      maintenanceMode: json['maintenance_mode'] ?? false,
      maintenanceMessage: json['maintenance_message'] ?? 'WIWIGA est en maintenance',
      registrationEnabled: json['registration_enabled'] ?? true,
      minDepositAmount: json['min_deposit_amount'] ?? 500,
      maxDepositAmount: json['max_deposit_amount'] ?? 1000000,
      minWithdrawalAmount: json['min_withdrawal_amount'] ?? 1000,
      maxWithdrawalAmount: json['max_withdrawal_amount'] ?? 5000000,
      kycRequiredThreshold: json['kyc_required_threshold'] ?? 100000,
      maxGamesPerUser: json['max_games_per_user'] ?? 10,
      websocketTimeoutMs: json['websocket_timeout_ms'] ?? 30000,
      sessionTimeoutMs: json['session_timeout_ms'] ?? 1800000,
      realityCheckIntervalMs: json['reality_check_interval_ms'] ?? 1800000,
      selfExclusionOptions: List<int>.from(json['self_exclusion_options'] ?? [24, 168, 720]),
      supportEmail: json['support_email'] ?? 'support@wiwiga.cm',
      supportPhone: json['support_phone'] ?? '+237 600 000 000',
      termsUrl: json['terms_url'] ?? 'https://wiwiga.cm/terms',
      privacyUrl: json['privacy_url'] ?? 'https://wiwiga.cm/privacy',
    );
  }

  bool get isMaintenanceActive => maintenanceMode;
  bool get isRegistrationOpen => !maintenanceMode && registrationEnabled;
}


// ========================================
// Providers Riverpod
// ========================================

/// Provider pour la configuration du thème
final themeConfigProvider = StateNotifierProvider<ThemeConfigNotifier, AsyncValue<ThemeConfigModel>>((ref) {
  return ThemeConfigNotifier();
});

class ThemeConfigNotifier extends StateNotifier<AsyncValue<ThemeConfigModel>> {
  ThemeConfigNotifier() : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // TODO: Implémenter appel API GET /api/admin/config/theme
    // Pour l'instant, on utilise des valeurs par défaut
    state = const AsyncValue.loading();
    
    try {
      // Simuler chargement
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Valeurs par défaut (néon gaming)
      final config = ThemeConfigModel(
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
      
      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateConfig(Map<String, dynamic> updates) async {
    // TODO: Implémenter appel API PUT /api/admin/config/theme
    // Broadcast WebSocket mettra à jour automatiquement
    await _loadConfig();
  }

  /// Écouter les updates WebSocket
  void onWebSocketUpdate(Map<String, dynamic> newData) {
    state = AsyncValue.data(ThemeConfigModel.fromJson(newData));
  }
}


/// Provider pour la configuration des features
final featureConfigProvider = StateNotifierProvider<FeatureConfigNotifier, AsyncValue<FeatureConfigModel>>((ref) {
  return FeatureConfigNotifier();
});

class FeatureConfigNotifier extends StateNotifier<AsyncValue<FeatureConfigModel>> {
  FeatureConfigNotifier() : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // TODO: Implémenter appel API GET /api/admin/config/features
    state = const AsyncValue.loading();
    
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      final config = FeatureConfigModel(
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
      
      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateConfig(Map<String, dynamic> updates) async {
    // TODO: Implémenter appel API PUT /api/admin/config/features
    await _loadConfig();
  }

  /// Écouter les updates WebSocket
  void onWebSocketUpdate(Map<String, dynamic> newData) {
    state = AsyncValue.data(FeatureConfigModel.fromJson(newData));
  }
}


/// Provider utilitaire pour vérifier si l'app est en maintenance
final isMaintenanceActiveProvider = Provider<bool>((ref) {
  final featureConfig = ref.watch(featureConfigProvider);
  return featureConfig.when(
    data: (config) => config.isMaintenanceActive,
    loading: () => false,
    error: (_, __) => false,
  );
});


/// Provider utilitaire pour vérifier si les inscriptions sont ouvertes
final isRegistrationOpenProvider = Provider<bool>((ref) {
  final featureConfig = ref.watch(featureConfigProvider);
  return featureConfig.when(
    data: (config) => config.isRegistrationOpen,
    loading: () => true,
    error: (_, __) => true,
  );
});

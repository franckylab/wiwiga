import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/app_providers.dart';
import '../../core/constants/api_constants.dart';

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
// Modèles de Configuration (Games, Payments, Tokens)
// ========================================

/// Configuration d'un type de jeu
class GameTypeConfigModel {
  final String type;
  final int minBet;
  final int maxBet;
  final double commissionPercent;
  final String commissionMode;
  final int timeoutSeconds;
  final int maxPlayers;
  final bool isActive;

  GameTypeConfigModel({
    required this.type,
    required this.minBet,
    required this.maxBet,
    required this.commissionPercent,
    required this.commissionMode,
    required this.timeoutSeconds,
    required this.maxPlayers,
    required this.isActive,
  });

  factory GameTypeConfigModel.fromJson(String type, Map<String, dynamic> json) {
    return GameTypeConfigModel(
      type: type,
      minBet: json['min_bet'] ?? 100,
      maxBet: json['max_bet'] ?? 50000,
      commissionPercent: (json['commission_percent'] ?? 5.0).toDouble(),
      commissionMode: json['commission_mode'] ?? 'percentage',
      timeoutSeconds: json['timeout_seconds'] ?? 120,
      maxPlayers: json['max_players'] ?? 4,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'min_bet': minBet,
    'max_bet': maxBet,
    'commission_percent': commissionPercent,
    'commission_mode': commissionMode,
    'timeout_seconds': timeoutSeconds,
    'max_players': maxPlayers,
    'is_active': isActive,
  };
}

/// Configuration des jeux
class GamesConfigModel {
  final Map<String, GameTypeConfigModel> gameTypes;
  final int matchmakingCreateTimeout;
  final int matchmakingJoinTimeout;
  final int turnTimeout;
  final int inactivityTimeout;

  GamesConfigModel({
    required this.gameTypes,
    required this.matchmakingCreateTimeout,
    required this.matchmakingJoinTimeout,
    required this.turnTimeout,
    required this.inactivityTimeout,
  });

  factory GamesConfigModel.fromJson(Map<String, dynamic> json) {
    final types = <String, GameTypeConfigModel>{};
    final gameConfigs = json['game_types'] as Map<String, dynamic>? ?? {};
    gameConfigs.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        types[key] = GameTypeConfigModel.fromJson(key, value);
      }
    });
    // Fallback: au moins un type "dice"
    if (types.isEmpty) {
      types['dice'] = GameTypeConfigModel(
        type: 'dice', minBet: 100, maxBet: 50000,
        commissionPercent: 5.0, commissionMode: 'percentage',
        timeoutSeconds: 120, maxPlayers: 4, isActive: true,
      );
    }
    return GamesConfigModel(
      gameTypes: types,
      matchmakingCreateTimeout: json['matchmaking_create_timeout'] ?? 60,
      matchmakingJoinTimeout: json['matchmaking_join_timeout'] ?? 30,
      turnTimeout: json['turn_timeout'] ?? 45,
      inactivityTimeout: json['inactivity_timeout'] ?? 300,
    );
  }
}

/// Configuration d'un provider de paiement
class PaymentProviderConfigModel {
  final String provider;
  final bool isEnabled;
  final int depositMin;
  final int depositMax;
  final double withdrawalFeePercent;

  PaymentProviderConfigModel({
    required this.provider,
    required this.isEnabled,
    required this.depositMin,
    required this.depositMax,
    required this.withdrawalFeePercent,
  });

  factory PaymentProviderConfigModel.fromJson(String provider, Map<String, dynamic> json) {
    return PaymentProviderConfigModel(
      provider: provider,
      isEnabled: json['is_enabled'] ?? true,
      depositMin: json['deposit_min'] ?? 100,
      depositMax: json['deposit_max'] ?? 500000,
      withdrawalFeePercent: (json['withdrawal_fee_percent'] ?? 2.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'is_enabled': isEnabled,
    'deposit_min': depositMin,
    'deposit_max': depositMax,
    'withdrawal_fee_percent': withdrawalFeePercent,
  };
}

/// Configuration des paiements
class PaymentsConfigModel {
  final Map<String, PaymentProviderConfigModel> providers;

  PaymentsConfigModel({required this.providers});

  factory PaymentsConfigModel.fromJson(Map<String, dynamic> json) {
    final providers = <String, PaymentProviderConfigModel>{};
    final providerConfigs = json['providers'] as Map<String, dynamic>? ?? {};
    providerConfigs.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        providers[key] = PaymentProviderConfigModel.fromJson(key, value);
      }
    });
    // Fallback providers
    if (providers.isEmpty) {
      providers['campay'] = PaymentProviderConfigModel(
        provider: 'campay', isEnabled: true,
        depositMin: 100, depositMax: 500000, withdrawalFeePercent: 2.0,
      );
      providers['mtn_momo'] = PaymentProviderConfigModel(
        provider: 'mtn_momo', isEnabled: true,
        depositMin: 100, depositMax: 1000000, withdrawalFeePercent: 1.5,
      );
      providers['orange_money'] = PaymentProviderConfigModel(
        provider: 'orange_money', isEnabled: false,
        depositMin: 100, depositMax: 500000, withdrawalFeePercent: 2.0,
      );
    }
    return PaymentsConfigModel(providers: providers);
  }
}

/// Configuration des tokens (taux wiga/FCFA, 1.0 = 1:1 par défaut)
class TokensConfigModel {
  final double exchangeRate;
  final double exchangeFeePercent;
  final int exchangeFixedFee;
  final int dailyPurchaseLimit;
  final int dailyTransferLimit;
  final double giftFeePercent;
  final int diceMinBet;
  final int cardsMinBet;

  TokensConfigModel({
    required this.exchangeRate,
    required this.exchangeFeePercent,
    required this.exchangeFixedFee,
    required this.dailyPurchaseLimit,
    required this.dailyTransferLimit,
    required this.giftFeePercent,
    required this.diceMinBet,
    required this.cardsMinBet,
  });

  factory TokensConfigModel.fromJson(Map<String, dynamic> json) {
    return TokensConfigModel(
      exchangeRate: (json['exchange_rate'] ?? 1.0).toDouble(),
      exchangeFeePercent: (json['exchange_fee_percent'] ?? 2.0).toDouble(),
      exchangeFixedFee: json['exchange_fixed_fee'] ?? 0,
      dailyPurchaseLimit: json['daily_purchase_limit'] ?? 50000,
      dailyTransferLimit: json['daily_transfer_limit'] ?? 10000,
      giftFeePercent: (json['gift_fee_percent'] ?? 5.0).toDouble(),
      diceMinBet: json['dice_min_bet'] ?? 10,
      cardsMinBet: json['cards_min_bet'] ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
    'exchange_rate': exchangeRate,
    'exchange_fee_percent': exchangeFeePercent,
    'exchange_fixed_fee': exchangeFixedFee,
    'daily_purchase_limit': dailyPurchaseLimit,
    'daily_transfer_limit': dailyTransferLimit,
    'gift_fee_percent': giftFeePercent,
    'dice_min_bet': diceMinBet,
    'cards_min_bet': cardsMinBet,
  };
}


// ========================================
// Providers Riverpod
// ========================================

/// Provider pour la configuration du thème
final themeConfigProvider = StateNotifierProvider<ThemeConfigNotifier, AsyncValue<ThemeConfigModel>>((ref) {
  return ThemeConfigNotifier(ref);
});

class ThemeConfigNotifier extends StateNotifier<AsyncValue<ThemeConfigModel>> {
  final Ref _ref;
  
  ThemeConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    state = const AsyncValue.loading();
    
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.adminConfigTheme,
        requiresAuth: true,
      );
      
      final data = response['data']?['theme_config'] as Map<String, dynamic>? ?? {};
      final config = ThemeConfigModel.fromJson(data);
      state = AsyncValue.data(config);
    } catch (e) {
      // Fallback sur les valeurs par défaut si l'API échoue
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
    }
  }

  Future<void> updateConfig(Map<String, dynamic> updates) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.adminConfigTheme,
        body: {'theme_config': updates},
        requiresAuth: true,
      );
      await _loadConfig();
    } catch (e) {
      // Recharger la config actuelle en cas d'erreur
      await _loadConfig();
    }
  }

  /// Écouter les updates WebSocket
  void onWebSocketUpdate(Map<String, dynamic> newData) {
    state = AsyncValue.data(ThemeConfigModel.fromJson(newData));
  }
}


/// Provider pour la configuration des features
final featureConfigProvider = StateNotifierProvider<FeatureConfigNotifier, AsyncValue<FeatureConfigModel>>((ref) {
  return FeatureConfigNotifier(ref);
});

class FeatureConfigNotifier extends StateNotifier<AsyncValue<FeatureConfigModel>> {
  final Ref _ref;
  
  FeatureConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    state = const AsyncValue.loading();
    
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.adminConfigFeatures,
        requiresAuth: true,
      );
      
      final data = response['data']?['feature_config'] as Map<String, dynamic>? ?? {};
      final config = FeatureConfigModel.fromJson(data);
      state = AsyncValue.data(config);
    } catch (e) {
      // Fallback sur les valeurs par défaut si l'API échoue
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
    }
  }

  Future<void> updateConfig(Map<String, dynamic> updates) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.adminConfigFeatures,
        body: {'feature_config': updates},
        requiresAuth: true,
      );
      await _loadConfig();
    } catch (e) {
      await _loadConfig();
    }
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


// ========================================
// Providers Games / Payments / Tokens
// ========================================

/// Provider pour la configuration des jeux
final gamesConfigProvider = StateNotifierProvider<GamesConfigNotifier, AsyncValue<GamesConfigModel>>((ref) {
  return GamesConfigNotifier(ref);
});

class GamesConfigNotifier extends StateNotifier<AsyncValue<GamesConfigModel>> {
  final Ref _ref;

  GamesConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    state = const AsyncValue.loading();
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.adminConfigGames,
        requiresAuth: true,
      );
      final data = response['data']?['game_config'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? {};
      state = AsyncValue.data(GamesConfigModel.fromJson(data));
    } catch (e) {
      state = AsyncValue.data(GamesConfigModel.fromJson({}));
    }
  }

  Future<void> updateGameType(String gameType, Map<String, dynamic> updates) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.adminConfigGames,
        body: {'type': gameType, 'game_config': updates},
        requiresAuth: true,
      );
      await _loadConfig();
    } catch (e) {
      await _loadConfig();
    }
  }
}

/// Provider pour la configuration des paiements
final paymentsConfigProvider = StateNotifierProvider<PaymentsConfigNotifier, AsyncValue<PaymentsConfigModel>>((ref) {
  return PaymentsConfigNotifier(ref);
});

class PaymentsConfigNotifier extends StateNotifier<AsyncValue<PaymentsConfigModel>> {
  final Ref _ref;

  PaymentsConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    state = const AsyncValue.loading();
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.adminConfigPayments,
        requiresAuth: true,
      );
      final data = response['data']?['payment_config'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? {};
      state = AsyncValue.data(PaymentsConfigModel.fromJson(data));
    } catch (e) {
      state = AsyncValue.data(PaymentsConfigModel.fromJson({}));
    }
  }

  Future<void> updateProvider(String provider, Map<String, dynamic> updates) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.adminConfigPayments,
        body: {'provider': provider, 'payment_config': updates},
        requiresAuth: true,
      );
      await _loadConfig();
    } catch (e) {
      await _loadConfig();
    }
  }
}

/// Provider pour la configuration des tokens
final tokensConfigProvider = StateNotifierProvider<TokensConfigNotifier, AsyncValue<TokensConfigModel>>((ref) {
  return TokensConfigNotifier(ref);
});

class TokensConfigNotifier extends StateNotifier<AsyncValue<TokensConfigModel>> {
  final Ref _ref;

  TokensConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    state = const AsyncValue.loading();
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.adminConfigTokens,
        requiresAuth: true,
      );
      final data = response['data']?['token_config'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? {};
      state = AsyncValue.data(TokensConfigModel.fromJson(data));
    } catch (e) {
      state = AsyncValue.data(TokensConfigModel.fromJson({}));
    }
  }

  Future<void> updateConfig(Map<String, dynamic> updates) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.adminConfigTokens,
        body: {'token_config': updates},
        requiresAuth: true,
      );
      await _loadConfig();
    } catch (e) {
      await _loadConfig();
    }
  }
}

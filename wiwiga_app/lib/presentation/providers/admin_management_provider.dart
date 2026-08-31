// ============================================================
// Fichier: admin_management_provider.dart
// Description: Providers Riverpod pour game config, bonuses, reports (V3)
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/error_handler.dart';
import '../../data/providers/app_providers.dart';

// ========================================
// ÉTATS
// ========================================

/// État game config
class AdminGameConfigState {
  final bool isLoading;
  final String? error;
  final List<dynamic> configs;
  final bool isSaving;

  const AdminGameConfigState({
    this.isLoading = false,
    this.error,
    this.configs = const [],
    this.isSaving = false,
  });

  AdminGameConfigState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? configs,
    bool? isSaving,
    bool clearError = false,
  }) {
    return AdminGameConfigState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      configs: configs ?? this.configs,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// État bonuses
class AdminBonusesState {
  final bool isLoading;
  final String? error;
  final List<dynamic> bonuses;
  final bool isSaving;

  const AdminBonusesState({
    this.isLoading = false,
    this.error,
    this.bonuses = const [],
    this.isSaving = false,
  });

  AdminBonusesState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? bonuses,
    bool? isSaving,
    bool clearError = false,
  }) {
    return AdminBonusesState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      bonuses: bonuses ?? this.bonuses,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// État reports
class AdminReportsState {
  final bool isLoading;
  final String? error;
  final List<dynamic> reports;
  final bool isGenerating;

  const AdminReportsState({
    this.isLoading = false,
    this.error,
    this.reports = const [],
    this.isGenerating = false,
  });

  AdminReportsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? reports,
    bool? isGenerating,
    bool clearError = false,
  }) {
    return AdminReportsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      reports: reports ?? this.reports,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

// ========================================
// STATE NOTIFIERS
// ========================================

/// StateNotifier pour Game Config
class AdminGameConfigNotifier extends StateNotifier<AdminGameConfigState> {
  final Ref _ref;

  AdminGameConfigNotifier(this._ref) : super(const AdminGameConfigState());

  Future<void> loadConfigs() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final configs = await repo.getGameConfigs();
      state = state.copyWith(isLoading: false, configs: configs);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminGameConfigNotifier.loadConfigs');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<bool> updateConfig(String gameType, Map<String, dynamic> config) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.updateGameConfig(gameType, config);
      await loadConfigs();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminGameConfigNotifier.updateConfig');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  Future<bool> createConfig(Map<String, dynamic> config) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.createGameConfig(config);
      await loadConfigs();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.createConfig');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

/// StateNotifier pour Bonuses
class AdminBonusesNotifier extends StateNotifier<AdminBonusesState> {
  final Ref _ref;

  AdminBonusesNotifier(this._ref) : super(const AdminBonusesState());

  Future<void> loadBonuses({String? type, bool? isActive}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final bonuses = await repo.getBonuses(type: type, isActive: isActive);
      state = state.copyWith(isLoading: false, bonuses: bonuses);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminBonusesNotifier.loadBonuses');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<bool> createBonus(Map<String, dynamic> bonus) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.createBonus(bonus);
      await loadBonuses();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminBonusesNotifier.createBonus');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  Future<bool> updateBonus(String bonusId, Map<String, dynamic> bonus) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.updateBonus(bonusId, bonus);
      await loadBonuses();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.updateBonus');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  Future<bool> toggleBonus(String bonusId, bool isActive) async {
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.toggleBonus(bonusId, isActive);
      await loadBonuses();
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.toggleBonus');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

/// StateNotifier pour Reports
class AdminReportsNotifier extends StateNotifier<AdminReportsState> {
  final Ref _ref;

  AdminReportsNotifier(this._ref) : super(const AdminReportsState());

  Future<void> loadReports() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final reports = await repo.getReports();
      state = state.copyWith(isLoading: false, reports: reports);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminReportsNotifier.loadReports');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<bool> generateReport({required String type, String? name, Map<String, dynamic>? parameters}) async {
    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.generateReport(type: type, name: name, parameters: parameters);
      await loadReports();
      state = state.copyWith(isGenerating: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminReportsNotifier.generateReport');
      state = state.copyWith(isGenerating: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

// ========================================
// PROVIDERS
// ========================================

final adminGameConfigManagementProvider = StateNotifierProvider<AdminGameConfigNotifier, AdminGameConfigState>((ref) {
  return AdminGameConfigNotifier(ref);
});

final adminBonusesManagementProvider = StateNotifierProvider<AdminBonusesNotifier, AdminBonusesState>((ref) {
  return AdminBonusesNotifier(ref);
});

final adminReportsManagementProvider = StateNotifierProvider<AdminReportsNotifier, AdminReportsState>((ref) {
  return AdminReportsNotifier(ref);
});

// ========================================
// PLATFORM CONFIG
// ========================================

class AdminPlatformConfigState {
  final bool isLoading;
  final String? error;
  final Map<String, List<dynamic>> configs;
  final List<String> categories;
  final String? selectedCategory;
  final bool isSaving;

  const AdminPlatformConfigState({
    this.isLoading = false,
    this.error,
    this.configs = const {},
    this.categories = const [],
    this.selectedCategory,
    this.isSaving = false,
  });

  AdminPlatformConfigState copyWith({
    bool? isLoading, String? error, Map<String, List<dynamic>>? configs,
    List<String>? categories, String? selectedCategory, bool? isSaving, bool clearError = false,
  }) {
    return AdminPlatformConfigState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      configs: configs ?? this.configs,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class AdminPlatformConfigNotifier extends StateNotifier<AdminPlatformConfigState> {
  final Ref ref;
  AdminPlatformConfigNotifier(this.ref) : super(const AdminPlatformConfigState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final response = await adminRepo.getPlatformConfig();
      final data = Map<String, List<dynamic>>.from(response['data'] as Map);
      final cats = List<String>.from(response['categories'] as List);
      state = state.copyWith(isLoading: false, configs: data, categories: cats);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminPlatformConfigNotifier.loadAll');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> loadCategory(String category) async {
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final configs = await adminRepo.getPlatformConfigByCategory(category);
      final updated = Map<String, List<dynamic>>.from(state.configs);
      updated[category] = configs;
      state = state.copyWith(configs: updated, selectedCategory: category);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminPlatformConfigNotifier.loadCategory');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  Future<bool> updateConfig(String category, String key, String value) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.updatePlatformConfig(category, key, value);
      await loadCategory(category);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.updateConfig');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

final adminPlatformConfigProvider = StateNotifierProvider<AdminPlatformConfigNotifier, AdminPlatformConfigState>((ref) {
  return AdminPlatformConfigNotifier(ref);
});

// ========================================
// PLAYER PROGRESSION
// ========================================

class AdminPlayerProgressionState {
  final bool isLoading;
  final String? error;
  final List<dynamic> levels;
  final bool isSaving;

  const AdminPlayerProgressionState({
    this.isLoading = false, this.error, this.levels = const [], this.isSaving = false,
  });

  AdminPlayerProgressionState copyWith({
    bool? isLoading, String? error, List<dynamic>? levels, bool? isSaving, bool clearError = false,
  }) {
    return AdminPlayerProgressionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      levels: levels ?? this.levels,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class AdminPlayerProgressionNotifier extends StateNotifier<AdminPlayerProgressionState> {
  final Ref ref;
  AdminPlayerProgressionNotifier(this.ref) : super(const AdminPlayerProgressionState());

  Future<void> loadLevels() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final levels = await adminRepo.getPlayerProgressionLevels();
      state = state.copyWith(isLoading: false, levels: levels);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminPlayerProgressionNotifier.loadLevels');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<bool> updateLevel(String tier, Map<String, dynamic> config) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.updatePlayerLevel(tier, config);
      await loadLevels();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminPlayerProgressionNotifier.updateLevel');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  Future<bool> createLevel(Map<String, dynamic> config) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.createPlayerLevel(config);
      await loadLevels();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.createLevel');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  Future<bool> deleteLevel(String tier) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.deletePlayerLevel(tier);
      await loadLevels();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.deleteLevel');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

final adminPlayerProgressionProvider = StateNotifierProvider<AdminPlayerProgressionNotifier, AdminPlayerProgressionState>((ref) {
  return AdminPlayerProgressionNotifier(ref);
});

// ========================================
// XP RULES
// ========================================

class AdminXPRulesState {
  final bool isLoading;
  final String? error;
  final List<dynamic> rules;
  final bool isSaving;

  const AdminXPRulesState({
    this.isLoading = false, this.error, this.rules = const [], this.isSaving = false,
  });

  AdminXPRulesState copyWith({
    bool? isLoading, String? error, List<dynamic>? rules, bool? isSaving, bool clearError = false,
  }) {
    return AdminXPRulesState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      rules: rules ?? this.rules,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class AdminXPRulesNotifier extends StateNotifier<AdminXPRulesState> {
  final Ref ref;
  AdminXPRulesNotifier(this.ref) : super(const AdminXPRulesState());

  Future<void> loadRules() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final rules = await adminRepo.getXPRules();
      state = state.copyWith(isLoading: false, rules: rules);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminXPRulesNotifier.loadRules');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<bool> saveRules(String gameType, Map<String, dynamic> rules) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.upsertXPRules(gameType, rules);
      await loadRules();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminXPRulesNotifier.saveRules');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  Future<bool> deleteRules(String gameType) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.deleteXPRules(gameType);
      await loadRules();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Admin.deleteRules');
      state = state.copyWith(isSaving: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

final adminXPRulesProvider = StateNotifierProvider<AdminXPRulesNotifier, AdminXPRulesState>((ref) {
  return AdminXPRulesNotifier(ref);
});
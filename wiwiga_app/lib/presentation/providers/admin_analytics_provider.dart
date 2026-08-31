// ============================================================
// Fichier: admin_analytics_provider.dart
// Description: Providers Riverpod pour les analytics KPI gaming (V3)
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/error_handler.dart';
import '../../data/providers/app_providers.dart';

// ========================================
// ÉTATS
// ========================================

/// État des analytics revenue
class AdminRevenueAnalyticsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final String selectedPeriod;

  const AdminRevenueAnalyticsState({
    this.isLoading = false,
    this.error,
    this.data,
    this.selectedPeriod = '30d',
  });

  AdminRevenueAnalyticsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    String? selectedPeriod,
    bool clearError = false,
  }) {
    return AdminRevenueAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }
}

/// État des analytics joueurs
class AdminPlayerAnalyticsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final String selectedPeriod;

  const AdminPlayerAnalyticsState({
    this.isLoading = false,
    this.error,
    this.data,
    this.selectedPeriod = '30d',
  });

  AdminPlayerAnalyticsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    String? selectedPeriod,
    bool clearError = false,
  }) {
    return AdminPlayerAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }
}

/// État des analytics jeux
class AdminGameAnalyticsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final String selectedPeriod;

  const AdminGameAnalyticsState({
    this.isLoading = false,
    this.error,
    this.data,
    this.selectedPeriod = '30d',
  });

  AdminGameAnalyticsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    String? selectedPeriod,
    bool clearError = false,
  }) {
    return AdminGameAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }
}

/// État du flux monétaire
class AdminMonetaryFlowState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final String selectedPeriod;

  const AdminMonetaryFlowState({
    this.isLoading = false,
    this.error,
    this.data,
    this.selectedPeriod = '30d',
  });

  AdminMonetaryFlowState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    String? selectedPeriod,
    bool clearError = false,
  }) {
    return AdminMonetaryFlowState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }
}

/// État de la distribution richesse
class AdminWealthState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;

  const AdminWealthState({
    this.isLoading = false,
    this.error,
    this.data,
  });

  AdminWealthState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    bool clearError = false,
  }) {
    return AdminWealthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
    );
  }
}

// ========================================
// STATE NOTIFIERS
// ========================================

/// StateNotifier pour les analytics revenue
class AdminRevenueAnalyticsNotifier extends StateNotifier<AdminRevenueAnalyticsState> {
  final Ref _ref;

  AdminRevenueAnalyticsNotifier(this._ref) : super(const AdminRevenueAnalyticsState());

  Future<void> load({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getRevenueAnalytics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, data: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminRevenueAnalyticsNotifier.load');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }
}

/// StateNotifier pour les analytics joueurs
class AdminPlayerAnalyticsNotifier extends StateNotifier<AdminPlayerAnalyticsState> {
  final Ref _ref;

  AdminPlayerAnalyticsNotifier(this._ref) : super(const AdminPlayerAnalyticsState());

  Future<void> load({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getPlayerAnalytics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, data: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminPlayerAnalyticsNotifier.load');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }
}

/// StateNotifier pour les analytics jeux
class AdminGameAnalyticsNotifier extends StateNotifier<AdminGameAnalyticsState> {
  final Ref _ref;

  AdminGameAnalyticsNotifier(this._ref) : super(const AdminGameAnalyticsState());

  Future<void> load({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getGameAnalytics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, data: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminGameAnalyticsNotifier.load');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }
}

/// StateNotifier pour le flux monétaire
class AdminMonetaryFlowNotifier extends StateNotifier<AdminMonetaryFlowState> {
  final Ref _ref;

  AdminMonetaryFlowNotifier(this._ref) : super(const AdminMonetaryFlowState());

  Future<void> load({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getMonetaryFlow(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, data: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMonetaryFlowNotifier.load');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }
}

/// StateNotifier pour la distribution richesse
class AdminWealthNotifier extends StateNotifier<AdminWealthState> {
  final Ref _ref;

  AdminWealthNotifier(this._ref) : super(const AdminWealthState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getWealthDistribution();
      state = state.copyWith(isLoading: false, data: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminWealthNotifier.load');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }
}

// ========================================
// PROVIDERS
// ========================================

final adminRevenueAnalyticsProvider = StateNotifierProvider<AdminRevenueAnalyticsNotifier, AdminRevenueAnalyticsState>((ref) {
  return AdminRevenueAnalyticsNotifier(ref);
});

final adminPlayerAnalyticsProvider = StateNotifierProvider<AdminPlayerAnalyticsNotifier, AdminPlayerAnalyticsState>((ref) {
  return AdminPlayerAnalyticsNotifier(ref);
});

final adminGameAnalyticsProvider = StateNotifierProvider<AdminGameAnalyticsNotifier, AdminGameAnalyticsState>((ref) {
  return AdminGameAnalyticsNotifier(ref);
});

final adminMonetaryFlowProvider = StateNotifierProvider<AdminMonetaryFlowNotifier, AdminMonetaryFlowState>((ref) {
  return AdminMonetaryFlowNotifier(ref);
});

final adminWealthProvider = StateNotifierProvider<AdminWealthNotifier, AdminWealthState>((ref) {
  return AdminWealthNotifier(ref);
});

/// Providers Future pour les données simples (cohorts, LTV, funnel)
final adminRetentionCohortsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getRetentionCohorts();
});

final adminLtvProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getLtvEstimate();
});

final adminConversionFunnelProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getConversionFunnel();
});
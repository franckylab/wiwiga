// ============================================================
// Fichier: admin_metrics_provider.dart
// Description: Providers Riverpod pour les métriques admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/error_handler.dart';
import '../../data/providers/app_providers.dart';

// ========================================
// ÉTATS
// ========================================

/// État des métriques admin
class AdminMetricsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? dashboard;
  final Map<String, dynamic>? financial;
  final Map<String, dynamic>? games;
  final Map<String, dynamic>? users;
  final Map<String, dynamic>? payments;
  final Map<String, dynamic>? security;
  final List<dynamic> timeseries;
  final String selectedPeriod;

  const AdminMetricsState({
    this.isLoading = false,
    this.error,
    this.dashboard,
    this.financial,
    this.games,
    this.users,
    this.payments,
    this.security,
    this.timeseries = const [],
    this.selectedPeriod = '24h',
  });

  AdminMetricsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? dashboard,
    Map<String, dynamic>? financial,
    Map<String, dynamic>? games,
    Map<String, dynamic>? users,
    Map<String, dynamic>? payments,
    Map<String, dynamic>? security,
    List<dynamic>? timeseries,
    String? selectedPeriod,
    bool clearError = false,
  }) {
    return AdminMetricsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      dashboard: dashboard ?? this.dashboard,
      financial: financial ?? this.financial,
      games: games ?? this.games,
      users: users ?? this.users,
      payments: payments ?? this.payments,
      security: security ?? this.security,
      timeseries: timeseries ?? this.timeseries,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }
}

/// État des alertes admin
class AdminAlertsState {
  final bool isLoading;
  final String? error;
  final List<dynamic> alerts;
  final int total;
  final int unreadNotifications;

  const AdminAlertsState({
    this.isLoading = false,
    this.error,
    this.alerts = const [],
    this.total = 0,
    this.unreadNotifications = 0,
  });

  AdminAlertsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? alerts,
    int? total,
    int? unreadNotifications,
    bool clearError = false,
  }) {
    return AdminAlertsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      alerts: alerts ?? this.alerts,
      total: total ?? this.total,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
    );
  }
}

/// État des parties actives
class AdminGamesLiveState {
  final bool isLoading;
  final String? error;
  final List<dynamic> activeGames;
  final Map<String, dynamic>? statsSummary;

  const AdminGamesLiveState({
    this.isLoading = false,
    this.error,
    this.activeGames = const [],
    this.statsSummary,
  });

  AdminGamesLiveState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? activeGames,
    Map<String, dynamic>? statsSummary,
    bool clearError = false,
  }) {
    return AdminGamesLiveState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeGames: activeGames ?? this.activeGames,
      statsSummary: statsSummary ?? this.statsSummary,
    );
  }
}

// ========================================
// STATE NOTIFIERS
// ========================================

/// StateNotifier pour les métriques admin
class AdminMetricsNotifier extends StateNotifier<AdminMetricsState> {
  final Ref _ref;

  AdminMetricsNotifier(this._ref) : super(const AdminMetricsState());

  /// Charger le résumé dashboard
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getDashboardMetrics();
      state = state.copyWith(isLoading: false, dashboard: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadDashboard');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger les métriques financières
  Future<void> loadFinancialMetrics({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getFinancialMetrics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, financial: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadFinancialMetrics');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger les métriques jeux
  Future<void> loadGameMetrics({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getGameMetrics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, games: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadGameMetrics');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger les métriques utilisateurs
  Future<void> loadUserMetrics({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getUserMetrics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, users: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadUserMetrics');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger les métriques paiements
  Future<void> loadPaymentMetrics({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getPaymentMetrics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, payments: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadPaymentMetrics');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger les métriques sécurité
  Future<void> loadSecurityMetrics({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getSecurityMetrics(period: period ?? state.selectedPeriod);
      state = state.copyWith(isLoading: false, security: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadSecurityMetrics');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger les données timeseries
  Future<void> loadTimeseries({required String metric, String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getTimeseries(
        metric: metric,
        period: period ?? state.selectedPeriod,
      );
      state = state.copyWith(isLoading: false, timeseries: data);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadTimeseries');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Changer la période sélectionnée
  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }

  /// Charger toutes les métriques d'un coup
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final results = await Future.wait([
        repo.getDashboardMetrics(),
        repo.getFinancialMetrics(period: state.selectedPeriod),
        repo.getGameMetrics(period: state.selectedPeriod),
        repo.getUserMetrics(period: state.selectedPeriod),
        repo.getPaymentMetrics(period: state.selectedPeriod),
        repo.getSecurityMetrics(period: state.selectedPeriod),
      ]);

      state = state.copyWith(
        isLoading: false,
        dashboard: results[0],
        financial: results[1],
        games: results[2],
        users: results[3],
        payments: results[4],
        security: results[5],
      );
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminMetrics.loadAll');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }
}

/// StateNotifier pour les alertes admin
class AdminAlertsNotifier extends StateNotifier<AdminAlertsState> {
  final Ref _ref;

  AdminAlertsNotifier(this._ref) : super(const AdminAlertsState());

  /// Charger les notifications
  Future<void> loadNotifications({String? type, int page = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getNotifications(page: page, type: type);
      state = state.copyWith(
        isLoading: false,
        alerts: data['notifications'] as List? ?? [],
        total: data['total'] as int? ?? 0,
      );
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminAlerts.loadNotifications');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger le compteur de notifications non lues
  Future<void> loadUnreadCount() async {
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final count = await repo.getUnreadNotificationCount();
      state = state.copyWith(unreadNotifications: count);
    } catch (_) {
      // Silencieux pour le compteur
    }
  }

  /// Marquer comme lu
  Future<void> markRead(String notificationId) async {
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.markNotificationRead(notificationId);
      // Recharger
      await loadUnreadCount();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminAlerts.markRead');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }
}

/// StateNotifier pour les parties en direct
class AdminGamesLiveNotifier extends StateNotifier<AdminGamesLiveState> {
  final Ref _ref;

  AdminGamesLiveNotifier(this._ref) : super(const AdminGamesLiveState());

  /// Charger les parties actives
  Future<void> loadActiveGames() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getActiveGames();
      state = state.copyWith(
        isLoading: false,
        activeGames: data['active_games'] as List? ?? [],
      );
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminGamesLive.loadActiveGames');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Charger le résumé stats
  Future<void> loadStatsSummary() async {
    try {
      final repo = _ref.read(adminRepositoryProvider);
      final data = await repo.getGamesStatsSummary();
      state = state.copyWith(statsSummary: data);
    } catch (_) {
      // Silencieux
    }
  }

  /// Forcer la clôture d'une partie
  Future<bool> forceCloseGame(String gameId, {String? reason}) async {
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.forceCloseGame(gameId, reason: reason);
      await loadActiveGames();
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminGamesLive.forceCloseGame');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

// ========================================
// PROVIDERS
// ========================================

/// Provider principal des métriques admin
final adminMetricsProvider = StateNotifierProvider<AdminMetricsNotifier, AdminMetricsState>((ref) {
  return AdminMetricsNotifier(ref);
});

/// Provider des alertes admin
final adminAlertsProvider = StateNotifierProvider<AdminAlertsNotifier, AdminAlertsState>((ref) {
  return AdminAlertsNotifier(ref);
});

/// Provider des parties en direct
final adminGamesLiveProvider = StateNotifierProvider<AdminGamesLiveNotifier, AdminGamesLiveState>((ref) {
  return AdminGamesLiveNotifier(ref);
});

/// Provider pour les données de sécurité admin
final adminSecurityOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getSecurityOverview();
});

/// Provider pour la whitelist IP
final adminIpWhitelistProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getIpWhitelist();
});

/// Provider pour les authentifications échouées
final adminFailedAuthsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getFailedAuths();
});

/// Provider pour le jeu responsable (overview)
final adminResponsibleGamingProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getResponsibleGamingOverview();
});

/// Provider pour les auto-exclusions
final adminSelfExclusionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getSelfExclusions();
});

/// Provider pour les indicateurs de risque
final adminRiskIndicatorsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getRiskIndicators();
});

/// Provider pour l'historique de configuration
final adminConfigHistoryProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, type) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.getConfigHistory(type: type);
});

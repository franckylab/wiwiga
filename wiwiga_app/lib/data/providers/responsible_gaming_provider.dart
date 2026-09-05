// ============================================================
// Fichier: responsible_gaming_provider.dart
// Description: Provider pour les limites de jeu responsable utilisateur.
//   Toutes les valeurs monétaires sont en jetons (1 jeton = 1 FCFA,
//   backend en jetons purs — AUCUNE conversion centimes).
//   Durées en minutes. Hausse différée 24h côté serveur (pending).
// Auteur: WIWIGA Team
// Date: 2026-08-17 (refonte 2026-09-06)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../core/errors/error_handler.dart';
import '../providers/app_providers.dart';

/// État des limites de jeu responsable (jetons + minutes).
class ResponsibleGamingState {
  final bool isLoading;
  final String? error;
  final int? dailyDepositLimit;
  final int? dailyLossLimit;
  final int? weeklyLossLimit;
  final int? monthlyLossLimit;
  final int? dailyWagerLimit;
  final int? maxBetAmount;
  final int? dailyMatchesLimit;
  final int? sessionTimeLimitMinutes;
  final int? realityCheckIntervalMinutes;
  final DateTime? coolingOffUntil;
  final DateTime? selfExclusionUntil;
  final String? selfExclusionReason;
  final bool isSelfExcluded;
  final Map<String, dynamic> pendingConfig;
  final DateTime? pendingEffectiveAt;
  final int stakedToday;
  final int netLossToday;
  final int matchesToday;
  final int depositsToday;

  const ResponsibleGamingState({
    this.isLoading = false,
    this.error,
    this.dailyDepositLimit,
    this.dailyLossLimit,
    this.weeklyLossLimit,
    this.monthlyLossLimit,
    this.dailyWagerLimit,
    this.maxBetAmount,
    this.dailyMatchesLimit,
    this.sessionTimeLimitMinutes,
    this.realityCheckIntervalMinutes,
    this.coolingOffUntil,
    this.selfExclusionUntil,
    this.selfExclusionReason,
    this.isSelfExcluded = false,
    this.pendingConfig = const {},
    this.pendingEffectiveAt,
    this.stakedToday = 0,
    this.netLossToday = 0,
    this.matchesToday = 0,
    this.depositsToday = 0,
  });

  ResponsibleGamingState copyWith({
    bool? isLoading,
    String? error,
    int? dailyDepositLimit,
    int? dailyLossLimit,
    int? weeklyLossLimit,
    int? monthlyLossLimit,
    int? dailyWagerLimit,
    int? maxBetAmount,
    int? dailyMatchesLimit,
    int? sessionTimeLimitMinutes,
    int? realityCheckIntervalMinutes,
    DateTime? coolingOffUntil,
    DateTime? selfExclusionUntil,
    String? selfExclusionReason,
    bool? isSelfExcluded,
    Map<String, dynamic>? pendingConfig,
    DateTime? pendingEffectiveAt,
    int? stakedToday,
    int? netLossToday,
    int? matchesToday,
    int? depositsToday,
    bool clearError = false,
    bool clearSelfExclusion = false,
  }) {
    return ResponsibleGamingState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      dailyDepositLimit: dailyDepositLimit ?? this.dailyDepositLimit,
      dailyLossLimit: dailyLossLimit ?? this.dailyLossLimit,
      weeklyLossLimit: weeklyLossLimit ?? this.weeklyLossLimit,
      monthlyLossLimit: monthlyLossLimit ?? this.monthlyLossLimit,
      dailyWagerLimit: dailyWagerLimit ?? this.dailyWagerLimit,
      maxBetAmount: maxBetAmount ?? this.maxBetAmount,
      dailyMatchesLimit: dailyMatchesLimit ?? this.dailyMatchesLimit,
      sessionTimeLimitMinutes:
          sessionTimeLimitMinutes ?? this.sessionTimeLimitMinutes,
      realityCheckIntervalMinutes:
          realityCheckIntervalMinutes ?? this.realityCheckIntervalMinutes,
      coolingOffUntil: coolingOffUntil ?? this.coolingOffUntil,
      selfExclusionUntil: clearSelfExclusion ? null : (selfExclusionUntil ?? this.selfExclusionUntil),
      selfExclusionReason: clearSelfExclusion ? null : (selfExclusionReason ?? this.selfExclusionReason),
      isSelfExcluded: clearSelfExclusion ? false : (isSelfExcluded ?? this.isSelfExcluded),
      pendingConfig: pendingConfig ?? this.pendingConfig,
      pendingEffectiveAt: pendingEffectiveAt ?? this.pendingEffectiveAt,
      stakedToday: stakedToday ?? this.stakedToday,
      netLossToday: netLossToday ?? this.netLossToday,
      matchesToday: matchesToday ?? this.matchesToday,
      depositsToday: depositsToday ?? this.depositsToday,
    );
  }

  /// Pause courte active ?
  bool get isCoolingOff {
    if (coolingOffUntil == null) return false;
    return DateTime.now().isBefore(coolingOffUntil!);
  }

  /// Hausse en attente d'effet (24h) ?
  bool get hasPendingIncrease => pendingConfig.isNotEmpty;

  /// Label lisible pour la limite de perte quotidienne (en jetons).
  String get dailyLossLimitLabel =>
      dailyLossLimit != null ? '$dailyLossLimit jetons' : 'Pas de limite';

  /// Label pour l'auto-exclusion.
  String get selfExclusionLabel {
    if (!isSelfExcluded) return 'Désactivé';
    if (selfExclusionUntil == null) return 'Active';
    final now = DateTime.now();
    final diff = selfExclusionUntil!.difference(now);
    if (diff.inDays > 365) return 'Permanente';
    if (diff.inDays > 0) return 'Jusqu\'au ${selfExclusionUntil!.day}/${selfExclusionUntil!.month}/${selfExclusionUntil!.year}';
    return 'Active';
  }
}

/// Notifier pour les limites de jeu responsable.
class ResponsibleGamingNotifier extends StateNotifier<ResponsibleGamingState> {
  final Ref _ref;

  ResponsibleGamingNotifier(this._ref) : super(const ResponsibleGamingState());

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Charge les limites depuis le backend (jetons purs, sans conversion).
  Future<void> loadLimits() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.responsibleGamingLimits,
        requiresAuth: true,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final usage = data['usage_today'] as Map<String, dynamic>? ?? {};

      state = ResponsibleGamingState(
        isLoading: false,
        dailyDepositLimit: _asInt(data['daily_deposit_limit']),
        dailyLossLimit: _asInt(data['daily_loss_limit']),
        weeklyLossLimit: _asInt(data['weekly_loss_limit']),
        monthlyLossLimit: _asInt(data['monthly_loss_limit']),
        dailyWagerLimit: _asInt(data['daily_wager_limit']),
        maxBetAmount: _asInt(data['max_bet_amount']),
        dailyMatchesLimit: _asInt(data['daily_matches_limit']),
        sessionTimeLimitMinutes: _asInt(data['session_time_limit_minutes']),
        realityCheckIntervalMinutes:
            _asInt(data['reality_check_interval_minutes']),
        coolingOffUntil: _asDateTime(data['cooling_off_until']),
        selfExclusionUntil: _asDateTime(data['self_exclusion_until']),
        selfExclusionReason: data['self_exclusion_reason'] as String?,
        isSelfExcluded: data['is_self_excluded'] as bool? ?? false,
        pendingConfig: (data['pending_config'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            const {},
        pendingEffectiveAt: _asDateTime(data['pending_effective_at']),
        stakedToday: _asInt(usage['staked']) ?? 0,
        netLossToday: _asInt(usage['net_loss']) ?? 0,
        matchesToday: _asInt(usage['matches']) ?? 0,
        depositsToday: _asInt(usage['deposits']) ?? 0,
      );
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'ResponsibleGaming.loadLimits');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  /// Met à jour les limites (jetons/minutes, sans conversion).
  /// Les baisses sont immédiates, les hausses effectives après 24h.
  Future<bool> updateLimits(Map<String, dynamic> limits) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.responsibleGamingLimits,
        body: {'limits': limits},
        requiresAuth: true,
      );
      await loadLimits();
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'ResponsibleGaming.updateLimits');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  /// Démarre une pause courte (1 à 30 jours).
  Future<bool> startCoolingOff({required int days}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.put(
        ApiEndpoints.responsibleGamingLimits,
        body: {
          'limits': <String, dynamic>{},
          'cooling_off_days': days,
        },
        requiresAuth: true,
      );
      await loadLimits();
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'ResponsibleGaming.startCoolingOff');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  /// Active l'auto-exclusion (durationDays 1..3650, 0 = permanente).
  Future<bool> selfExclude({required int durationDays, required String reason}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.post(
        ApiEndpoints.responsibleGamingSelfExclude,
        body: {'duration_days': durationDays, 'reason': reason},
        requiresAuth: true,
      );
      await loadLimits();
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'ResponsibleGaming.selfExclude');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
      return false;
    }
  }
}

/// Provider principal.
final responsibleGamingProvider =
    StateNotifierProvider<ResponsibleGamingNotifier, ResponsibleGamingState>((ref) {
  return ResponsibleGamingNotifier(ref);
});

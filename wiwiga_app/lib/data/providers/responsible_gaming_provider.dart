// ============================================================
// Fichier: responsible_gaming_provider.dart
// Description: Provider pour les limites de jeu responsable utilisateur
// Auteur: WIWIGA Team
// Date: 2026-08-17
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../providers/app_providers.dart';

/// État des limites de jeu responsable
class ResponsibleGamingState {
  final bool isLoading;
  final String? error;
  final int? dailyDepositLimit;
  final int? dailyLossLimit;
  final int? dailyWagerLimit;
  final int? sessionTimeLimitMinutes;
  final int? realityCheckIntervalMinutes;
  final DateTime? selfExclusionUntil;
  final String? selfExclusionReason;
  final bool isSelfExcluded;

  const ResponsibleGamingState({
    this.isLoading = false,
    this.error,
    this.dailyDepositLimit,
    this.dailyLossLimit,
    this.dailyWagerLimit,
    this.sessionTimeLimitMinutes,
    this.realityCheckIntervalMinutes,
    this.selfExclusionUntil,
    this.selfExclusionReason,
    this.isSelfExcluded = false,
  });

  ResponsibleGamingState copyWith({
    bool? isLoading,
    String? error,
    int? dailyDepositLimit,
    int? dailyLossLimit,
    int? dailyWagerLimit,
    int? sessionTimeLimitMinutes,
    int? realityCheckIntervalMinutes,
    DateTime? selfExclusionUntil,
    String? selfExclusionReason,
    bool? isSelfExcluded,
    bool clearError = false,
    bool clearSelfExclusion = false,
  }) {
    return ResponsibleGamingState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      dailyDepositLimit: dailyDepositLimit ?? this.dailyDepositLimit,
      dailyLossLimit: dailyLossLimit ?? this.dailyLossLimit,
      dailyWagerLimit: dailyWagerLimit ?? this.dailyWagerLimit,
      sessionTimeLimitMinutes: sessionTimeLimitMinutes ?? this.sessionTimeLimitMinutes,
      realityCheckIntervalMinutes: realityCheckIntervalMinutes ?? this.realityCheckIntervalMinutes,
      selfExclusionUntil: clearSelfExclusion ? null : (selfExclusionUntil ?? this.selfExclusionUntil),
      selfExclusionReason: clearSelfExclusion ? null : (selfExclusionReason ?? this.selfExclusionReason),
      isSelfExcluded: clearSelfExclusion ? false : (isSelfExcluded ?? this.isSelfExcluded),
    );
  }

  /// Label lisible pour la limite de mise quotidienne (en wiga)
  String get dailyLossLimitLabel =>
      dailyLossLimit != null ? '$dailyLossLimit wiga' : 'Pas de limite';

  /// Label pour l'auto-exclusion
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

/// Notifier pour les limites de jeu responsable
class ResponsibleGamingNotifier extends StateNotifier<ResponsibleGamingState> {
  final Ref _ref;

  ResponsibleGamingNotifier(this._ref) : super(const ResponsibleGamingState());

  /// Charge les limites depuis le backend
  Future<void> loadLimits() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.responsibleGamingLimits,
        requiresAuth: true,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};

      DateTime? exclusionUntil;
      if (data['self_exclusion_until'] != null) {
        exclusionUntil = DateTime.tryParse(data['self_exclusion_until'].toString());
      }

      // Backend stocke en centimes → conversion wiga (1:1) pour affichage uniforme
      int? toWiga(dynamic v) => v == null ? null : (v as int) ~/ 100;
      state = ResponsibleGamingState(
        isLoading: false,
        dailyDepositLimit: toWiga(data['daily_deposit_limit']),
        dailyLossLimit: toWiga(data['daily_loss_limit']),
        dailyWagerLimit: toWiga(data['daily_wager_limit']),
        sessionTimeLimitMinutes: data['session_time_limit_minutes'] as int?,
        realityCheckIntervalMinutes: data['reality_check_interval_minutes'] as int?,
        selfExclusionUntil: exclusionUntil,
        selfExclusionReason: data['self_exclusion_reason'] as String?,
        isSelfExcluded: data['is_self_excluded'] as bool? ?? false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Met à jour les limites (conversion wiga → centimes pour backend)
  Future<bool> updateLimits(Map<String, dynamic> limits) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      // Convertir limites wiga → centimes (taux 1:1, 1 wiga = 1 FCFA = 100 centimes)
      final converted = limits.map((k, v) {
        if (v is int && k.contains('limit')) {
          return MapEntry(k, v * 100);
        }
        return MapEntry(k, v);
      });
      await apiService.put(
        ApiEndpoints.responsibleGamingLimits,
        body: {'limits': converted},
        requiresAuth: true,
      );
      await loadLimits();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Active l'auto-exclusion
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

/// Provider principal
final responsibleGamingProvider =
    StateNotifierProvider<ResponsibleGamingNotifier, ResponsibleGamingState>((ref) {
  return ResponsibleGamingNotifier(ref);
});

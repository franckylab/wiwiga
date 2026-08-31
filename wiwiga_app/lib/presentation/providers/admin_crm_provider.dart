// ============================================================
// Fichier: admin_crm_provider.dart
// Description: Providers Riverpod pour le CRM admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/error_handler.dart';
import '../../data/providers/app_providers.dart';

// ========================================
// ÉTATS
// ========================================

class AdminCrmState {
  final bool isLoading;
  final String? error;
  final List<dynamic> segments;
  final List<dynamic> vipPlayers;
  final List<dynamic> atRiskPlayers;
  final Map<String, dynamic>? selectedPlayerSummary;

  const AdminCrmState({
    this.isLoading = false,
    this.error,
    this.segments = const [],
    this.vipPlayers = const [],
    this.atRiskPlayers = const [],
    this.selectedPlayerSummary,
  });

  AdminCrmState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? segments,
    List<dynamic>? vipPlayers,
    List<dynamic>? atRiskPlayers,
    Map<String, dynamic>? selectedPlayerSummary,
  }) {
    return AdminCrmState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      segments: segments ?? this.segments,
      vipPlayers: vipPlayers ?? this.vipPlayers,
      atRiskPlayers: atRiskPlayers ?? this.atRiskPlayers,
      selectedPlayerSummary: selectedPlayerSummary ?? this.selectedPlayerSummary,
    );
  }
}

// ========================================
// NOTIFIER
// ========================================

class AdminCrmNotifier extends StateNotifier<AdminCrmState> {
  final Ref ref;

  AdminCrmNotifier(this.ref) : super(const AdminCrmState());

  Future<void> loadSegments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final segments = await ref.read(adminRepositoryProvider).getCrmSegments();
      state = state.copyWith(isLoading: false, segments: segments);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.loadSegments');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> loadVipPlayers() async {
    try {
      final players = await ref.read(adminRepositoryProvider).getVipPlayers();
      state = state.copyWith(vipPlayers: players);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.loadVipPlayers');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> loadAtRiskPlayers() async {
    try {
      final players = await ref.read(adminRepositoryProvider).getAtRiskPlayers();
      state = state.copyWith(atRiskPlayers: players);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.loadAtRiskPlayers');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> loadPlayerSummary(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await ref.read(adminRepositoryProvider).getPlayerSummary(userId);
      state = state.copyWith(isLoading: false, selectedPlayerSummary: summary);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.loadPlayerSummary');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> addNote(String userId, String note, {String category = 'general'}) async {
    try {
      await ref.read(adminRepositoryProvider).addPlayerNote(userId, note, category: category);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.addNote');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> setVipTier(String userId, String tier) async {
    try {
      await ref.read(adminRepositoryProvider).setVipTier(userId, tier);
      // Recharger les VIP
      await loadVipPlayers();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.setVipTier');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        ref.read(adminRepositoryProvider).getCrmSegments(),
        ref.read(adminRepositoryProvider).getVipPlayers(),
        ref.read(adminRepositoryProvider).getAtRiskPlayers(),
      ]);
      state = state.copyWith(
        isLoading: false,
        segments: results[0],
        vipPlayers: results[1],
        atRiskPlayers: results[2],
      );
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminCrm.loadAll');
      state = state.copyWith(isLoading: false, error: ErrorHandler.userMessage(e));
    }
  }
}

// ========================================
// PROVIDERS
// ========================================

final adminCrmProvider = StateNotifierProvider<AdminCrmNotifier, AdminCrmState>((ref) {
  return AdminCrmNotifier(ref);
});

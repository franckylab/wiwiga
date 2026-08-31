// ============================================================
// Fichier: sessions_provider.dart
// Description: Provider sessions actives utilisateur
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/error_handler.dart';
import '../repositories/profile_repository.dart';
import 'app_providers.dart';

/// État des sessions
class SessionsState {
  final bool isLoading;
  final List<Map<String, dynamic>> sessions;
  final String? error;

  const SessionsState({
    this.isLoading = false,
    this.sessions = const [],
    this.error,
  });

  SessionsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? sessions,
    String? error,
  }) {
    return SessionsState(
      isLoading: isLoading ?? this.isLoading,
      sessions: sessions ?? this.sessions,
      error: error,
    );
  }
}

/// Provider des sessions actives
final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, SessionsState>(
  (ref) => SessionsNotifier(ref),
);

class SessionsNotifier extends StateNotifier<SessionsState> {
  final Ref _ref;

  SessionsNotifier(this._ref) : super(const SessionsState());

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  /// Charge les sessions actives
  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sessions = await _repository.getSessions();
      state = state.copyWith(isLoading: false, sessions: sessions);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Sessions.loadSessions');
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.userMessage(e),
      );
    }
  }

  /// Révoque une session spécifique
  Future<bool> revokeSession(String sessionId) async {
    try {
      await _repository.revokeSession(sessionId);
      // Retirer de la liste locale
      state = state.copyWith(
        sessions: state.sessions
            .where((s) => s['id']?.toString() != sessionId)
            .toList(),
      );
      return true;
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Sessions.revokeSession');
      state = state.copyWith(error: ErrorHandler.userMessage(e));
      return false;
    }
  }

  /// Efface l'erreur
  void clearError() {
    state = state.copyWith(error: null);
  }
}

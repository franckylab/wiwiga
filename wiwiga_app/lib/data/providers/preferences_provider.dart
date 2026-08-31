// ============================================================
// Fichier: preferences_provider.dart
// Description: Provider préférences utilisateur (persistées serveur)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/error_handler.dart';
import '../repositories/preferences_repository.dart';
import 'app_providers.dart';

/// État des préférences utilisateur
class PreferencesState {
  final bool isLoading;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final String language; // fr, en
  final String theme; // neon, dark, light
  final String fontSize; // small, medium, large
  final String? error;

  const PreferencesState({
    this.isLoading = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.language = 'fr',
    this.theme = 'neon',
    this.fontSize = 'medium',
    this.error,
  });

  PreferencesState copyWith({
    bool? isLoading,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    String? language,
    String? theme,
    String? fontSize,
    String? error,
  }) {
    return PreferencesState(
      isLoading: isLoading ?? this.isLoading,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      error: error,
    );
  }

  /// Convertit en map pour l'API
  Map<String, dynamic> toMap() => {
        'sound_enabled': soundEnabled,
        'vibration_enabled': vibrationEnabled,
        'notifications_enabled': notificationsEnabled,
        'language': language,
        'theme': theme,
        'font_size': fontSize,
      };
}

/// Provider des préférences
final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, PreferencesState>(
  (ref) => PreferencesNotifier(ref),
);

class PreferencesNotifier extends StateNotifier<PreferencesState> {
  final Ref _ref;

  PreferencesNotifier(this._ref) : super(const PreferencesState());

  PreferencesRepository get _repository =>
      _ref.read(preferencesRepositoryProvider);

  /// Charge les préférences depuis le serveur
  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await _repository.getPreferences();
      state = PreferencesState(
        isLoading: false,
        soundEnabled: prefs['sound_enabled'] as bool? ?? true,
        vibrationEnabled: prefs['vibration_enabled'] as bool? ?? true,
        notificationsEnabled: prefs['notifications_enabled'] as bool? ?? true,
        language: prefs['language'] as String? ?? 'fr',
        theme: prefs['theme'] as String? ?? 'neon',
        fontSize: prefs['font_size'] as String? ?? 'medium',
      );
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Preferences.loadPreferences');
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.userMessage(e),
      );
    }
  }

  /// Met à jour une préférence booléenne (optimistic update)
  Future<void> updateBool(String key, bool value) async {
    final previousState = state;

    // Optimistic update
    switch (key) {
      case 'sound_enabled':
        state = state.copyWith(soundEnabled: value);
        break;
      case 'vibration_enabled':
        state = state.copyWith(vibrationEnabled: value);
        break;
      case 'notifications_enabled':
        state = state.copyWith(notificationsEnabled: value);
        break;
    }

    // Sync serveur
    try {
      await _repository.updatePreferences({key: value});
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Preferences.updateBool');
      // Rollback en cas d'erreur
      state = previousState;
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  /// Met à jour une préférence string (optimistic update)
  Future<void> updateString(String key, String value) async {
    final previousState = state;

    // Optimistic update
    switch (key) {
      case 'language':
        state = state.copyWith(language: value);
        break;
      case 'theme':
        state = state.copyWith(theme: value);
        break;
      case 'font_size':
        state = state.copyWith(fontSize: value);
        break;
    }

    // Sync serveur
    try {
      await _repository.updatePreferences({key: value});
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'Preferences.updateString');
      // Rollback
      state = previousState;
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  /// Efface l'erreur
  void clearError() {
    state = state.copyWith(error: null);
  }
}

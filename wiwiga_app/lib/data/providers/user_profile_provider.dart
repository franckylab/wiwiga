// ============================================================
// Fichier: user_profile_provider.dart
// Description: Provider profil utilisateur connecté au backend
// ============================================================

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../repositories/profile_repository.dart';
import 'app_providers.dart';

/// État du profil utilisateur
class UserProfileState {
  final bool isLoading;
  final UserProfile? profile;
  final List<Achievement> achievements;
  final String? error;

  const UserProfileState({
    this.isLoading = false,
    this.profile,
    this.achievements = const [],
    this.error,
  });

  UserProfileState copyWith({
    bool? isLoading,
    UserProfile? profile,
    List<Achievement>? achievements,
    String? error,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      achievements: achievements ?? this.achievements,
      error: error,
    );
  }
}

/// Provider du profil utilisateur avec données réelles
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>(
  (ref) => UserProfileNotifier(ref),
);

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final Ref _ref;

  UserProfileNotifier(this._ref) : super(const UserProfileState());

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  /// Charge le profil complet (stats + achievements) depuis l'API
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Charger stats et achievements en parallèle
      final results = await Future.wait([
        _repository.getStats(),
        _repository.getAchievements(),
      ]);

      final profile = results[0] as UserProfile;
      final achievements = results[1] as List<Achievement>;

      state = state.copyWith(
        isLoading: false,
        profile: profile,
        achievements: achievements,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur chargement profil: $e',
      );
    }
  }

  /// Met à jour le username via l'API
  Future<bool> updateUsername(String newUsername) async {
    try {
      await _repository.updateProfile(username: newUsername);
      // Mettre à jour le user dans authProvider
      _ref.read(authProvider.notifier).refreshProfile();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Erreur update username: $e');
      return false;
    }
  }

  /// Change l'avatar pour un avatar prédéfini WIWIGA
  Future<bool> selectAvatar(AvatarType avatarType) async {
    try {
      await _repository.updateProfile(
        username: null, // Pas de changement username
      );
      // Mettre à jour l'avatar_type via updateProfile
      // Le backend gère avatar_type dans le changeset
      await _ref.read(authProvider.notifier).refreshProfile();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Erreur changement avatar: $e');
      return false;
    }
  }

  /// Upload une photo personnelle comme avatar
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final avatarUrl = await _repository.uploadAvatar(imageFile);
      // Refresh le profil pour obtenir le nouvel avatar_url
      await _ref.read(authProvider.notifier).refreshProfile();
      return avatarUrl;
    } catch (e) {
      state = state.copyWith(error: 'Erreur upload avatar: $e');
      return null;
    }
  }

  /// Rafraîchit les stats uniquement
  Future<void> refreshStats() async {
    try {
      final profile = await _repository.getStats();
      state = state.copyWith(profile: profile);
    } catch (e) {
      // Silencieux pour le refresh
    }
  }

  /// Rafraîchit les achievements
  Future<void> refreshAchievements() async {
    try {
      final achievements = await _repository.getAchievements();
      state = state.copyWith(achievements: achievements);
    } catch (e) {
      // Silencieux pour le refresh
    }
  }

  /// Efface l'erreur
  void clearError() {
    state = state.copyWith(error: null);
  }
}

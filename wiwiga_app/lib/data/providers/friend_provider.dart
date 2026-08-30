// ============================================================
// Fichier: friend_provider.dart
// Description: Providers Riverpod pour le système d'amis
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/friend_repository.dart';
import '../models/friend_model.dart';
import 'app_providers.dart';

/// Provider pour le FriendRepository — réutilise l'ApiService centralisé
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FriendRepository(apiService);
});

/// Provider pour la liste des amis
/// Auto-dispose non nécessaire: cache 30s implicite via Riverpod
final friendsProvider = FutureProvider<List<FriendModel>>((ref) async {
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.listFriends();
  } catch (e) {
    // Retourne liste vide si 401 -> l'écran guest gère le CTA
    // Propager l'erreur pour affichage dans l'UI si authentifié
    rethrow;
  }
});

/// Provider pour les demandes d'amis en attente
final pendingRequestsProvider = FutureProvider<List<FriendRequestModel>>((ref) async {
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.listPendingRequests();
  } catch (e) {
    rethrow;
  }
});

/// Provider pour le nombre de demandes en attente (badge)
final pendingRequestsCountProvider = FutureProvider<int>((ref) async {
  final requests = await ref.watch(pendingRequestsProvider.future);
  return requests.length;
});

/// Provider pour le leaderboard amis
final friendLeaderboardProvider = FutureProvider<List<FriendLeaderboardEntry>>((ref) async {
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.getLeaderboard();
  } catch (e) {
    rethrow;
  }
});

/// Provider pour l'activité des amis
final friendActivityProvider = FutureProvider<List<FriendActivityModel>>((ref) async {
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.getActivity();
  } catch (e) {
    rethrow;
  }
});

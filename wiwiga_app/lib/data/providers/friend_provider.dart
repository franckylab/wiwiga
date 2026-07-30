// ============================================================
// Fichier: friend_provider.dart
// Description: Providers Riverpod pour le système d'amis
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/friend_repository.dart';
import '../services/api_service.dart';
import '../models/friend_model.dart';

/// Provider pour le FriendRepository
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FriendRepository(apiService);
});

/// Provider pour ApiService (si pas déjà défini ailleurs)
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Provider pour la liste des amis
final friendsProvider = FutureProvider<List<FriendModel>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  return repo.listFriends();
});

/// Provider pour les demandes d'amis en attente
final pendingRequestsProvider = FutureProvider<List<FriendRequestModel>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  return repo.listPendingRequests();
});

/// Provider pour le nombre de demandes en attente (badge)
final pendingRequestsCountProvider = FutureProvider<int>((ref) async {
  final requests = await ref.watch(pendingRequestsProvider.future);
  return requests.length;
});

/// Provider pour le leaderboard amis
final friendLeaderboardProvider = FutureProvider<List<FriendLeaderboardEntry>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  return repo.getLeaderboard();
});

/// Provider pour l'activité des amis
final friendActivityProvider = FutureProvider<List<FriendActivityModel>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  return repo.getActivity();
});

// ============================================================
// Fichier: friend_provider.dart
// Description: Providers Riverpod pour le système d'amis
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/friend_repository.dart';
import '../models/friend_model.dart';
import 'app_providers.dart';

/// Provider pour le FriendRepository — réutilise l'ApiService centralisé
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FriendRepository(apiService);
});

/// Provider pour la liste des amis — 30s quand visible, WS `friendOnline` complète
final friendsProvider = FutureProvider.autoDispose<List<FriendModel>>((ref) async {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.listFriends();
  } catch (e) {
    rethrow;
  }
});

/// Provider pour les demandes d'amis en attente — 30s
final pendingRequestsProvider = FutureProvider.autoDispose<List<FriendRequestModel>>((ref) async {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.listPendingRequests();
  } catch (e) {
    rethrow;
  }
});

/// Provider pour le nombre de demandes en attente (badge) — dérivé, pas de timer propre
final pendingRequestsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final requests = await ref.watch(pendingRequestsProvider.future);
  return requests.length;
});

/// Provider pour le leaderboard amis — 60s
final friendLeaderboardProvider = FutureProvider.autoDispose<List<FriendLeaderboardEntry>>((ref) async {
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.getLeaderboard();
  } catch (e) {
    rethrow;
  }
});

/// Provider pour l'activité des amis — 60s
final friendActivityProvider = FutureProvider.autoDispose<List<FriendActivityModel>>((ref) async {
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(friendRepositoryProvider);
  try {
    return await repo.getActivity();
  } catch (e) {
    rethrow;
  }
});

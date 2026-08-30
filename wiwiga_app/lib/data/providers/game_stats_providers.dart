// ============================================================
// Fichier: game_stats_providers.dart
// Description: Providers Riverpod catalogue, stats, classement, activité
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_model.dart';
import '../models/game_room_model.dart';
import '../models/game_stats_models.dart';
import '../repositories/room_repository.dart';
import 'app_providers.dart';

// ============================================================
// REPOSITORY SALLES
// ============================================================

/// Provider du repository Rooms (salles de jeu)
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return RoomRepository(apiService);
});

// ============================================================
// CATALOGUE & DÉTAIL
// ============================================================

/// Catalogue des jeux (triés par display_order côté backend)
final gamesCatalogProvider = FutureProvider<List<GameModel>>((ref) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getGames();
});

/// Détail d'un jeu (tips + config inclus)
final gameDetailProvider =
    FutureProvider.family<GameModel, String>((ref, gameType) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getGame(gameType);
});

// ============================================================
// STATS & CLASSEMENT
// ============================================================

/// Stats globales d'un jeu (joueurs en ligne, parties du jour...)
final gameStatsProvider =
    FutureProvider.family<GameGlobalStats, String>((ref, gameType) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getGameStats(gameType);
});

/// Paramètres d'un classement
typedef LeaderboardParams = ({String gameType, String metric, String period});

/// Classement d'un jeu pour une métrique × période
final gameLeaderboardProvider =
    FutureProvider.family<GameLeaderboard, LeaderboardParams>(
        (ref, params) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getLeaderboard(
    params.gameType,
    metric: params.metric,
    period: params.period,
  );
});

/// Mes statistiques personnelles sur un jeu
final myGameStatsProvider =
    FutureProvider.family<MyGameStats, String>((ref, gameType) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getMyStats(gameType);
});

/// Règles d'un jeu (Normal/Cible)
final gameRulesProvider =
    FutureProvider.family<List<GameRuleInfo>, String>((ref, gameType) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getRules(gameType);
});

/// Astuces d'un jeu
final gameTipsProvider =
    FutureProvider.family<List<GameTip>, String>((ref, gameType) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getTips(gameType);
});

// ============================================================
// ACTIVITÉ & SALLES EN ATTENTE (auto-refresh)
// ============================================================

/// Flux d'activité récent d'un jeu, rafraîchi toutes les 60 secondes (éco perf, évite Violation)
final gameActivityProvider = FutureProvider.family<List<GameActivityEvent>,
    String>((ref, gameType) async {
  // Auto-refresh périodique - léger
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  final repo = ref.watch(gameRepositoryProvider);
  return repo.getActivity(gameType);
});

/// Salles en attente d'un jeu, rafraîchies toutes les 30 secondes (au lieu de 15)
final waitingRoomsProvider =
    FutureProvider.family<List<GameRoomModel>, String>((ref, gameType) async {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  final repo = ref.watch(roomRepositoryProvider);
  return repo.listWaitingRooms(gameType: gameType);
});

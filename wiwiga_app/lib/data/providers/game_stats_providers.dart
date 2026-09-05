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
// Auto-refresh 60s quand visible, pas de polling en background (autoDispose)
final gamesCatalogProvider = FutureProvider.autoDispose<List<GameModel>>((ref) async {
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getGames();
});

/// Détail d'un jeu (tips + config inclus) — cache 2min, peu volatil
final gameDetailProvider =
    FutureProvider.autoDispose.family<GameModel, String>((ref, gameType) async {
  final timer = Timer(const Duration(seconds: 120), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getGame(gameType);
});

// ============================================================
// STATS & CLASSEMENT — auto-refresh léger et cohérent
// ============================================================

/// Stats globales d'un jeu (joueurs en ligne, parties du jour...) — 30s
final gameStatsProvider =
    FutureProvider.autoDispose.family<GameGlobalStats, String>((ref, gameType) async {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getGameStats(gameType);
});

/// Paramètres d'un classement
typedef LeaderboardParams = ({String gameType, String metric, String period});

/// Classement d'un jeu pour une métrique × période — 60s
final gameLeaderboardProvider =
    FutureProvider.autoDispose.family<GameLeaderboard, LeaderboardParams>(
        (ref, params) async {
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getLeaderboard(
    params.gameType,
    metric: params.metric,
    period: params.period,
  );
});

/// Mes statistiques personnelles sur un jeu — 45s
final myGameStatsProvider =
    FutureProvider.autoDispose.family<MyGameStats, String>((ref, gameType) async {
  final timer = Timer(const Duration(seconds: 45), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getMyStats(gameType);
});

/// Règles d'un jeu (Normal/Cible) — 5min (peu volatil, admin)
final gameRulesProvider =
    FutureProvider.autoDispose.family<List<GameRuleInfo>, String>((ref, gameType) async {
  final timer = Timer(const Duration(seconds: 300), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getRules(gameType);
});

/// Astuces d'un jeu — 5min
final gameTipsProvider =
    FutureProvider.autoDispose.family<List<GameTip>, String>((ref, gameType) async {
  final timer = Timer(const Duration(seconds: 300), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
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

/// Partie active de l'utilisateur pour redirection auto (room/match/quick_lobby)
/// Usage: lorsqu'un joueur est déjà dans une partie en attente ou en cours,
/// la page Jeux le redirige directement vers attente ou partie. Poll léger 15s quand visible.
final activeGameProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.isGuest || auth.isUnknown) return null;
  final timer = Timer(const Duration(seconds: 15), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(gameRepositoryProvider);
  try {
    final data = await repo.getActiveGame();
    if (data['has_active'] == true) return data;
    return null;
  } catch (_) {
    return null;
  }
});

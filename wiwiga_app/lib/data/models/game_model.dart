// ============================================================
// Fichier: game_model.dart
// Description: Modèle de jeu WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'game_stats_models.dart';

/// Modèle représentant un jeu disponible
class GameModel {
  final String id;
  final String name;
  final String description;
  final String type; // 'dice', etc.
  final double minBet;
  final double maxBet;
  final double houseEdge;
  final bool isActive;
  final int maxPlayers;
  final String? imageUrl;
  final bool comingSoon;
  final int displayOrder;
  final int playersOnline;
  final List<GameTip> tips;
  
  const GameModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.minBet,
    required this.maxBet,
    required this.houseEdge,
    required this.isActive,
    required this.maxPlayers,
    this.imageUrl,
    this.comingSoon = false,
    this.displayOrder = 0,
    this.playersOnline = 0,
    this.tips = const [],
  });
  
  /// Crée un modèle depuis JSON
  factory GameModel.fromJson(Map<String, dynamic> json) {
    final rawTips = json['tips'] as List? ?? [];
    return GameModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      // Le backend utilise l'id comme game_type ('dice', 'ludo', ...)
      type: json['type'] ?? json['id'] ?? 'dice',
      minBet: (json['min_bet'] ?? 0).toDouble(),
      maxBet: (json['max_bet'] ?? 0).toDouble(),
      houseEdge: (json['commission_rate'] ?? json['house_edge'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? (json['status'] == null || json['status'] == 'active'),
      maxPlayers: json['max_players'] ?? 2,
      imageUrl: json['image_url'],
      comingSoon: json['coming_soon'] ?? false,
      displayOrder: (json['display_order'] ?? 0) as int,
      playersOnline: (json['players_online'] ?? 0) as int,
      tips: rawTips
          .map((t) => GameTip.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Modèle d'une session de jeu en cours
class GameSessionModel {
  final String id;
  final String gameId;
  final String gameName;
  final List<String> playerIds;
  final double totalPot;
  final DateTime startedAt;
  final String status; // 'waiting', 'playing', 'finished'
  final Map<String, dynamic>? result;
  
  const GameSessionModel({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.playerIds,
    required this.totalPot,
    required this.startedAt,
    required this.status,
    this.result,
  });
  
  /// Crée un modèle depuis JSON
  factory GameSessionModel.fromJson(Map<String, dynamic> json) {
    return GameSessionModel(
      id: json['id'] ?? '',
      gameId: json['game_id'] ?? '',
      gameName: json['game_name'] ?? '',
      playerIds: List<String>.from(json['player_ids'] ?? []),
      totalPot: (json['total_pot'] ?? 0).toDouble(),
      startedAt: DateTime.parse(json['started_at']),
      status: json['status'] ?? 'waiting',
      result: json['result'],
    );
  }
}

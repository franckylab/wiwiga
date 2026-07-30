// ============================================================
// Fichier: game_room_model.dart
// Description: Modèle de salle de jeu WIWIGA
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

/// Modèle représentant une salle de jeu (Room)
class GameRoomModel {
  final String roomId;
  final String roomCode;
  final String creatorId;
  final String gameType;
  final String ruleType;
  final String mode; // 'free' | 'betting'
  final String status; // 'waiting' | 'starting' | 'in_progress' | 'ended' | 'cancelled'
  final int betAmount;
  final int setsCount;
  final int diceCount;
  final int maxPlayers;
  final int playersCount;
  final List<RoomPlayer> players;
  final String? matchId;
  final DateTime? createdAt;

  const GameRoomModel({
    required this.roomId,
    required this.roomCode,
    required this.creatorId,
    required this.gameType,
    required this.ruleType,
    required this.mode,
    required this.status,
    required this.betAmount,
    required this.setsCount,
    required this.diceCount,
    required this.maxPlayers,
    required this.playersCount,
    required this.players,
    this.matchId,
    this.createdAt,
  });

  factory GameRoomModel.fromJson(Map<String, dynamic> json) {
    return GameRoomModel(
      roomId: json['room_id'] ?? '',
      roomCode: json['room_code'] ?? '',
      creatorId: json['creator_id'] ?? '',
      gameType: json['game_type'] ?? 'dice',
      ruleType: json['rule_type'] ?? 'normal',
      mode: json['mode'] ?? 'free',
      status: json['status'] ?? 'waiting',
      betAmount: json['bet_amount'] ?? 0,
      setsCount: json['sets_count'] ?? 1,
      diceCount: json['dice_count'] ?? 2,
      maxPlayers: json['max_players'] ?? 2,
      playersCount: json['players_count'] ?? 0,
      players: (json['players'] as List<dynamic>?)
              ?.map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      matchId: json['match_id'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  bool get isFree => mode == 'free';
  bool get isBetting => mode == 'betting';
  bool get isWaiting => status == 'waiting';
  bool get isInProgress => status == 'in_progress';
  bool get isFull => playersCount >= maxPlayers;
}

/// Joueur dans une salle
class RoomPlayer {
  final String id;
  final String name;
  final DateTime? joinedAt;

  const RoomPlayer({required this.id, required this.name, this.joinedAt});

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Joueur',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at']) : null,
    );
  }
}

/// Configuration de création de partie
class CreateGameConfig {
  final String gameType;
  final String ruleType;
  final String mode;
  final int setsCount;
  final int diceCount;
  final int betAmount;
  final int maxPlayers;

  const CreateGameConfig({
    this.gameType = 'dice',
    this.ruleType = 'normal',
    this.mode = 'free',
    this.setsCount = 1,
    this.diceCount = 2,
    this.betAmount = 0,
    this.maxPlayers = 2,
  });

  Map<String, dynamic> toJson() {
    return {
      'game_type': gameType,
      'rule_type': ruleType,
      'mode': mode,
      'sets_count': setsCount,
      'dice_count': diceCount,
      'bet_amount': betAmount,
      'max_players': maxPlayers,
    };
  }
}

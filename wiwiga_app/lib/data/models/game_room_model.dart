// ============================================================
// Fichier: game_room_model.dart
// Description: Modèle de salle de jeu WIWIGA — migration brutale 2026-08-30
//              Modes: free = Partie sans mise (gratuit), staked = Partie avec mise
//              "betting"/"mise en ligne"/"pari" SUPPRIMÉS
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29 (refactor brutal 2026-08-30)
// ============================================================

import '../../core/constants/game_mode.dart';

/// Modèle représentant une salle de jeu (Room)
class GameRoomModel {
  final String roomId;
  final String roomCode;
  final String creatorId;
  final String gameType;
  final String ruleType;
  final String mode; // 'free' (Partie sans mise) | 'staked' (Partie avec mise) — betting supprimé
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
    // Migration brutale: seuls free/staked acceptés — betting lève
    final rawMode = json['mode'] as String? ?? 'free';
    final canonicalMode = GameMode.parse(rawMode).apiValue;
    return GameRoomModel(
      roomId: json['room_id'] ?? '',
      roomCode: json['room_code'] ?? '',
      creatorId: json['creator_id'] ?? '',
      gameType: json['game_type'] ?? 'dice',
      ruleType: json['rule_type'] ?? 'normal',
      mode: canonicalMode,
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

  /// Mode canonique typé
  GameMode get gameMode => GameMode.parse(mode);

  /// Affichages centralisés
  String get modeLabel => gameMode.displayLabel;
  String get modeShortLabel => gameMode.shortLabel;
  String get modeSubtitle => gameMode.subtitle;

  bool get isFree => gameMode.isFree;
  bool get isStaked => gameMode.isStaked;

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

/// Configuration de création de partie — migration brutale
class CreateGameConfig {
  final String gameType;
  final String ruleType;
  final String mode; // 'free' (Partie sans mise) | 'staked' (Partie avec mise) — betting supprimé
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

  /// Constructeur typé depuis enum
  factory CreateGameConfig.withMode({
    String gameType = 'dice',
    String ruleType = 'normal',
    GameMode mode = GameMode.free,
    int setsCount = 1,
    int diceCount = 2,
    int betAmount = 0,
    int maxPlayers = 2,
  }) {
    return CreateGameConfig(
      gameType: gameType,
      ruleType: ruleType,
      mode: mode.apiValue,
      setsCount: setsCount,
      diceCount: diceCount,
      betAmount: betAmount,
      maxPlayers: maxPlayers,
    );
  }

  Map<String, dynamic> toJson() {
    // Toujours envoyer la valeur canonique (free/staked)
    final canonical = GameMode.parse(mode).apiValue;
    return {
      'game_type': gameType,
      'rule_type': ruleType,
      'mode': canonical,
      'sets_count': setsCount,
      'dice_count': diceCount,
      'bet_amount': betAmount,
      'max_players': maxPlayers,
    };
  }
}

// ============================================================
// Fichier: friend_model.dart
// Description: Modèles du système d'amis WIWIGA
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

/// Modèle représentant un ami
class FriendModel {
  final int id;
  final String name;
  final String? phone;
  final String status; // 'online' | 'offline' | 'in_game'
  final int? friendshipId;
  final DateTime? createdAt;

  const FriendModel({
    required this.id,
    required this.name,
    this.phone,
    this.status = 'offline',
    this.friendshipId,
    this.createdAt,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      name: json['name'] ?? 'Inconnu',
      phone: json['phone'],
      status: json['status'] ?? 'offline',
      friendshipId: json['friendship_id'] is int
          ? json['friendship_id']
          : int.tryParse(json['friendship_id']?.toString() ?? '0'),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  bool get isOnline => status == 'online' || status == 'in_game';
  bool get isInGame => status == 'in_game';
}

/// Demande d'ami en attente
class FriendRequestModel {
  final int id;
  final FriendUser fromUser;
  final DateTime createdAt;

  const FriendRequestModel({required this.id, required this.fromUser, required this.createdAt});

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      fromUser: FriendUser.fromJson(json['from_user'] as Map<String, dynamic>),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

/// Utilisateur dans le contexte amis
class FriendUser {
  final int id;
  final String name;
  final String? phone;

  const FriendUser({required this.id, required this.name, this.phone});

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      name: json['name'] ?? 'Inconnu',
      phone: json['phone'],
    );
  }
}

/// Activité d'un ami
class FriendActivityModel {
  final Map<String, dynamic> activity;
  final FriendUser user;

  const FriendActivityModel({required this.activity, required this.user});

  factory FriendActivityModel.fromJson(Map<String, dynamic> json) {
    return FriendActivityModel(
      activity: json['activity'] as Map<String, dynamic>? ?? {},
      user: FriendUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  String get action => activity['action']?.toString() ?? '';
  DateTime? get insertedAt =>
      activity['inserted_at'] != null ? DateTime.tryParse(activity['inserted_at']) : null;
}

/// Entrée du leaderboard amis
class FriendLeaderboardEntry {
  final int id;
  final String name;
  final int wins;

  const FriendLeaderboardEntry({required this.id, required this.name, required this.wins});

  factory FriendLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return FriendLeaderboardEntry(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      name: json['name'] ?? 'Inconnu',
      wins: json['wins'] ?? 0,
    );
  }
}

/// Joueur trouvé par recherche
class PlayerSearchResult {
  final int id;
  final String name;
  final String? phone;

  const PlayerSearchResult({required this.id, required this.name, this.phone});

  factory PlayerSearchResult.fromJson(Map<String, dynamic> json) {
    return PlayerSearchResult(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      name: json['name'] ?? 'Inconnu',
      phone: json['phone'],
    );
  }
}

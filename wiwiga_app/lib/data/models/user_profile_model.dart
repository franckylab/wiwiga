/// Modèle étendu pour le profil utilisateur avec stats et achievements
class UserProfile {
  final String id;
  final String phone;
  final String? email;
  final String? username;
  final double balance;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  
  // Stats de jeu
  final int gamesPlayed;
  final int wins;
  final int losses;
  final double totalWinnings;
  final double totalBets;
  final int currentStreak;
  final int bestStreak;
  final int xpPoints;
  final String rankTier; // bronze, silver, gold, platinum, diamond
  
  // Achievements
  final List<Achievement> achievements;
  
  // Historique récent
  final List<RecentGame> recentGames;

  const UserProfile({
    required this.id,
    required this.phone,
    this.email,
    this.username,
    required this.balance,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalWinnings = 0,
    this.totalBets = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.xpPoints = 0,
    this.rankTier = 'bronze',
    this.achievements = const [],
    this.recentGames = const [],
  });

  double get winRate => gamesPlayed > 0 ? (wins / gamesPlayed * 100) : 0;
  
  String get rankLabel {
    switch (rankTier) {
      case 'legend': return 'Légende';
      case 'diamond': return 'Diamant';
      case 'platinum': return 'Platine';
      case 'gold': return 'Or';
      case 'silver': return 'Argent';
      case 'bronze': return 'Bronze';
      default: return 'Bronze';
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      username: json['username'],
      balance: (json['balance'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? false,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      gamesPlayed: json['games_played'] ?? 0,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      totalWinnings: (json['total_winnings'] ?? 0).toDouble(),
      totalBets: (json['total_bets'] ?? 0).toDouble(),
      currentStreak: json['current_streak'] ?? 0,
      bestStreak: json['best_streak'] ?? 0,
      xpPoints: json['xp_points'] ?? 0,
      rankTier: json['rank_tier'] ?? 'bronze',
      achievements: (json['achievements'] as List?)
          ?.map((a) => Achievement.fromJson(a))
          .toList() ?? [],
      recentGames: (json['recent_games'] as List?)
          ?.map((g) => RecentGame.fromJson(g))
          .toList() ?? [],
    );
  }

  UserProfile copyWith({
    String? username,
    String? email,
    double? balance,
    int? gamesPlayed,
    int? wins,
    int? losses,
    double? totalWinnings,
    int? xpPoints,
    String? rankTier,
    List<Achievement>? achievements,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      email: email ?? this.email,
      username: username ?? this.username,
      balance: balance ?? this.balance,
      isActive: isActive,
      isVerified: isVerified,
      createdAt: createdAt,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      totalWinnings: totalWinnings ?? this.totalWinnings,
      totalBets: totalBets,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      xpPoints: xpPoints ?? this.xpPoints,
      rankTier: rankTier ?? this.rankTier,
      achievements: achievements ?? this.achievements,
      recentGames: recentGames,
    );
  }
}

/// Achievement / Badge débloqué
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final String tier; // bronze, silver, gold, diamond

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
    required this.tier,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'trophy',
      isUnlocked: json['is_unlocked'] ?? false,
      unlockedAt: json['unlocked_at'] != null 
          ? DateTime.tryParse(json['unlocked_at']) 
          : null,
      tier: json['tier'] ?? 'bronze',
    );
  }
}

/// Partie récente dans l'historique
class RecentGame {
  final String id;
  final String gameType;
  final String result; // win, loss, draw
  final double betAmount;
  final double winnings;
  final DateTime playedAt;
  final int? predictedSum;
  final int? actualSum;

  const RecentGame({
    required this.id,
    required this.gameType,
    required this.result,
    required this.betAmount,
    required this.winnings,
    required this.playedAt,
    this.predictedSum,
    this.actualSum,
  });

  factory RecentGame.fromJson(Map<String, dynamic> json) {
    return RecentGame(
      id: json['id'] ?? '',
      gameType: json['game_type'] ?? 'dice',
      result: json['result'] ?? 'loss',
      betAmount: (json['bet_amount'] ?? 0).toDouble(),
      winnings: (json['winnings'] ?? 0).toDouble(),
      playedAt: DateTime.tryParse(json['played_at'] ?? '') ?? DateTime.now(),
      predictedSum: json['predicted_sum'],
      actualSum: json['actual_sum'],
    );
  }
}

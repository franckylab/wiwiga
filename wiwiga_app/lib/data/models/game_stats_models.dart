// ============================================================
// Fichier: game_stats_models.dart
// Description: Modèles stats, classement, activité et règles d'un jeu
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

/// Statistiques globales d'un jeu (GET /api/games/:type/stats)
/// Valeurs monétaires du backend (centimes) converties en wiga côté UI (1 FCFA=1 wiga, taux 10)
class GameGlobalStats {
  final int playersOnline;
  final int matchesToday;
  final int totalDistributedToday; // wiga (backend centimes converti)
  final int biggestWinToday; // wiga (backend centimes converti)
  final int totalPlayers;

  const GameGlobalStats({
    required this.playersOnline,
    required this.matchesToday,
    required this.totalDistributedToday,
    required this.biggestWinToday,
    required this.totalPlayers,
  });

  factory GameGlobalStats.fromJson(Map<String, dynamic> json) {
    return GameGlobalStats(
      playersOnline: (json['players_online'] ?? 0) as int,
      matchesToday: (json['matches_today'] ?? 0) as int,
      totalDistributedToday: (json['total_distributed_today'] ?? 0) as int,
      biggestWinToday: (json['biggest_win_today'] ?? 0) as int,
      totalPlayers: (json['total_players'] ?? 0) as int,
    );
  }
}

/// Entrée de classement (top N)
class GameLeaderboardEntry {
  final int userId;
  final String name;
  final int value; // valeur de la métrique (wins, total_won, biggest_win)
  final int wins;
  final int rank;

  const GameLeaderboardEntry({
    required this.userId,
    required this.name,
    required this.value,
    required this.wins,
    required this.rank,
  });

  factory GameLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return GameLeaderboardEntry(
      userId: (json['user_id'] ?? 0) as int,
      name: json['name'] ?? 'Joueur',
      value: (json['value'] ?? 0) as int,
      wins: (json['wins'] ?? 0) as int,
      rank: (json['rank'] ?? 0) as int,
    );
  }
}

/// Classement complet (GET /api/games/:type/leaderboard)
class GameLeaderboard {
  final String metric; // wins | total_won | biggest_win
  final String period; // day | week | month | all
  final List<GameLeaderboardEntry> entries;
  final int? myRank;
  final int? myValue;

  const GameLeaderboard({
    required this.metric,
    required this.period,
    required this.entries,
    this.myRank,
    this.myValue,
  });

  factory GameLeaderboard.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List? ?? [];
    return GameLeaderboard(
      metric: json['metric'] ?? 'wins',
      period: json['period'] ?? 'all',
      entries: rawEntries
          .map((e) => GameLeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      myRank: json['my_rank'] as int?,
      myValue: json['my_value'] as int?,
    );
  }
}

/// Statistiques personnelles (GET /api/games/:type/my-stats)
/// Montants en wiga (backend centimes convertis)
class MyGameStats {
  final int matchesPlayed;
  final int wins;
  final int losses;
  final int totalWagered; // wiga
  final int totalWonNet; // wiga
  final int biggestWin; // wiga
  final int currentStreak;
  final int bestStreak;
  final double winRate; // pourcentage 0-100
  final DateTime? lastPlayedAt;

  const MyGameStats({
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.totalWagered,
    required this.totalWonNet,
    required this.biggestWin,
    required this.currentStreak,
    required this.bestStreak,
    required this.winRate,
    this.lastPlayedAt,
  });

  factory MyGameStats.fromJson(Map<String, dynamic> json) {
    return MyGameStats(
      matchesPlayed: (json['matches_played'] ?? 0) as int,
      wins: (json['wins'] ?? 0) as int,
      losses: (json['losses'] ?? 0) as int,
      totalWagered: (json['total_wagered'] ?? 0) as int,
      totalWonNet: (json['total_won_net'] ?? 0) as int,
      biggestWin: (json['biggest_win'] ?? 0) as int,
      currentStreak: (json['current_streak'] ?? 0) as int,
      bestStreak: (json['best_streak'] ?? 0) as int,
      winRate: ((json['win_rate'] ?? 0) as num).toDouble(),
      lastPlayedAt: json['last_played_at'] != null
          ? DateTime.tryParse(json['last_played_at'].toString())
          : null,
    );
  }
}

/// Événement du flux d'activité public (GET /api/games/:type/activity)
class GameActivityEvent {
  final int id;
  final int userId;
  final String name;
  final String eventType; // 'win'
  final int amount; // wiga
  final DateTime? insertedAt;

  const GameActivityEvent({
    required this.id,
    required this.userId,
    required this.name,
    required this.eventType,
    required this.amount,
    this.insertedAt,
  });

  factory GameActivityEvent.fromJson(Map<String, dynamic> json) {
    return GameActivityEvent(
      id: (json['id'] ?? 0) as int,
      userId: (json['user_id'] ?? 0) as int,
      name: json['name'] ?? 'Joueur',
      eventType: json['event_type'] ?? 'win',
      amount: (json['amount'] ?? 0) as int,
      insertedAt: json['inserted_at'] != null
          ? DateTime.tryParse(json['inserted_at'].toString())
          : null,
    );
  }
}

/// Règle de jeu formatée (GET /api/games/:type/rules)
class GameRuleInfo {
  final String ruleType; // 'normal' | 'cible'
  final String name;
  final String description;
  final Map<String, dynamic> config;

  const GameRuleInfo({
    required this.ruleType,
    required this.name,
    required this.description,
    required this.config,
  });

  factory GameRuleInfo.fromJson(Map<String, dynamic> json) {
    return GameRuleInfo(
      ruleType: json['rule_type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }

  // === Nombre de sets (source serveur game_rules.config) ===
  // Le client n'invente jamais ces valeurs : elles pilotent l'affichage
  // (slider fixe vs carte aléatoire) et restent cohérentes avec le moteur.

  int _configInt(String key, int fallback) {
    final value = config[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  /// Bornes de validation du choix joueur.
  int get minSets => _configInt('min_sets', 1);
  int get maxSets {
    final max = _configInt('max_sets', 11);
    final min = minSets;
    return max >= min ? max : min;
  }

  /// Valeur fixe (mode fixe) : défaut serveur, pas 3 codé en dur.
  int get defaultSets => _configInt('default_sets', 3).clamp(minSets, maxSets);

  /// Mode de détermination : 'fixed' | 'random' (défaut fixe).
  String get setsMode {
    final mode = (config['sets_mode']?.toString() ?? 'fixed').trim();
    return mode == 'random' ? 'random' : 'fixed';
  }

  bool get isRandomSets => setsMode == 'random';

  /// Intervalle du tirage serveur (mode aléatoire), borné par min/max.
  int get setsRandomMin =>
      _configInt('sets_random_min', minSets).clamp(minSets, maxSets);
  int get setsRandomMax =>
      _configInt('sets_random_max', maxSets).clamp(setsRandomMin, maxSets);

  /// Libellé d'affichage : "BO3" ou "Aléatoire (1–5)".
  String get setsLabel {
    if (isRandomSets) {
      if (setsRandomMin == setsRandomMax) return 'BO$setsRandomMin';
      return 'Aléatoire ($setsRandomMin–$setsRandomMax)';
    }
    return 'BO$defaultSets';
  }
}

/// Astuce de jeu (GET /api/games/:type/tips)
class GameTip {
  final String title;
  final String body;

  const GameTip({required this.title, required this.body});

  factory GameTip.fromJson(Map<String, dynamic> json) {
    return GameTip(
      title: json['title'] ?? '',
      body: json['body'] ?? '',
    );
  }
}

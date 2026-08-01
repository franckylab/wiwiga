import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';

/// Provider du profil utilisateur avec données mockées (à connecter au backend)
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>(
  (ref) => UserProfileNotifier(),
);

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(_mockProfile);

  static final _mockProfile = UserProfile(
    id: 'user_001',
    phone: '+237 699 999 999',
    email: 'franck@wiwiga.com',
    username: 'Franck_CH',
    balance: 350000,
    isActive: true,
    isVerified: true,
    createdAt: DateTime(2025, 6, 15),
    gamesPlayed: 156,
    wins: 97,
    losses: 59,
    totalWinnings: 2450000,
    totalBets: 1200000,
    currentStreak: 5,
    bestStreak: 12,
    xpPoints: 8450,
    rankTier: 'gold',
    achievements: [
      Achievement(
        id: 'first_win',
        name: 'Première Victoire',
        description: 'Gagner sa première partie',
        icon: 'emoji_events',
        isUnlocked: true,
        unlockedAt: DateTime(2025, 6, 20),
        tier: 'bronze',
      ),
      Achievement(
        id: 'streak_5',
        name: 'En Feu',
        description: '5 victoires consécutives',
        icon: 'local_fire_department',
        isUnlocked: true,
        unlockedAt: DateTime(2025, 8, 10),
        tier: 'silver',
      ),
      Achievement(
        id: 'big_winner',
        name: 'Gros Gain',
        description: 'Gagner plus de 1 000 000 jetons en une partie',
        icon: 'attach_money',
        isUnlocked: true,
        unlockedAt: DateTime(2025, 9, 5),
        tier: 'gold',
      ),
      Achievement(
        id: 'veteran',
        name: 'Vétéran',
        description: 'Jouer 100 parties',
        icon: 'military_tech',
        isUnlocked: true,
        unlockedAt: DateTime(2025, 10, 1),
        tier: 'gold',
      ),
      const Achievement(
        id: 'diamond_roll',
        name: 'Roulage de Diamant',
        description: 'Gagner avec une prédiction exacte de 2 ou 12',
        icon: 'diamond',
        isUnlocked: false,
        tier: 'diamond',
      ),
      const Achievement(
        id: 'champion',
        name: 'Champion',
        description: 'Gagner un tournoi',
        icon: 'workspace_premium',
        isUnlocked: false,
        tier: 'diamond',
      ),
    ],
    recentGames: [
      RecentGame(
        id: 'g1',
        gameType: 'dice',
        result: 'win',
        betAmount: 50000,
        winnings: 95000,
        playedAt: DateTime.now().subtract(const Duration(hours: 2)),
        predictedSum: 7,
        actualSum: 7,
      ),
      RecentGame(
        id: 'g2',
        gameType: 'dice',
        result: 'win',
        betAmount: 30000,
        winnings: 57000,
        playedAt: DateTime.now().subtract(const Duration(hours: 5)),
        predictedSum: 8,
        actualSum: 8,
      ),
      RecentGame(
        id: 'g3',
        gameType: 'dice',
        result: 'loss',
        betAmount: 25000,
        winnings: 0,
        playedAt: DateTime.now().subtract(const Duration(hours: 8)),
        predictedSum: 6,
        actualSum: 9,
      ),
      RecentGame(
        id: 'g4',
        gameType: 'dice',
        result: 'win',
        betAmount: 40000,
        winnings: 76000,
        playedAt: DateTime.now().subtract(const Duration(days: 1)),
        predictedSum: 10,
        actualSum: 10,
      ),
      RecentGame(
        id: 'g5',
        gameType: 'dice',
        result: 'loss',
        betAmount: 20000,
        winnings: 0,
        playedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        predictedSum: 5,
        actualSum: 8,
      ),
    ],
  );

  void updateUsername(String newUsername) {
    state = state.copyWith(username: newUsername);
  }

  void refreshProfile() {
    // Simule un refresh depuis le backend
    state = state;
  }
}

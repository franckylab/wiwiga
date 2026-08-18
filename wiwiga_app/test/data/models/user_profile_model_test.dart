import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/models/user_profile_model.dart';

void main() {
  group('UserProfile', () {
    test('fromJson parse les stats backend', () {
      final profile = UserProfile.fromJson({
        'id': 'user-123',
        'phone': '+237690000000',
        'balance': 5000.0,
        'is_active': true,
        'is_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
        'games_played': 42,
        'wins': 28,
        'losses': 12,
        'total_winnings': 15000.0,
        'total_bets': 8000.0,
        'current_streak': 3,
        'best_streak': 7,
        'xp_points': 1500,
        'rank_tier': 'silver',
      });

      expect(profile.gamesPlayed, 42);
      expect(profile.wins, 28);
      expect(profile.xpPoints, 1500);
      expect(profile.rankTier, 'silver');
      expect(profile.rankLabel, 'Argent');
      expect(profile.currentStreak, 3);
    });

    test('winRate calcule correctement', () {
      final profile = UserProfile.fromJson({
        'id': '1',
        'phone': '',
        'balance': 0,
        'is_active': true,
        'is_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
        'games_played': 100,
        'wins': 65,
      });

      expect(profile.winRate, 65.0);
    });

    test('winRate retourne 0 si aucune partie', () {
      final profile = UserProfile.fromJson({
        'id': '1',
        'phone': '',
        'balance': 0,
        'is_active': true,
        'is_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(profile.winRate, 0.0);
    });

    test('rankLabel gère tous les tiers incluant legend', () {
      final tiers = {
        'legend': 'Légende',
        'diamond': 'Diamant',
        'platinum': 'Platine',
        'gold': 'Or',
        'silver': 'Argent',
        'bronze': 'Bronze',
        'unknown': 'Bronze', // fallback
      };

      for (final entry in tiers.entries) {
        final profile = UserProfile.fromJson({
          'id': '1',
          'phone': '',
          'balance': 0,
          'is_active': true,
          'is_verified': true,
          'created_at': '2026-01-01T00:00:00Z',
          'rank_tier': entry.key,
        });
        expect(profile.rankLabel, entry.value);
      }
    });

    test('copyWith met à jour les champs', () {
      final profile = UserProfile.fromJson({
        'id': '1',
        'phone': '',
        'balance': 1000,
        'is_active': true,
        'is_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
        'xp_points': 500,
        'rank_tier': 'bronze',
      });

      final updated = profile.copyWith(
        xpPoints: 2500,
        rankTier: 'gold',
      );

      expect(updated.xpPoints, 2500);
      expect(updated.rankTier, 'gold');
      expect(updated.rankLabel, 'Or');
    });
  });
}

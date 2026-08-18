import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/screens/leaderboard/leaderboard_screen.dart';

void main() {
  group('LeaderboardScreen', () {
    test('LeaderboardScreen peut être instancié', () {
      const screen = LeaderboardScreen();
      expect(screen, isNotNull);
    });

    test('les providers de state existent', () {
      // Vérifier que les providers sont définis
      expect(leaderboardGameTypeProvider, isNotNull);
      expect(leaderboardPeriodProvider, isNotNull);
      expect(leaderboardMetricProvider, isNotNull);
    });
  });
}

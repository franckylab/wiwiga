import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/widgets/neon/neon_business.dart';

void main() {
  group('GameStatus enum', () {
    test('contient tous les statuts attendus', () {
      expect(GameStatus.values.length, 5);
      expect(GameStatus.values, contains(GameStatus.waiting));
      expect(GameStatus.values, contains(GameStatus.inProgress));
      expect(GameStatus.values, contains(GameStatus.finished));
      expect(GameStatus.values, contains(GameStatus.cancelled));
      expect(GameStatus.values, contains(GameStatus.comingSoon));
    });
  });
}

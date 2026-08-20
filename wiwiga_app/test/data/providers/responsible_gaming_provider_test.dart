import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/providers/responsible_gaming_provider.dart';

void main() {
  group('ResponsibleGamingState', () {
    test('état initial par défaut', () {
      const state = ResponsibleGamingState();
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.dailyDepositLimit, isNull);
      expect(state.dailyLossLimit, isNull);
      expect(state.dailyWagerLimit, isNull);
      expect(state.sessionTimeLimitMinutes, isNull);
      expect(state.realityCheckIntervalMinutes, isNull);
      expect(state.selfExclusionUntil, isNull);
      expect(state.selfExclusionReason, isNull);
      expect(state.isSelfExcluded, false);
    });

    test('copyWith met à jour les champs', () {
      const state = ResponsibleGamingState(
        dailyDepositLimit: 50000,
        dailyLossLimit: 10000,
        dailyWagerLimit: 100000,
        sessionTimeLimitMinutes: 120,
        realityCheckIntervalMinutes: 30,
      );

      final updated = state.copyWith(
        dailyLossLimit: 20000,
        isLoading: true,
      );

      expect(updated.dailyLossLimit, 20000);
      expect(updated.dailyDepositLimit, 50000); // inchangé
      expect(updated.isLoading, true);
    });

    test('copyWith clearError efface l\'erreur', () {
      const state = ResponsibleGamingState(error: 'Erreur réseau');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearSelfExclusion efface l\'auto-exclusion', () {
      final state = ResponsibleGamingState(
        isSelfExcluded: true,
        selfExclusionUntil: DateTime(2027, 1, 1),
        selfExclusionReason: 'Besoin de pause',
      );
      final cleared = state.copyWith(clearSelfExclusion: true);
      expect(cleared.isSelfExcluded, false);
      expect(cleared.selfExclusionUntil, isNull);
      expect(cleared.selfExclusionReason, isNull);
    });

    test('dailyLossLimitLabel avec limite', () {
      const state = ResponsibleGamingState(dailyLossLimit: 25000);
      expect(state.dailyLossLimitLabel, '25000 FCFA');
    });

    test('dailyLossLimitLabel sans limite', () {
      const state = ResponsibleGamingState();
      expect(state.dailyLossLimitLabel, 'Pas de limite');
    });

    test('selfExclusionLabel désactivé', () {
      const state = ResponsibleGamingState();
      expect(state.selfExclusionLabel, 'Désactivé');
    });

    test('selfExclusionLabel active sans date', () {
      const state = ResponsibleGamingState(isSelfExcluded: true);
      expect(state.selfExclusionLabel, 'Active');
    });

    test('selfExclusionLabel permanente (>365 jours)', () {
      final state = ResponsibleGamingState(
        isSelfExcluded: true,
        selfExclusionUntil: DateTime.now().add(const Duration(days: 400)),
      );
      expect(state.selfExclusionLabel, 'Permanente');
    });

    test('selfExclusionLabel avec date future', () {
      final futureDate = DateTime(2027, 6, 15);
      final state = ResponsibleGamingState(
        isSelfExcluded: true,
        selfExclusionUntil: futureDate,
      );
      expect(state.selfExclusionLabel, contains('2027'));
    });
  });
}

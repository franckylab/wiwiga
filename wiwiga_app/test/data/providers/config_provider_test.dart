import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/providers/config_provider.dart';

void main() {
  group('FeatureConfigModel', () {
    test('fromJson parse les valeurs admin', () {
      final config = FeatureConfigModel.fromJson({
        'maintenance_mode': false,
        'registration_enabled': true,
        'min_deposit_amount': 1000,
        'max_deposit_amount': 500000,
        'min_withdrawal_amount': 2000,
        'max_withdrawal_amount': 1000000,
        'kyc_required_threshold': 100000,
        'max_games_per_user': 50,
        'reality_check_interval_ms': 1800000,
        'support_email': 'support@wiwiga.com',
      });

      expect(config.maintenanceMode, false);
      expect(config.registrationEnabled, true);
      expect(config.minDepositAmount, 1000);
      expect(config.maxDepositAmount, 500000);
      expect(config.realityCheckIntervalMs, 1800000);
      expect(config.maxGamesPerUser, 50);
      expect(config.supportEmail, 'support@wiwiga.com');
    });

    test('valeurs par défaut si champs manquants', () {
      final config = FeatureConfigModel.fromJson({});

      expect(config.maintenanceMode, false);
      expect(config.registrationEnabled, true);
      expect(config.minDepositAmount, 500);
      expect(config.maxDepositAmount, 1000000);
    });
  });

  group('TokensConfigModel', () {
    test('fromJson parse les valeurs admin', () {
      final config = TokensConfigModel.fromJson({
        'exchange_rate': 10,
        'exchange_fee_percent': 2.5,
        'exchange_fixed_fee': 5,
        'daily_purchase_limit': 50000,
        'daily_transfer_limit': 10000,
        'gift_fee_percent': 5.0,
        'dice_min_bet': 10,
        'cards_min_bet': 20,
      });

      expect(config.exchangeRate, 10);
      expect(config.exchangeFeePercent, 2.5);
      expect(config.dailyPurchaseLimit, 50000);
      expect(config.dailyTransferLimit, 10000);
      expect(config.diceMinBet, 10);
    });
  });

  group('PaymentsConfigModel', () {
    test('fromJson parse les providers', () {
      final config = PaymentsConfigModel.fromJson({
        'providers': {
          'campay': {
            'is_enabled': true,
            'deposit_min': 500,
            'deposit_max': 1000000,
            'withdrawal_fee_percent': 0.0,
          },
          'orange_money': {
            'is_enabled': false,
            'deposit_min': 1000,
            'deposit_max': 500000,
            'withdrawal_fee_percent': 1.5,
          },
        },
      });

      expect(config.providers.length, 2);
      expect(config.providers['campay']?.isEnabled, true);
      expect(config.providers['campay']?.depositMin, 500);
      expect(config.providers['orange_money']?.isEnabled, false);
    });
  });

  group('GamesConfigModel', () {
    test('fromJson parse les configs par type de jeu', () {
      final config = GamesConfigModel.fromJson({
        'game_types': {
          'dice': {
            'min_bet': 100,
            'max_bet': 50000,
            'commission_percent': 5.0,
            'max_players': 6,
            'is_active': true,
          },
          'lottery': {
            'min_bet': 500,
            'max_bet': 100000,
            'commission_percent': 10.0,
            'max_players': 100,
            'is_active': true,
          },
        },
      });

      expect(config.gameTypes.length, 2);
      expect(config.gameTypes['dice']?.minBet, 100);
      expect(config.gameTypes['dice']?.maxPlayers, 6);
      expect(config.gameTypes['lottery']?.commissionPercent, 10.0);
      expect(config.gameTypes['unknown'], isNull);
    });
  });
}

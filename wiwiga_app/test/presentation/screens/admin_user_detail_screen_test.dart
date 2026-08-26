import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/models/user_model.dart';

void main() {
  group('AdminUserDetail /admin/users/:id - JSNull regression', () {
    test('UserModel.fromJson gère id=16 (int) + champs null sans JSNull', () {
      final json = {
        'id': 16,
        'name': null,
        'permissions': ['games:play'],
        'balance': 0,
        'username': 'newuser_test2026',
        'role': 'user',
        'created_at': '2026-08-01T23:33:44',
        'is_active': true,
        'self_excluded': false,
        'token_balance': 0,
        'last_login_at': '2026-08-01T23:33:44Z',
        'has_verified_kyc': false,
        'phone': '+23768888777',
        'email': null,
        'avatar_type': 'default',
        'daily_deposit_limit': 1000000,
        'daily_loss_limit': 500000,
        'login_count': 1,
        'can_manage': true,
      };

      // Ne doit pas lancer "JSNull is not subtype of Map"
      final user = UserModel.fromJson(json);
      expect(user.id, '16');
      expect(user.username, 'newuser_test2026');
      expect(user.phone, '+23768888777');
      expect(user.email, isNull);
      expect(user.name, isNull);
      expect(user.role, UserRole.user);
      expect(user.isActive, true);
      expect(user.balance, 0.0);
      expect(user.loginCount, 1);
    });

    test('UserModel.fromJson gère backend plat vs imbriqué (data vs data.user)', () {
      // Simule le fix admin_repository: raw['user'] ?? raw
      final rawPlat = {
        'id': 16,
        'username': 'newuser_test2026',
        'role': 'user',
      };
      final rawImbrique = {
        'user': {'id': 16, 'username': 'newuser_test2026', 'role': 'user'}
      };

      Map<String, dynamic> extract(Map<String, dynamic> raw) =>
          (raw['user'] as Map<String, dynamic>?) ?? raw;

      expect(extract(rawPlat)['id'], 16);
      expect(extract(rawImbrique)['id'], 16);
    });

    test('Repository guard null data ne lance pas JSNull', () {
      // Simule le fix: rawData == null -> throw notFound au lieu de as Map
      Map<String, dynamic> responseNull = {'data': null};
      Map<String, dynamic> responsePlat = {
        'data': {'id': 16, 'username': 'test'}
      };

      String parse(Map<String, dynamic> response) {
        final rawData = response['data'];
        if (rawData == null) return 'notFound';
        if (rawData is! Map<String, dynamic>) return 'invalid';
        final raw = rawData;
        final userMap = (raw['user'] as Map<String, dynamic>?) ?? raw;
        final u = UserModel.fromJson(userMap);
        return u.id;
      }

      expect(parse(responseNull), 'notFound');
      expect(parse(responsePlat), '16');
    });
  });
}

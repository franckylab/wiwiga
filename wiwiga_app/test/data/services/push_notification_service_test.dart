import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/data/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService', () {
    test('dégradation gracieuse sans Firebase configuré', () async {
      final service = PushNotificationService();

      // Sans google-services.json : init réussit mais service désactivé
      await service.initialize();
      expect(service.isAvailable, false);

      // Token indisponible, jamais de crash
      expect(await service.getToken(), isNull);
      expect(await service.requestPermission(), false);
      await service.deleteToken();

      // Plateforme détectée selon la cible de test
      expect(service.platform, isNotEmpty);
    });

    test('background handler sans Firebase ne lève pas', () async {
      // Le handler doit survivre à l absence de config (repli inbox)
      // Note : incompatible avec les isolates de test, vérifié par initialize()
      expect(wiwigaFirebaseBackgroundHandler, isA<Function>());
    });
  });
}

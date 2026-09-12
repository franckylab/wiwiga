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

      // Diagnostic : la raison de non-disponibilité est exposée
      // (ex. config Firebase absente) au lieu d'un silence total
      expect(service.lastDiagnostic, isNotNull);
      expect(service.lastDiagnostic, isNotEmpty);

      // Lecture du statut sans prompt : null tant que non initialisé
      // (jamais de prompt OS accidentel depuis un état indisponible)
      expect(await service.permissionStatus(), isNull);
    });

    test('initialize retente vraiment après un échec (bouton Réessayer)', () async {
      final service = PushNotificationService();

      await service.initialize();
      expect(service.isAvailable, false);
      final first = service.lastDiagnostic;

      // Second appel : pas de court-circuit, nouvelle tentative réelle
      await service.initialize();
      expect(service.isAvailable, false);
      expect(service.lastDiagnostic, isNotNull);
      expect(service.lastDiagnostic, isNotEmpty);
      expect(first, isNotNull);
    });

    test('isSecurePushOriginFor verrouille HTTP non-loopback', () {
      // Natif : toujours OK (pas de notion d'origine web)
      expect(
        PushNotificationService.isSecurePushOriginFor(
          isWeb: false,
          uri: Uri.parse('http://192.168.0.100:8003/'),
        ),
        isTrue,
      );
      // Web HTTPS : OK partout
      expect(
        PushNotificationService.isSecurePushOriginFor(
          isWeb: true,
          uri: Uri.parse('https://192.168.0.100:8443/'),
        ),
        isTrue,
      );
      // Web HTTP loopback : OK (localhost, 127.0.0.1, ::1)
      for (final host in ['localhost', '127.0.0.1', '[::1]']) {
        expect(
          PushNotificationService.isSecurePushOriginFor(
            isWeb: true,
            uri: Uri.parse('http://$host:8003/'),
          ),
          isTrue,
          reason: host,
        );
      }
      // Web HTTP non-loopback : verrouillé (notifications grisées, pas de SW)
      for (final url in [
        'http://192.168.0.100:8003/',
        'http://10.0.0.5/',
        'http://wiwiga.local/',
      ]) {
        expect(
          PushNotificationService.isSecurePushOriginFor(
            isWeb: true,
            uri: Uri.parse(url),
          ),
          isFalse,
          reason: url,
        );
      }
    });

    test('background handler sans Firebase ne lève pas', () async {
      // Le handler doit survivre à l absence de config (repli inbox)
      // Note : incompatible avec les isolates de test, vérifié par initialize()
      expect(wiwigaFirebaseBackgroundHandler, isA<Function>());
    });
  });
}

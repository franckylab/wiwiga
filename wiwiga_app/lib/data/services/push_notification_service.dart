// ============================================================
// Fichier: push_notification_service.dart
// Description: Réception push FCM + notifications locales.
//              Dégradation gracieuse si Firebase non configuré
//              (google-services.json absent → service désactivé).
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Handler background (obligatoirement top-level pour FCM).
@pragma('vm:entry-point')
Future<void> wiwigaFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    // Options explicites si configurées, sinon config native
    // (google-services.json / GoogleService-Info.plist).
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Firebase non configuré : rien à faire en background
  }
}

/// Callback token FCM (enregistrement backend).
typedef FcmTokenCallback = Future<void> Function(String token);

/// Callback tap sur notification (navigation).
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Callback message reçu au premier plan (toutes plateformes).
/// L'appelant rafraîchit l'inbox et affiche une surface in-app
/// (SnackBar sur Web, où il n'existe pas de notification locale).
typedef ForegroundMessageCallback = Future<void> Function(
    RemoteMessage message,);

/// Service push FCM : permissions, token, foreground/background, tap.
class PushNotificationService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _available = false;
  String? _lastDiagnostic;
  FcmTokenCallback? _onToken;
  NotificationTapCallback? _onTap;
  ForegroundMessageCallback? _onForeground;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'wiwiga_high',
    'WIWIGA',
    description: 'Annonces, gains et alertes de sécurité',
    importance: Importance.high,
  );

  /// Vrai si Firebase est configuré et utilisable.
  bool get isAvailable => _available;

  /// Dernier diagnostic lisible (raison de non-disponibilité ou état OK).
  /// Jamais de secret : le token éventuel est tronqué.
  /// Ex. "non configuré : google-services.json absent (Android)".
  String? get lastDiagnostic => _lastDiagnostic;

  /// Initialise Firebase + plugin local. N'échoue jamais.
  ///
  /// Réappelable : le flag n'est posé qu'après succès, donc la carte
  /// "Réessayer" des Préférences retente vraiment l'initialisation.
  /// Un `duplicate-app` (hot restart : Dart réinitialisé mais Firebase
  /// natif/JS déjà initialisé) est un succès, pas un échec.
  Future<void> initialize({
    FcmTokenCallback? onToken,
    NotificationTapCallback? onTap,
    ForegroundMessageCallback? onForeground,
  }) async {
    if (_initialized) return;
    _onToken = onToken;
    _onTap = onTap;
    _onForeground = onForeground;

    try {
      // Config explicite (build --dart-define) prioritaire, sinon config
      // native (google-services.json côté Android). Échec → push désactivé,
      // l'inbox in_app + WebSocket prennent le relais.
      if (DefaultFirebaseOptions.isConfigured) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _setDiagnostic(
            'OK : options explicites (${DefaultFirebaseOptions.projectId})',);
      } else {
        await Firebase.initializeApp();
        _setDiagnostic('OK : config native (google-services.json / plist)');
      }
      _available = true;
      _initialized = true;
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _available = true;
        _initialized = true;
        _setDiagnostic(
            'OK : déjà initialisé (${DefaultFirebaseOptions.projectId})',);
      } else {
        // Erreur réelle exposée (écran authentifié, aucun secret) : sans
        // elle, tout échec d'init est indiscernable ("config absente").
        _available = false;
        _setDiagnostic('non configuré : init Firebase rejetée (${e.code} ${e.message})');
        return;
      }
    } catch (e) {
      // Pas de google-services.json / config web : push désactivé,
      // l'inbox in_app + WebSocket prennent le relais.
      _available = false;
      _setDiagnostic('non configuré : init Firebase impossible ($e)');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(wiwigaFirebaseBackgroundHandler);

    // Notifications locales (foreground Android/iOS, pas web)
    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Renouvellement du token → re-enregistrement backend
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_onToken?.call(token));
    });

    // Message en foreground → locale (natif) + surface in-app (appelant,
    // indispensable sur Web : FCM n'affiche rien tout seul au 1er plan).
    FirebaseMessaging.onMessage.listen((message) async {
      await _showForeground(message);
      try {
        await _onForeground?.call(message);
      } catch (_) {
        // Surface in-app optionnelle : jamais bloquante
      }
    });

    // Tap (app ouverte en fond) → navigation
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onTap?.call(message.data);
    });

    // Tap ayant ouvert l'app depuis terminée
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onTap?.call(initial.data);
    }
  }

  /// Demande la permission (iOS/web, no-op Android < 13).
  Future<bool> requestPermission() async {
    if (!_available) {
      _setDiagnostic('permission ignorée : Firebase non configuré');
      return false;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      _setDiagnostic(granted
          ? 'permission accordée'
          : 'permission refusée par le système',);
      return granted;
    } catch (_) {
      _setDiagnostic('permission : échec de la demande');
      return false;
    }
  }

  /// Statut courant de la permission OS, SANS déclencher de prompt.
  /// Permet de distinguer "jamais demandé" (le prompt s'affichera) de
  /// "bloqué" (le navigateur n'affichera plus jamais de prompt : il faut
  /// guider l'utilisateur vers le cadenas / réglages). null si indisponible.
  Future<AuthorizationStatus?> permissionStatus() async {
    if (!_available) return null;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (_) {
      return null;
    }
  }

  /// Token FCM courant (null si indisponible).
  /// Web : clé VAPID via `--dart-define=FCM_VAPID_KEY=...`.
  Future<String?> getToken() async {
    if (!_available) {
      _setDiagnostic('token indisponible : Firebase non configuré');
      return null;
    }
    try {
      const vapidKey =
          String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
      if (kIsWeb && vapidKey.isEmpty) {
        _setDiagnostic(
            'token indisponible : FCM_VAPID_KEY absente (rebuild web avec --dart-define=FCM_VAPID_KEY=... requis)',);
        return null;
      }
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? vapidKey : null,
      );
      if (token == null || token.isEmpty) {
        _setDiagnostic(
            'token indisponible : Firebase n\u2019a retourné aucun token (permission ?)',);
      } else {
        _setDiagnostic(
            'token obtenu (${token.substring(0, token.length > 12 ? 12 : token.length)}…)',);
      }
      return token;
    } catch (_) {
      _setDiagnostic(
          'token indisponible : erreur Firebase (permission refusée ?)',);
      return null;
    }
  }

  /// Supprime le token local (logout).
  Future<void> deleteToken() async {
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  /// Plateforme pour l'enregistrement backend (android/ios/web).
  String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  /// Mémorise + journalise le diagnostic (debug uniquement en console).
  void _setDiagnostic(String message) {
    _lastDiagnostic = message;
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint('[Push] $message');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || kIsWeb) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title ?? 'WIWIGA',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['notification_id']?.toString(),
    );
  }

  void _onLocalTap(NotificationResponse response) {
    final id = response.payload;
    _onTap?.call(id == null ? {} : {'notification_id': id});
  }
}

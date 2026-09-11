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

/// Service push FCM : permissions, token, foreground/background, tap.
class PushNotificationService {
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _available = false;
  FcmTokenCallback? _onToken;
  NotificationTapCallback? _onTap;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'wiwiga_high',
    'WIWIGA',
    description: 'Annonces, gains et alertes de sécurité',
    importance: Importance.high,
  );

  /// Vrai si Firebase est configuré et utilisable.
  bool get isAvailable => _available;

  /// Initialise Firebase + plugin local. N'échoue jamais.
  Future<void> initialize({
    FcmTokenCallback? onToken,
    NotificationTapCallback? onTap,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _onToken = onToken;
    _onTap = onTap;

    try {
      // Config explicite (build --dart-define) prioritaire, sinon config
      // native (google-services.json côté Android). Échec → push désactivé,
      // l'inbox in_app + WebSocket prennent le relais.
      if (DefaultFirebaseOptions.isConfigured) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
      _available = true;
    } catch (_) {
      // Pas de google-services.json / config web : push désactivé,
      // l'inbox in_app + WebSocket prennent le relais.
      _available = false;
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
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Renouvellement du token → re-enregistrement backend
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_onToken?.call(token));
    });

    // Message en foreground → notification locale
    FirebaseMessaging.onMessage.listen(_showForeground);

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
    if (!_available) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Token FCM courant (null si indisponible).
  /// Web : clé VAPID via `--dart-define=FCM_VAPID_KEY=...`.
  Future<String?> getToken() async {
    if (!_available) return null;
    try {
      const vapidKey = String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
      if (kIsWeb && vapidKey.isEmpty) return null;
      return await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? vapidKey : null,
      );
    } catch (_) {
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

// ============================================================
// Fichier: firebase_options.dart
// Description: Options Firebase par plateforme (Android/Web/iOS).
//              Valeurs réelles générées par FlutterFire CLI le
//              2026-09-11 (projet wiwiga-d9a7e), surchargeables
//              via --dart-define. Clés Web/API publiques par design
//              Firebase — aucun secret (compte de service) ne transite
//              côté app.
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-11
// ============================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Options Firebase WIWIGA.
///
/// Surcharge au build (ex. clés de staging) :
/// ```
/// flutter build web --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_AUTH_DOMAIN=... \
///   --dart-define=FIREBASE_PROJECT_ID=... \
///   --dart-define=FIREBASE_SENDER_ID=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FCM_VAPID_KEY=...
/// ```
/// Android natif : `google-services.json` reste le repli si les options
/// explicites sont indisponibles (voir PushNotificationService).
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  // --- Web / valeurs communes (publiques, générées par FlutterFire) ---
  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCxPkfsemAaXeyHQ4FlclNn7OHfdVoCyRk',
  );
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'wiwiga-d9a7e.firebaseapp.com',
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'wiwiga-d9a7e',
  );
  static const String senderId = String.fromEnvironment(
    'FIREBASE_SENDER_ID',
    defaultValue: '660834792043',
  );

  /// App ID Web (généré par FlutterFire).
  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:660834792043:web:c2737e7e778f743333f72e',
  );

  // --- Android natif (générés par FlutterFire, cf. google-services.json) ---
  static const String androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyBALSZLdkALH6EXQLlGWB1GTIgMkueOHO8',
  );
  static const String androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:660834792043:android:b5ef5ea42f492c7e33f72e',
  );

  /// Vrai si des identifiants réels sont présents (jamais les placeholders
  /// historiques `WIWIGA_DEFAULT_*`).
  static bool get isConfigured =>
      !apiKey.startsWith('WIWIGA_DEFAULT_') &&
      !senderId.startsWith('WIWIGA_DEFAULT_') &&
      !appId.startsWith('WIWIGA_DEFAULT_');

  /// Options de la plateforme courante (web/android/ios).
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: apiKey,
        authDomain: authDomain,
        projectId: projectId,
        messagingSenderId: senderId,
        appId: appId,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const FirebaseOptions(
        apiKey: apiKey,
        projectId: projectId,
        messagingSenderId: senderId,
        appId: appId,
        iosBundleId: 'com.wiwiga.wiwiga',
      );
    }
    // Android (et autres natifs) : jeu d'options Android dédié.
    return const FirebaseOptions(
      apiKey: androidApiKey,
      projectId: projectId,
      messagingSenderId: senderId,
      appId: androidAppId,
    );
  }
}

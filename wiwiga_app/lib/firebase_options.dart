// ============================================================
// Fichier: firebase_options.dart
// Description: Options Firebase par plateforme (Android/Web/iOS).
//              Valeurs via --dart-define, placeholders par défaut
//              (push désactivé, inbox in_app en repli).
//              Clés Web/API publiques par design Firebase — aucun
//              secret (compte de service) ne transite côté app.
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-09
// ============================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Options Firebase WIWIGA.
///
/// Surcharge en build :
/// ```
/// flutter build web --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_AUTH_DOMAIN=... \
///   --dart-define=FIREBASE_PROJECT_ID=... \
///   --dart-define=FIREBASE_SENDER_ID=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FCM_VAPID_KEY=...
/// ```
/// Sans valeurs réelles : placeholders `wiwiga-dev` → push désactivé.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  // Valeurs par défaut : projet placeholder, jamais un secret.
  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'WIWIGA_DEFAULT_API_KEY',
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
  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: 'WIWIGA_DEFAULT_APP_ID',
  );

  /// Vrai si des identifiants réels ont été injectés au build.
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
    // Android (et autres natifs) : même jeu d'options.
    return const FirebaseOptions(
      apiKey: apiKey,
      projectId: projectId,
      messagingSenderId: senderId,
      appId: appId,
    );
  }
}

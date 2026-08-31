// ============================================================
// WIWIGA - Error Handler Centralisé (UX Best Practices)
// ============================================================
// Principes:
// 1. Jamais de technique exposée (stacktrace, ApiException.toString, SocketException, URL, errorCode brut)
// 2. Séparation user copy / telemetry (Nielsen #9, LogRocket, SageIdeas)
// 3. Messages humains, empathiques, actionnables, préservent la saisie
// 4. Sévérité-aware: inline (validation) / snackbar (transitoire) / fullscreen (bloquant) / dialog (session)
// 5. Retry partout, offline détecté, timeout explicite
// ============================================================

import 'package:flutter/foundation.dart';
import 'api_exception.dart';

/// Helper centralisé pour convertir toute erreur en message humain
/// et logger les détails techniques séparément.
///
/// ## Usage
/// ```dart
/// try {
///   await repo.doSomething();
/// } catch (e, st) {
///   final msg = ErrorHandler.userMessage(e);
///   ErrorHandler.logError(e, st, context: 'doSomething', extra: {'userId': id});
///   state = state.copyWith(error: msg);
/// }
/// ```
class ErrorHandler {
  const ErrorHandler._();

  /// Message humain, court, actionnable, jamais technique
  /// Utiliser pour `SnackBar`, `Text(error)`, `AdminErrorState`
  static String userMessage(Object error, {String? fallback}) {
    // ApiException typée → userMessage déjà mappé
    if (error is ApiException) {
      // Cas spéciaux: 409 déjà humain (ROOM_FULL etc) → on garde
      // 422 details → message précis si présent
      if (error.isValidation && error.details != null && error.details!.isNotEmpty) {
        // Tente d'extraire un champ lisible, sinon message générique
        final detailsMsg = _validationDetailsMessage(error.details!);
        if (detailsMsg != null) return detailsMsg;
      }
      // 404/403: éviter de leak URL, on garde le message humain
      return error.userMessage;
    }

    final raw = error.toString().toLowerCase();
    // Offline / réseau (common sur mobile Cameroun)
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('failed to fetch') ||
        raw.contains('network_error') ||
        raw.contains('no internet')) {
      return 'Pas de connexion. Vérifiez votre réseau et réessayez.';
    }
    if (raw.contains('timeoutexception') || raw.contains('délai')) {
      return 'Le serveur met trop de temps à répondre. Réessayez.';
    }
    if (raw.contains('formatException') || raw.contains('json') || raw.contains('parse')) {
      return 'Données reçues invalides. Réessayez plus tard.';
    }
    // Timeout/storage fallback silencieux
    if (raw.contains('storage') || raw.contains('secure')) {
      return 'Problème de stockage local. Redémarrez l\'app.';
    }
    // Si l'erreur est déjà un message humain court (<120 chars, sans "ApiException" ni "Exception:")
    final cleaned = _cleanRawMessage(error.toString());
    if (cleaned.length < 120 && !cleaned.contains('ApiException') && !cleaned.contains('Exception')) {
      return cleaned;
    }
    return fallback ?? 'Un problème est survenu. Réessayez.';
  }

  /// Détails de validation 422 → message lisible
  /// ex: details: {"phone": ["must be valid"], "daily_loss_limit": ["too low"]}
  static String? _validationDetailsMessage(Map<String, dynamic> details) {
    if (details.isEmpty) return null;
    // Prend la première entrée lisible
    for (final entry in details.entries) {
      final field = entry.key;
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return '${_humanField(field)} : ${value.first}';
      }
      if (value is String && value.isNotEmpty) {
        return '${_humanField(field)} : $value';
      }
    }
    return null;
  }

  static String _humanField(String field) {
    const map = {
      'phone': 'Téléphone',
      'email': 'Email',
      'username': 'Nom d\'utilisateur',
      'password': 'Mot de passe',
      'daily_loss_limit': 'Limite de perte',
      'daily_deposit_limit': 'Limite de dépôt',
    };
    return map[field] ?? field.replaceAll('_', ' ');
  }

  static String _cleanRawMessage(String raw) {
    // Enlève "Exception: " prefix
    var msg = raw.replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
    // Enlève "ApiException(401, ...): " prefix si jamais passé
    msg = msg.replaceFirst(RegExp(r'ApiException\(\d+[^)]*\):\s*'), '');
    // Coupe les URLs leakées
    msg = msg.replaceAll(RegExp(r'https?://\S+'), '[url]');
    msg = msg.replaceAll(RegExp(r'\(Url:.*?\)'), '');
    msg = msg.replaceAll(RegExp(r'\[url\]'), '');
    // Coupe les stacktrace multiligne
    if (msg.contains('\n')) msg = msg.split('\n').first;
    msg = msg.trim();
    // Limite longueur
    if (msg.length > 180) msg = '${msg.substring(0, 180)}…';
    // Capitalize
    if (msg.isNotEmpty) msg = msg[0].toUpperCase() + msg.substring(1);
    return msg;
  }

  /// Log technique séparé (telemetry) — jamais montré à l'utilisateur
  /// En dev: debugPrint, en prod: Sentry/Crashlytics (TODO)
  static void logError(
    Object error,
    StackTrace? stack, {
    String? context,
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    if (kDebugMode || force) {
      final sb = StringBuffer('[WIWIGA][Error]');
      if (context != null) sb.write(' $context');
      sb.write(' => $error');
      if (error is ApiException) {
        sb.write(' {code:${error.statusCode} errorCode:${error.errorCode} url:${error.requestUrl} details:${error.details}}');
      }
      if (extra != null) sb.write(' extra:$extra');
      debugPrint(sb.toString());
      if (stack != null) debugPrint('$stack');
    }
    // TODO: Sentry.captureException(error, stackTrace: stack, hint: context, extra: extra)
  }

  /// Détermine si retry a du sens (transitoire)
  static bool isRetryable(Object error) {
    if (error is ApiException) {
      return error.isNetworkError || error.isServerError || error.isRateLimited || error.statusCode == 408;
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('timeout') ||
        raw.contains('network') ||
        raw.contains('fetch');
  }

  /// Détermine si offline
  static bool isOffline(Object error) {
    if (error is ApiException) return error.isNetworkError;
    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') || raw.contains('no internet') || raw.contains('failed host lookup') || raw.contains('network is unreachable');
  }

  /// Message court pour bouton retry selon type
  static String retryLabel(Object error) {
    if (isOffline(error)) return 'Réessayer quand en ligne';
    if (error is ApiException && error.isRateLimited) return 'Réessayer dans quelques instants';
    return 'Réessayer';
  }
}

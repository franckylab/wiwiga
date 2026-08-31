// ============================================================
// Fichier: api_exception.dart
// Description: Exceptions HTTP typées pour WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

/// Exception HTTP typée avec code statut, message et code erreur serveur.
///
/// Permet au frontend de différencier les erreurs (409 conflit, 422 validation,
/// 500 serveur, etc.) et d'afficher des messages utilisateur appropriés.
///
/// ## Usage
/// ```dart
/// try {
///   await roomRepo.joinByCode(code);
/// } on ApiException catch (e) {
///   if (e.isConflict) {
///     // 409 : déjà dans une partie
///   } else if (e.isServerError) {
///     // 500 : problème serveur
///   }
/// }
/// ```
class ApiException implements Exception {
  /// Code statut HTTP (400, 401, 409, 422, 500, etc.)
  final int statusCode;

  /// Message d'erreur lisible pour l'utilisateur
  final String message;

  /// Code erreur technique retourné par le backend (ex: "ROOM_FULL")
  final String? errorCode;

  /// Données supplémentaires retournées par le backend
  final Map<String, dynamic>? details;

  /// URL de la requête ayant échoué (pour debug)
  final String? requestUrl;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.details,
    this.requestUrl,
  });

  // ========================================
  // Factory constructors par code statut
  // ========================================

  /// 400 — Bad Request (validation échouée)
  factory ApiException.badRequest(String message, {String? errorCode, Map<String, dynamic>? details, String? url}) =>
      ApiException(statusCode: 400, message: message, errorCode: errorCode, details: details, requestUrl: url);

  /// 401 — Unauthorized (token expiré ou invalide)
  factory ApiException.unauthorized({String? message, String? url, String? errorCode}) => ApiException(
        statusCode: 401,
        message: message ?? 'Session expirée. Veuillez vous reconnecter.',
        errorCode: errorCode ?? 'UNAUTHORIZED',
        requestUrl: url,
      );

  /// 403 — Forbidden (permissions insuffisantes)
  factory ApiException.forbidden(String message, {String? url}) =>
      ApiException(statusCode: 403, message: message, errorCode: 'FORBIDDEN', requestUrl: url);

  /// 404 — Not Found (ressource inexistante)
  factory ApiException.notFound(String message, {String? url}) =>
      ApiException(statusCode: 404, message: message, errorCode: 'NOT_FOUND', requestUrl: url);

  /// 409 — Conflict (conflit de ressource)
  factory ApiException.conflict(String message, {String? errorCode, Map<String, dynamic>? details, String? url}) =>
      ApiException(statusCode: 409, message: message, errorCode: errorCode, details: details, requestUrl: url);

  /// 422 — Unprocessable Entity (erreur de validation)
  factory ApiException.validation(String message, {Map<String, dynamic>? details, String? url}) =>
      ApiException(statusCode: 422, message: message, errorCode: 'VALIDATION_ERROR', details: details, requestUrl: url);

  /// 429 — Too Many Requests (rate limit)
  factory ApiException.rateLimited({String? message, String? url, String? errorCode, Map<String, dynamic>? details}) => ApiException(
        statusCode: 429,
        message: message ?? 'Trop de tentatives. Veuillez patienter.',
        errorCode: errorCode ?? 'RATE_LIMITED',
        details: details,
        requestUrl: url,
      );

  /// 500 — Internal Server Error
  factory ApiException.serverError({String? message, String? url, String? errorCode, Map<String, dynamic>? details}) => ApiException(
        statusCode: 500,
        message: message ?? 'Erreur serveur. Veuillez réessayer.',
        errorCode: errorCode ?? 'SERVER_ERROR',
        details: details,
        requestUrl: url,
      );

  /// 502/503 — Service Unavailable
  factory ApiException.serviceUnavailable({String? url}) =>
      ApiException(statusCode: 503, message: 'Service temporairement indisponible.', errorCode: 'SERVICE_UNAVAILABLE', requestUrl: url);

  /// Erreur réseau (pas de connexion, timeout)
  factory ApiException.network(String message, {String? url}) =>
      ApiException(statusCode: 0, message: message, errorCode: 'NETWORK_ERROR', requestUrl: url);

  // ========================================
  // Predicates — Tests rapides par catégorie
  // ========================================

  /// Erreur réseau (statusCode == 0)
  bool get isNetworkError => statusCode == 0;

  /// 401 — Session expirée
  bool get isUnauthorized => statusCode == 401;

  /// 403 — Accès refusé
  bool get isForbidden => statusCode == 403;

  /// 404 — Non trouvé
  bool get isNotFound => statusCode == 404;

  /// 409 — Conflit (déjà dans une partie, etc.)
  bool get isConflict => statusCode == 409;

  /// 422 — Validation échouée
  bool get isValidation => statusCode == 422;

  /// 429 — Rate limit
  bool get isRateLimited => statusCode == 429;

  /// 500+ — Erreur serveur
  bool get isServerError => statusCode >= 500;

  /// Erreur côté client (4xx)
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  // ========================================
  // Helpers
  // ========================================

  /// Message utilisateur court, sans détails techniques
  /// Jamais d'URL, jamais de stack, jamais de SocketException brut
  String get userMessage {
    switch (statusCode) {
      case 0:
        return 'Pas de connexion. Vérifiez votre réseau.';
      case 400:
        // 400 a déjà un message métier précis
        return message.isNotEmpty ? message : 'Vérifiez les informations saisies.';
      case 401:
        return 'Session expirée. Reconnectez-vous.';
      case 403:
        return message.isNotEmpty ? message : 'Accès non autorisé.';
      case 404:
        return message.isNotEmpty ? message : 'Introuvable. Vérifiez et réessayez.';
      case 409:
        // Conflit = message métier déjà humain (ROOM_FULL etc)
        return message.isNotEmpty ? message : 'Conflit. Action déjà effectuée.';
      case 422:
        return message.isNotEmpty ? message : 'Données invalides. Corrigez le formulaire.';
      case 429:
        return 'Trop de requêtes. Patientez quelques instants.';
      case 500:
      case 502:
      case 503:
      case >= 500:
        return 'Service temporairement indisponible. Réessayez.';
      default:
        return message.isNotEmpty ? message : 'Un problème est survenu. Réessayez.';
    }
  }

  @override
  String toString() => 'ApiException($statusCode${errorCode != null ? ', $errorCode' : ''}): $message';
}

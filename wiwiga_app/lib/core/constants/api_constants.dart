// ============================================================
// Fichier: api_constants.dart
// Description: Constantes des endpoints API WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

/// Endpoints de l'API REST
class ApiEndpoints {
  // Authentication
  static const String login = '/api/auth/login';
  static const String verifyOtp = '/api/auth/verify';
  static const String logout = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';
  
  // Wallet
  static const String walletBalance = '/api/wallet/balance';
  static const String deposit = '/api/wallet/deposit';
  static const String withdraw = '/api/wallet/withdraw';
  static const String transactions = '/api/wallet/transactions';
  
  // Games
  static const String gamesList = '/api/games';
  static const String joinGame = '/api/games/join';
  static const String placeBet = '/api/games/bet';
  static const String gameHistory = '/api/games/history';
  
  // User
  static const String profile = '/api/users/profile';
  static const String updateProfile = '/api/users/profile';
  
  // Payments
  static const String paymentInitiate = '/api/payments/initiate';
  static const String paymentStatus = '/api/payments/status';
}

/// Canaux WebSocket
class WebSocketChannels {
  // Canal principal pour les jeux
  static const String gameRoom = 'game:room';
  
  // Canal pour notifications utilisateur
  static const String userNotifications = 'user:notifications';
  
  // Canal pour mises à jour wallet
  static const String walletUpdates = 'wallet:updates';
}

/// Messages d'erreur standards
class ApiErrors {
  static const String networkError = 'Erreur de connexion réseau';
  static const String timeoutError = 'Délai d\'attente dépassé';
  static const String unauthorized = 'Non autorisé. Veuillez vous reconnecter';
  static const String serverError = 'Erreur serveur. Veuillez réessayer';
  static const String invalidResponse = 'Réponse invalide du serveur';
  static const String insufficientBalance = 'Solde insuffisant';
  static const String invalidAmount = 'Montant invalide';
}

/// Statuts de réponse API
class ApiStatus {
  static const String success = 'success';
  static const String error = 'error';
}

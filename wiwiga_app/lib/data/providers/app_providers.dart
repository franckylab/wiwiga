// ============================================================
// Fichier: app_providers.dart
// Description: Providers Riverpod principaux (Auth, Wallet, Game, WebSocket)
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/game_websocket_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/wallet_repository.dart';
import '../repositories/game_repository.dart';
import '../repositories/admin_repository.dart';
import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/game_model.dart';

// ============================================================
// PROVIDERS DE SERVICES
// ============================================================

/// Provider du service API
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provider du repository Auth
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthRepository(apiService: apiService);
});

/// Provider du repository Wallet
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return WalletRepository(apiService: apiService);
});

/// Provider du repository Game
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GameRepository(apiService: apiService);
});

/// Provider du repository Admin
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AdminRepository(apiService: apiService);
});

/// Provider du service WebSocket jeu (avec fallback REST)
final gameWebSocketServiceProvider = ChangeNotifierProvider<GameWebSocketService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GameWebSocketService(apiService: apiService);
});

// ============================================================
// AUTH PROVIDER
// ============================================================

/// États d'authentification de l'utilisateur
enum AuthStatus {
  /// App vient de démarrer, vérification de session en cours
  unknown,
  
  /// Pas de token, pas de session active — accès public uniquement
  guest,
  
  /// OTP envoyé ou en cours de vérification
  authenticating,
  
  /// JWT valide, session active — accès complet
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final UserModel? user;
  final String? error;
  final String? redirectTo; // Intent original après auth (deep link)
  final bool needsProfileCompletion; // Si l'utilisateur doit compléter son profil
  
  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.user,
    this.error,
    this.redirectTo,
    this.needsProfileCompletion = false,
  });
  
  /// Si l'utilisateur est authentifié
  bool get isAuthenticated => status == AuthStatus.authenticated;
  
  /// Si l'utilisateur est en mode guest
  bool get isGuest => status == AuthStatus.guest;
  
  /// Si la session est en cours de vérification
  bool get isUnknown => status == AuthStatus.unknown;
  
  /// Si l'utilisateur est admin
  bool get isAdmin => user?.isAdmin ?? false;
  
  /// Si l'utilisateur est super_admin
  bool get isSuperAdmin => user?.isSuperAdmin ?? false;
  
  /// Si l'utilisateur est modérateur ou supérieur
  bool get isModerator => user?.isModerator ?? false;
  
  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    UserModel? user,
    String? error,
    String? redirectTo,
    bool? needsProfileCompletion,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      redirectTo: redirectTo ?? this.redirectTo,
      needsProfileCompletion: needsProfileCompletion ?? this.needsProfileCompletion,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  
  AuthNotifier(this._repository) : super(const AuthState());
  
  /// Restaure la session au démarrage de l'app
  /// Appelé par le splash screen
  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.unknown, isLoading: true);
    
    try {
      final user = await _repository.restoreSession();
      
      if (user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          isLoading: false,
          user: user,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.guest,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
      );
    }
  }
  
  /// Envoie OTP par phone
  /// 
  /// Nettoie les anciens tokens avant de commencer le flow d'inscription
  /// pour éviter qu'une session précédente (ex: admin) ne interfere.
  Future<void> sendOtp(String phoneNumber) async {
    // Nettoyer toute session existante avant inscription
    await _repository.logout();
    state = const AuthState(
      status: AuthStatus.authenticating,
      isLoading: true,
    );
    try {
      await _repository.sendOtp(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
        error: 'Erreur lors de l\'envoi du code: $e',
      );
    }
  }
  
  /// Envoie OTP par email
  /// 
  /// Nettoie les anciens tokens avant de commencer le flow d'inscription.
  Future<void> sendOtpByEmail(String email) async {
    // Nettoyer toute session existante avant inscription
    await _repository.logout();
    state = const AuthState(
      status: AuthStatus.authenticating,
      isLoading: true,
    );
    try {
      await _repository.sendOtpByEmail(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
        error: 'Erreur lors de l\'envoi du code: $e',
      );
    }
  }
  
  /// Connexion par mot de passe (phone/email + password)
  /// 
  /// Si OTP requis, retourne sans tokens (l'écran gère la vérification OTP).
  Future<void> loginWithPassword({
    String? phone,
    String? email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      error: null,
    );
    try {
      final result = await _repository.loginWithPassword(
        phone: phone,
        email: email,
        password: password,
      );
      
      final otpRequired = result['otp_required'] as bool? ?? false;
      
      if (otpRequired) {
        // OTP requis: l'écran gère la transition
        state = state.copyWith(
          status: AuthStatus.authenticating,
          isLoading: false,
          user: result['user'] as UserModel,
          error: 'otp_required',
        );
      } else {
        // Connexion directe
        state = state.copyWith(
          status: AuthStatus.authenticated,
          isLoading: false,
          user: result['user'] as UserModel,
          redirectTo: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
        error: 'Identifiants incorrects: $e',
      );
    }
  }
  
  /// Inscription (création de compte)
  Future<void> register({
    String? phone,
    String? email,
    required String username,
    String? avatarType,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      error: null,
    );
    try {
      final result = await _repository.register(
        phone: phone,
        email: email,
        username: username,
        avatarType: avatarType,
      );
      
      state = state.copyWith(
        isLoading: false,
        user: result['user'] as UserModel?,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
        error: 'Erreur lors de l\'inscription: $e',
      );
    }
  }
  
  /// Vérifie OTP par phone et connecte
  Future<void> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      error: null,
    );
    try {
      final result = await _repository.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
      );
      
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
        user: result['user'] as UserModel,
        redirectTo: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
        error: 'Code OTP invalide: $e',
      );
    }
  }
  
  /// Vérifie OTP par email et connecte
  Future<void> verifyOtpByEmail({
    required String email,
    required String otpCode,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      error: null,
    );
    try {
      final result = await _repository.verifyOtpByEmail(
        email: email,
        otpCode: otpCode,
      );
      
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
        user: result['user'] as UserModel,
        redirectTo: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.guest,
        isLoading: false,
        error: 'Code OTP invalide: $e',
      );
    }
  }
  
  /// Complète le profil (username + avatar) après inscription
  Future<void> completeProfile({
    required String username,
    String? avatarType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.completeRegistration(
        username: username,
        avatarType: avatarType,
      );
      
      state = state.copyWith(
        isLoading: false,
        user: user,
        needsProfileCompletion: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur complétion profil: $e',
      );
    }
  }
  
  /// Définit l'intent de redirection après auth
  void setRedirectTo(String route) {
    state = state.copyWith(redirectTo: route);
  }
  
  /// Déconnecte
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.logout();
      state = const AuthState(status: AuthStatus.guest);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.guest,
        user: null,
        error: 'Erreur lors de la déconnexion: $e',
      );
    }
  }
  
  /// Recharge le profil
  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getMe();
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: 'Erreur chargement profil: $e');
    }
  }
  
  /// Récupère les préférences auth (OTP)
  Future<Map<String, dynamic>> getAuthSettings() async {
    try {
      return await _repository.getAuthSettings();
    } catch (e) {
      return {'otp_required_on_login': false};
    }
  }
  
  /// Met à jour les préférences OTP
  Future<bool> updateOtpRequired({required bool enabled}) async {
    try {
      await _repository.updateAuthSettings(otpRequiredOnLogin: enabled);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Provider principal Auth
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

// ============================================================
// WALLET PROVIDER
// ============================================================

class WalletState {
  final bool isLoading;
  final double balance;
  final int tokenBalance;
  final double tokenMonetaryValue;
  final List<WalletTransactionModel> transactions;
  final String? error;
  
  const WalletState({
    this.isLoading = false,
    this.balance = 0,
    this.tokenBalance = 0,
    this.tokenMonetaryValue = 0,
    this.transactions = const [],
    this.error,
  });
  
  WalletState copyWith({
    bool? isLoading,
    double? balance,
    int? tokenBalance,
    double? tokenMonetaryValue,
    List<WalletTransactionModel>? transactions,
    String? error,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      tokenBalance: tokenBalance ?? this.tokenBalance,
      tokenMonetaryValue: tokenMonetaryValue ?? this.tokenMonetaryValue,
      transactions: transactions ?? this.transactions,
      error: error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _repository;
  
  WalletNotifier(this._repository) : super(const WalletState());
  
  /// Charge le solde (monétaire + jetons)
  Future<void> loadBalance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final balanceCentimes = await _repository.getBalance();
      
      // Charger aussi le solde jetons
      int tokenBalance = 0;
      double tokenMonetaryValue = 0;
      try {
        final tokenSummary = await _repository.getTokenSummary();
        tokenBalance = tokenSummary['token_balance'] as int? ?? 0;
        tokenMonetaryValue = ((tokenSummary['monetary_value_centimes'] as num?) ?? 0).toDouble() / 100.0;
      } catch (_) {
        // Non-bloquant si endpoint tokens non disponible
      }
      
      state = state.copyWith(
        isLoading: false,
        balance: balanceCentimes / 100.0,
        tokenBalance: tokenBalance,
        tokenMonetaryValue: tokenMonetaryValue,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur chargement solde: $e',
      );
    }
  }
  
  /// Charge les transactions
  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getTransactions();
      final txList = (result['transactions'] as List)
          .map((t) => WalletTransactionModel.fromJson(t as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        isLoading: false,
        transactions: txList,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur chargement transactions: $e',
      );
    }
  }
  
  /// Dépôt
  Future<void> deposit(double amount) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.deposit(
        amount: (amount * 100).round(),
        idempotencyKey: 'deposit_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      final newBalance = ((result['new_balance'] as num?) ?? 0) / 100.0;
      final tx = WalletTransactionModel.fromJson(result['transaction'] as Map<String, dynamic>? ?? {});
      
      state = state.copyWith(
        isLoading: false,
        balance: newBalance,
        transactions: [tx, ...state.transactions],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur dépôt: $e',
      );
    }
  }
  
  /// Retrait
  Future<void> withdraw(double amount) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.withdraw(
        amount: (amount * 100).round(),
        idempotencyKey: 'withdraw_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      final newBalance = ((result['new_balance'] as num?) ?? 0) / 100.0;
      final tx = WalletTransactionModel.fromJson(result['transaction'] as Map<String, dynamic>? ?? {});
      
      state = state.copyWith(
        isLoading: false,
        balance: newBalance,
        transactions: [tx, ...state.transactions],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur retrait: $e',
      );
    }
  }
}

/// Provider principal Wallet
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(repository);
});

// ============================================================
// GAME PROVIDER
// ============================================================

class GameState {
  final bool isLoading;
  final List<GameModel> games;
  final Map<String, dynamic>? currentSession;
  final Map<String, dynamic>? lastResult;
  final String? error;
  
  const GameState({
    this.isLoading = false,
    this.games = const [],
    this.currentSession,
    this.lastResult,
    this.error,
  });
  
  GameState copyWith({
    bool? isLoading,
    List<GameModel>? games,
    Map<String, dynamic>? currentSession,
    Map<String, dynamic>? lastResult,
    String? error,
  }) {
    return GameState(
      isLoading: isLoading ?? this.isLoading,
      games: games ?? this.games,
      currentSession: currentSession ?? this.currentSession,
      lastResult: lastResult,
      error: error,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  final GameRepository _repository;
  
  GameNotifier(this._repository) : super(const GameState());
  
  /// Charge la liste des jeux
  Future<void> loadGames() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final games = await _repository.getGames();
      state = state.copyWith(
        isLoading: false,
        games: games,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur chargement jeux: $e',
      );
    }
  }
  
  /// Rejoint une file de matchmaking
  Future<void> joinQueue(String gameId, double betAmount) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await _repository.joinQueue(
        gameId: gameId,
        betAmount: betAmount,
      );
      
      state = state.copyWith(
        isLoading: false,
        currentSession: session,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur matchmaking: $e',
      );
    }
  }
  
  /// Place une mise
  Future<void> placeBet({
    required String sessionId,
    required double amount,
    required Map<String, dynamic> betData,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.placeBet(
        sessionId: sessionId,
        amount: amount,
        betData: betData,
      );
      
      state = state.copyWith(
        isLoading: false,
        lastResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur mise: $e',
      );
    }
  }
}

/// Provider principal Game
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  final repository = ref.watch(gameRepositoryProvider);
  return GameNotifier(repository);
});

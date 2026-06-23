// ============================================================
// Fichier: app_providers.dart
// Description: Providers Riverpod principaux (Auth, Wallet, Game, WebSocket)
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/wallet_repository.dart';
import '../repositories/game_repository.dart';
import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/game_model.dart';
import 'web_socket_provider.dart';

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

// ============================================================
// AUTH PROVIDER
// ============================================================

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? error;
  
  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
  });
  
  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error, // Permet de réinitialiser l'erreur
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  
  AuthNotifier(this._repository) : super(const AuthState());
  
  /// Envoie OTP
  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendOtp(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de l\'envoi du code: $e',
      );
    }
  }
  
  /// Vérifie OTP et connecte
  Future<void> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
      );
      
      state = state.copyWith(
        isLoading: false,
        user: result['user'] as UserModel,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Code OTP invalide: $e',
      );
    }
  }
  
  /// Déconnecte
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.logout();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la déconnexion: $e',
      );
    }
  }
  
  /// Recharge le profil
  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getProfile();
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: 'Erreur chargement profil: $e');
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
  final List<WalletTransactionModel> transactions;
  final String? error;
  
  const WalletState({
    this.isLoading = false,
    this.balance = 0,
    this.transactions = const [],
    this.error,
  });
  
  WalletState copyWith({
    bool? isLoading,
    double? balance,
    List<WalletTransactionModel>? transactions,
    String? error,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      error: error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _repository;
  
  WalletNotifier(this._repository) : super(const WalletState());
  
  /// Charge le solde
  Future<void> loadBalance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.getBalance();
      state = state.copyWith(
        isLoading: false,
        balance: user.balance,
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
      final transactions = await _repository.getTransactions();
      state = state.copyWith(
        isLoading: false,
        transactions: transactions,
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
      final transaction = await _repository.deposit(
        amount: amount,
        idempotencyKey: 'deposit_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      state = state.copyWith(
        isLoading: false,
        balance: transaction.balanceAfter,
        transactions: [transaction, ...state.transactions],
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
      final transaction = await _repository.withdraw(
        amount: amount,
        idempotencyKey: 'withdraw_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      state = state.copyWith(
        isLoading: false,
        balance: transaction.balanceAfter,
        transactions: [transaction, ...state.transactions],
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
  final GameSessionModel? currentSession;
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
    GameSessionModel? currentSession,
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

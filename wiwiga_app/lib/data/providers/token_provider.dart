// ============================================================
// Fichier: token_provider.dart
// Description: Provider Riverpod pour la gestion des wiga
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/token_repository.dart';
import '../models/token_transaction_model.dart';
import 'app_providers.dart';
import '../../core/errors/api_exception.dart';

// ============================================================
// TOKEN STATE
// ============================================================

class TokenState {
  final bool isLoading;
  final int tokenBalance;
  final double monetaryValueFcfa;
  final double exchangeRate;
  final bool giftEnabled;
  final List<TokenTransactionModel> transactions;
  final List<PromoTokenModel> availablePromos;
  final String? error;
  final String? promosError;

  const TokenState({
    this.isLoading = false,
    this.tokenBalance = 0,
    this.monetaryValueFcfa = 0,
    this.exchangeRate = 1.0,
    this.giftEnabled = true,
    this.transactions = const [],
    this.availablePromos = const [],
    this.error,
    this.promosError,
  });

  TokenState copyWith({
    bool? isLoading,
    int? tokenBalance,
    double? monetaryValueFcfa,
    double? exchangeRate,
    bool? giftEnabled,
    List<TokenTransactionModel>? transactions,
    List<PromoTokenModel>? availablePromos,
    String? error,
    String? promosError,
    bool clearPromosError = false,
  }) {
    return TokenState(
      isLoading: isLoading ?? this.isLoading,
      tokenBalance: tokenBalance ?? this.tokenBalance,
      monetaryValueFcfa: monetaryValueFcfa ?? this.monetaryValueFcfa,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      giftEnabled: giftEnabled ?? this.giftEnabled,
      transactions: transactions ?? this.transactions,
      availablePromos: availablePromos ?? this.availablePromos,
      error: error,
      promosError: clearPromosError ? null : (promosError ?? this.promosError),
    );
  }
}

// ============================================================
// TOKEN NOTIFIER
// ============================================================

class TokenNotifier extends StateNotifier<TokenState> {
  final TokenRepository _repository;

  TokenNotifier(this._repository) : super(const TokenState());

  /// Charge le résumé des wiga (sans transfert/échange)
  Future<void> loadSummary() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _repository.getTokenSummary();
      final model = TokenSummaryModel.fromJson(summary);

      state = state.copyWith(
        isLoading: false,
        tokenBalance: model.tokenBalance,
        monetaryValueFcfa: model.monetaryValueFcfa,
        exchangeRate: model.exchangeRate,
        giftEnabled: model.giftEnabled,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur chargement wiga');
    }
  }

  /// Charge les transactions
  Future<void> loadTransactions({int page = 1, int limit = 20}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getTokenTransactions(page: page, limit: limit);
      final txList = (result['transactions'] as List)
          .map((t) => TokenTransactionModel.fromJson(t as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        transactions: txList,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur chargement transactions');
    }
  }

  /// Achat de wiga
  Future<void> purchaseTokens(int amountFcfa) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.purchaseTokens(
        amount: (amountFcfa * 100).round(),
        idempotencyKey: 'purchase_${DateTime.now().millisecondsSinceEpoch}',
      );

      await loadSummary();
      await loadTransactions();

      state = state.copyWith(isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur achat wiga');
    }
  }

  /// Envoi cadeau entre amis uniquement
  Future<void> sendGift(String recipientId, int tokenAmount, {String message = ''}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendGift(
        recipientId: recipientId,
        tokenAmount: tokenAmount,
        idempotencyKey: 'gift_${DateTime.now().millisecondsSinceEpoch}',
        message: message,
      );

      await loadSummary();
      await loadTransactions();

      state = state.copyWith(isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur cadeau');
    }
  }

  /// Charge les promos disponibles
  Future<void> loadPromos() async {
    try {
      final promosJson = await _repository.getAvailablePromos();
      final promos = promosJson
          .map((p) => PromoTokenModel.fromJson(p))
          .toList();

      state = state.copyWith(availablePromos: promos, clearPromosError: true);
    } catch (e) {
      // Non-bloquant : on track l'erreur pour affichage UI
      state = state.copyWith(promosError: 'Promotions indisponibles');
    }
  }

  /// Réclame une promo
  Future<void> redeemPromo(String promoId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.redeemPromo(
        promoId: promoId,
        idempotencyKey: 'redeem_${DateTime.now().millisecondsSinceEpoch}',
      );

      await loadSummary();
      await loadTransactions();
      await loadPromos();

      state = state.copyWith(isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur réclamation promo');
    }
  }

  /// Calcule les wiga pour un montant FCFA
  int calculateTokensForAmount(double amountFcfa) {
    return (amountFcfa * state.exchangeRate).floor();
  }

  /// Calcule la valeur monétaire pour un nombre de wiga
  double calculateMonetaryForTokens(int tokens) {
    return tokens / state.exchangeRate;
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Provider du repository Token
final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return TokenRepository(apiService: apiService);
});

/// Provider principal Token
final tokenProvider = StateNotifierProvider<TokenNotifier, TokenState>((ref) {
  final repository = ref.watch(tokenRepositoryProvider);
  return TokenNotifier(repository);
});

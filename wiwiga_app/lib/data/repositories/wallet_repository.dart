// ============================================================
// Fichier: wallet_repository.dart
// Description: Repository du portefeuille financier
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import '../models/wallet_transaction_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant les opérations de portefeuille
class WalletRepository {
  final ApiService _apiService;
  
  WalletRepository({required ApiService apiService})
      : _apiService = apiService;
  
  /// Récupère le solde actuel
  Future<UserModel> getBalance() async {
    final response = await _apiService.get(
      ApiEndpoints.walletBalance,
      requiresAuth: true,
    );
    
    return UserModel.fromJson(response['user']);
  }
  
  /// Effectue un dépôt
  Future<WalletTransactionModel> deposit({
    required double amount,
    required String idempotencyKey,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.deposit,
      body: {
        'amount': amount,
        'idempotency_key': idempotencyKey,
      },
      requiresAuth: true,
    );
    
    return WalletTransactionModel.fromJson(response['transaction']);
  }
  
  /// Effectue un retrait
  Future<WalletTransactionModel> withdraw({
    required double amount,
    required String idempotencyKey,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.withdraw,
      body: {
        'amount': amount,
        'idempotency_key': idempotencyKey,
      },
      requiresAuth: true,
    );
    
    return WalletTransactionModel.fromJson(response['transaction']);
  }
  
  /// Récupère l'historique des transactions
  Future<List<WalletTransactionModel>> getTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.transactions}?limit=$limit&offset=$offset',
      requiresAuth: true,
    );
    
    final transactions = response['transactions'] as List;
    return transactions
        .map((json) => WalletTransactionModel.fromJson(json))
        .toList();
  }
}

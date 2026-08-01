// ============================================================
// Fichier: wallet_repository.dart
// Description: Repository du compte utilisateur
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant les opérations de compte
class WalletRepository {
  final ApiService _apiService;
  
  WalletRepository({required ApiService apiService})
      : _apiService = apiService;
  
  /// Récupère le solde actuel
  /// Backend: GET /api/wallet/balance → {success: true, data: {balance: 50000}}
  Future<int> getBalance() async {
    final response = await _apiService.get(
      ApiEndpoints.walletBalance,
      requiresAuth: true,
    );
    
    final data = response['data'] as Map<String, dynamic>;
    return data['balance'] as int;
  }
  
  /// Effectue un dépôt
  /// Backend: POST /api/wallet/deposit → {success: true, data: {new_balance: 55000, transaction: {...}}}
  Future<Map<String, dynamic>> deposit({
    required int amount,
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
    
    return response['data'] as Map<String, dynamic>;
  }
  
  /// Effectue un retrait
  /// Backend: POST /api/wallet/withdraw → {success: true, data: {new_balance: 48000, transaction: {...}}}
  Future<Map<String, dynamic>> withdraw({
    required int amount,
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
    
    return response['data'] as Map<String, dynamic>;
  }
  
  /// Récupère l'historique des transactions
  /// Backend: GET /api/wallet/transactions?page=1&limit=20 → {success: true, data: [...], pagination: {...}}
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.transactions}?page=$page&limit=$limit',
      requiresAuth: true,
    );
    
    return {
      'transactions': response['data'] as List? ?? [],
      'pagination': response['pagination'] as Map<String, dynamic>? ?? {},
    };
  }
  
  /// Récupère le résumé jetons (solde + valeur monétaire)
  /// Backend: GET /api/tokens/summary → {success: true, data: {token_balance, monetary_value_centimes, ...}}
  Future<Map<String, dynamic>> getTokenSummary() async {
    final response = await _apiService.get(
      ApiEndpoints.tokenSummary,
      requiresAuth: true,
    );
    
    return response['data'] as Map<String, dynamic>;
  }
}

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
  
  /// Récupère l'historique des transactions (monétaire) – paginé + filtres
  /// Backend: GET /api/wallet/transactions?page=1&limit=20&type=&from=&to=&search=
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (type != null && type.isNotEmpty && type != 'all') 'type': type,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _apiService.get(
      ApiEndpoints.transactions,
      queryParams: qp,
      requiresAuth: true,
    );
    return {
      'transactions': response['data'] as List? ?? [],
      'pagination': response['pagination'] as Map<String, dynamic>? ?? {},
    };
  }

  /// Récupère l'historique wiga paginé + filtres (recommandé pour l'historique unifié)
  Future<Map<String, dynamic>> getTokenTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (type != null && type.isNotEmpty && type != 'all') 'type': type,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _apiService.get(
      ApiEndpoints.tokenTransactions,
      queryParams: qp,
      requiresAuth: true,
    );
    return {
      'transactions': response['data'] as List? ?? [],
      'pagination': response['pagination'] as Map<String, dynamic>? ?? {},
    };
  }
  
  /// Récupère le résumé wiga (solde + valeur monétaire)
  /// Backend: GET /api/tokens/summary → {success: true, data: {token_balance, monetary_value_centimes, ...}}
  Future<Map<String, dynamic>> getTokenSummary() async {
    final response = await _apiService.get(
      ApiEndpoints.tokenSummary,
      requiresAuth: true,
    );
    
    return response['data'] as Map<String, dynamic>;
  }
}

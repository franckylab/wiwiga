// ============================================================
// Fichier: token_repository.dart
// Description: Repository des jetons virtuels
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant les opérations de jetons virtuels
class TokenRepository {
  final ApiService _apiService;

  TokenRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Récupère le résumé du solde de jetons
  Future<Map<String, dynamic>> getTokenSummary() async {
    final response = await _apiService.get(
      ApiEndpoints.tokenSummary,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Récupère le solde en jetons
  Future<int> getTokenBalance() async {
    final summary = await getTokenSummary();
    return summary['token_balance'] as int? ?? 0;
  }

  /// Achat de jetons
  Future<Map<String, dynamic>> purchaseTokens({
    required int amount,
    required String idempotencyKey,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.tokenPurchase,
      body: {
        'amount': amount,
        'idempotency_key': idempotencyKey,
      },
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Échange jetons → monnaie
  Future<Map<String, dynamic>> exchangeTokens({
    required int tokenAmount,
    required String idempotencyKey,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.tokenExchange,
      body: {
        'token_amount': tokenAmount,
        'idempotency_key': idempotencyKey,
      },
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Transfert de jetons entre joueurs
  Future<Map<String, dynamic>> transferTokens({
    required String recipientId,
    required int tokenAmount,
    required String idempotencyKey,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.tokenTransfer,
      body: {
        'recipient_id': recipientId,
        'token_amount': tokenAmount,
        'idempotency_key': idempotencyKey,
      },
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Envoi de cadeau (jetons gratuits)
  Future<Map<String, dynamic>> sendGift({
    required String recipientId,
    required int tokenAmount,
    required String idempotencyKey,
    String message = '',
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.tokenGift,
      body: {
        'recipient_id': recipientId,
        'token_amount': tokenAmount,
        'idempotency_key': idempotencyKey,
        'message': message,
      },
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Historique des transactions de jetons
  Future<Map<String, dynamic>> getTokenTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.tokenTransactions}?page=$page&limit=$limit',
      requiresAuth: true,
    );
    return {
      'transactions': response['data'] as List? ?? [],
      'pagination': response['pagination'] as Map<String, dynamic>? ?? {},
    };
  }

  /// Promotions disponibles
  Future<List<Map<String, dynamic>>> getAvailablePromos() async {
    final response = await _apiService.get(
      ApiEndpoints.tokenPromos,
      requiresAuth: true,
    );
    final data = response['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Réclamer une promotion
  Future<Map<String, dynamic>> redeemPromo({
    required String promoId,
    required String idempotencyKey,
  }) async {
    final response = await _apiService.post(
      '${ApiEndpoints.tokenPromos}/$promoId/redeem',
      body: {
        'idempotency_key': idempotencyKey,
      },
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }
}

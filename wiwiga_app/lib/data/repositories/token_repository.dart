// ============================================================
// Fichier: token_repository.dart
// Description: Repository des wiga virtuels
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository gérant les opérations de wiga virtuels
class TokenRepository {
  final ApiService _apiService;

  TokenRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Récupère le résumé du solde de wiga
  Future<Map<String, dynamic>> getTokenSummary() async {
    final response = await _apiService.get(
      ApiEndpoints.tokenSummary,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Récupère le solde en wiga
  Future<int> getTokenBalance() async {
    final summary = await getTokenSummary();
    return summary['token_balance'] as int? ?? 0;
  }

  /// Achat de wiga
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

  /// Envoi de cadeau entre amis uniquement (backend vérifie Friendship)
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

  /// Historique des transactions de wiga
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

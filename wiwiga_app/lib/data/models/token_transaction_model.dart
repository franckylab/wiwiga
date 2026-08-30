// ============================================================
// Fichier: token_transaction_model.dart
// Description: Modèle de transaction de wiga virtuels WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

/// Types de transactions de wiga
enum TokenTransactionType {
  purchase,       // Achat wiga (monnaie → wiga)
  exchange,       // Échange wiga (wiga → monnaie)
  bet,            // Mise de jeu
  winnings,       // Gains
  transferOut,    // Transfert sortant
  transferIn,     // Transfert entrant
  giftSent,       // Cadeau envoyé
  giftReceived,   // Cadeau reçu
  promoCredit,    // Crédit promotionnel
  promoDebit,     // Débit promotionnel
  commission,     // Commission
}

/// Statuts de transaction
enum TokenTransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

/// Modèle représentant une transaction de wiga
class TokenTransactionModel {
  final String id;
  final String userId;
  final TokenTransactionType type;
  final int tokenAmount;
  final int balanceBefore;
  final int balanceAfter;
  final int? monetaryValue;
  final double? exchangeRate;
  final String? counterpartyId;
  final String? gameId;
  final Map<String, dynamic>? metadata;
  final TokenTransactionStatus status;
  final DateTime createdAt;

  const TokenTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.tokenAmount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.monetaryValue,
    this.exchangeRate,
    this.counterpartyId,
    this.gameId,
    this.metadata,
    required this.status,
    required this.createdAt,
  });

  factory TokenTransactionModel.fromJson(Map<String, dynamic> json) {
    return TokenTransactionModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: _parseType(json['type']),
      tokenAmount: json['wiga_amount'] as int? ?? json['token_amount'] as int? ?? 0,
      balanceBefore: json['wiga_balance_before'] as int? ?? json['balance_before'] as int? ?? 0,
      balanceAfter: json['wiga_balance_after'] as int? ?? json['balance_after'] as int? ?? 0,
      monetaryValue: json['monetary_value'] as int?,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      counterpartyId: json['counterparty_id']?.toString(),
      gameId: json['game_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: _parseStatus(json['status']),
      createdAt: json['inserted_at'] != null
          ? DateTime.parse(json['inserted_at'])
          : DateTime.now(),
    );
  }

  static TokenTransactionType _parseType(String? type) {
    switch (type) {
      case 'purchase': return TokenTransactionType.purchase;
      case 'exchange': return TokenTransactionType.exchange;
      case 'bet': return TokenTransactionType.bet;
      case 'winnings': return TokenTransactionType.winnings;
      case 'transfer_out': return TokenTransactionType.transferOut;
      case 'transfer_in': return TokenTransactionType.transferIn;
      case 'gift_sent': return TokenTransactionType.giftSent;
      case 'gift_received': return TokenTransactionType.giftReceived;
      case 'promo_credit': return TokenTransactionType.promoCredit;
      case 'promo_debit': return TokenTransactionType.promoDebit;
      case 'commission': return TokenTransactionType.commission;
      default: return TokenTransactionType.purchase;
    }
  }

  static TokenTransactionStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending': return TokenTransactionStatus.pending;
      case 'completed': return TokenTransactionStatus.completed;
      case 'failed': return TokenTransactionStatus.failed;
      case 'cancelled': return TokenTransactionStatus.cancelled;
      default: return TokenTransactionStatus.completed;
    }
  }

  /// Label lisible du type
  String get typeLabel {
    switch (type) {
      case TokenTransactionType.purchase: return 'Achat';
      case TokenTransactionType.exchange: return 'Échange';
      case TokenTransactionType.bet: return 'Mise';
      case TokenTransactionType.winnings: return 'Gain';
      case TokenTransactionType.transferOut: return 'Transfert envoyé';
      case TokenTransactionType.transferIn: return 'Transfert reçu';
      case TokenTransactionType.giftSent: return 'Cadeau envoyé';
      case TokenTransactionType.giftReceived: return 'Cadeau reçu';
      case TokenTransactionType.promoCredit: return 'Bonus promo';
      case TokenTransactionType.promoDebit: return 'Débit promo';
      case TokenTransactionType.commission: return 'Commission';
    }
  }

  /// Icône associée au type
  String get typeIcon {
    switch (type) {
      case TokenTransactionType.purchase: return 'shopping_cart';
      case TokenTransactionType.exchange: return 'swap_horiz';
      case TokenTransactionType.bet: return 'casino';
      case TokenTransactionType.winnings: return 'emoji_events';
      case TokenTransactionType.transferOut: return 'send';
      case TokenTransactionType.transferIn: return 'call_received';
      case TokenTransactionType.giftSent: return 'card_giftcard';
      case TokenTransactionType.giftReceived: return 'redeem';
      case TokenTransactionType.promoCredit: return 'campaign';
      case TokenTransactionType.promoDebit: return 'remove_circle';
      case TokenTransactionType.commission: return 'receipt';
    }
  }
}

/// Modèle résumé du solde de wiga
class TokenSummaryModel {
  final int tokenBalance;
  final int monetaryValueCentimes;
  final double monetaryValueFcfa;
  final double exchangeRate;
  final int minExchange;
  final int maxExchange;
  final bool transferEnabled;
  final bool giftEnabled;

  const TokenSummaryModel({
    required this.tokenBalance,
    required this.monetaryValueCentimes,
    required this.monetaryValueFcfa,
    required this.exchangeRate,
    required this.minExchange,
    required this.maxExchange,
    required this.transferEnabled,
    required this.giftEnabled,
  });

  factory TokenSummaryModel.fromJson(Map<String, dynamic> json) {
    return TokenSummaryModel(
      tokenBalance: json['wiga_balance'] as int? ?? json['token_balance'] as int? ?? 0,
      monetaryValueCentimes: json['monetary_value_centimes'] as int? ?? 0,
      monetaryValueFcfa: (json['monetary_value_fcfa'] as num?)?.toDouble() ?? 0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      minExchange: json['min_exchange'] as int? ?? 100,
      maxExchange: json['max_exchange'] as int? ?? 100000,
      transferEnabled: json['transfer_enabled'] as bool? ?? true,
      giftEnabled: json['gift_enabled'] as bool? ?? true,
    );
  }

  /// Valeur monétaire formatée en FCFA
  String get monetaryValueFormatted {
    return '${monetaryValueFcfa.toStringAsFixed(0)} FCFA';
  }

  /// Solde wiga formaté
  String get tokenBalanceFormatted {
    return tokenBalance.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}

/// Modèle offre promotionnelle
class PromoTokenModel {
  final String id;
  final String name;
  final String? description;
  final int tokenAmount;
  final Map<String, dynamic> conditions;
  final bool isActive;
  final int? maxRedemptions;
  final int currentRedemptions;
  final DateTime validFrom;
  final DateTime? validUntil;

  const PromoTokenModel({
    required this.id,
    required this.name,
    this.description,
    required this.tokenAmount,
    required this.conditions,
    required this.isActive,
    this.maxRedemptions,
    required this.currentRedemptions,
    required this.validFrom,
    this.validUntil,
  });

  factory PromoTokenModel.fromJson(Map<String, dynamic> json) {
    return PromoTokenModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      tokenAmount: json['token_amount'] as int? ?? 0,
      conditions: json['conditions'] as Map<String, dynamic>? ?? {},
      isActive: json['is_active'] as bool? ?? true,
      maxRedemptions: json['max_redemptions'] as int?,
      currentRedemptions: json['current_redemptions'] as int? ?? 0,
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'])
          : DateTime.now(),
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'])
          : null,
    );
  }

  /// Jours restants avant expiration
  int? get daysRemaining {
    if (validUntil == null) return null;
    final diff = validUntil!.difference(DateTime.now());
    return diff.inDays > 0 ? diff.inDays : 0;
  }

  /// Description des conditions
  String get conditionsText {
    final parts = <String>[];
    if (conditions.containsKey('min_games')) {
      parts.add('${conditions['min_games']} parties min.');
    }
    if (conditions.containsKey('expiry_days')) {
      parts.add('Expire après ${conditions['expiry_days']} jours');
    }
    if (conditions.containsKey('wagering_multiplier')) {
      parts.add('Mise x${conditions['wagering_multiplier']} requise');
    }
    if (conditions.containsKey('game_type')) {
      parts.add('Jeu: ${conditions['game_type']}');
    }
    return parts.isEmpty ? 'Aucune condition' : parts.join(' • ');
  }
}

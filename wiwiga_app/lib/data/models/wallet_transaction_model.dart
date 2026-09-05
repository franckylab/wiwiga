// ============================================================
// Fichier: wallet_transaction_model.dart
// Description: Modèle de transaction financière WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';

/// Types de transactions
enum TransactionType {
  deposit,    // Dépôt
  withdraw,   // Retrait
  bet,        // Mise de jeu
  win,        // Gain
  commission, // Commission
  refund,     // Remboursement
}

/// Statuts de transaction
enum TransactionStatus {
  pending,    // En attente
  completed,  // Terminée
  failed,     // Échouée
  cancelled,  // Annulée
}

/// Modèle représentant une transaction financière
class WalletTransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final TransactionStatus status;
  final String? description;
  final String? idempotencyKey;
  final DateTime createdAt;
  
  // Champs wiga (optionnels)
  final int? tokenAmount;
  final int? tokenBalanceBefore;
  final int? tokenBalanceAfter;
  final String? gameId;
  
  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    this.description,
    this.idempotencyKey,
    required this.createdAt,
    this.tokenAmount,
    this.tokenBalanceBefore,
    this.tokenBalanceAfter,
    this.gameId,
  });
  
  /// Crée un modèle depuis JSON
  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: _parseTransactionType(json['type']),
      amount: (json['amount'] ?? 0).toDouble(),
      balanceBefore: (json['balance_before'] ?? 0).toDouble(),
      balanceAfter: (json['balance_after'] ?? 0).toDouble(),
      status: _parseTransactionStatus(json['status']),
      description: json['description'],
      idempotencyKey: json['idempotency_key'],
      createdAt: DateTime.parse(json['created_at']),
      tokenAmount: json['token_amount'] as int?,
      tokenBalanceBefore: json['token_balance_before'] as int?,
      tokenBalanceAfter: json['token_balance_after'] as int?,
      gameId: json['game_id'] as String?,
    );
  }
  
  /// Parse le type de transaction depuis une chaîne
  static TransactionType _parseTransactionType(String? type) {
    switch (type) {
      case 'deposit':
        return TransactionType.deposit;
      case 'withdraw':
        return TransactionType.withdraw;
      case 'bet':
        return TransactionType.bet;
      case 'win':
        return TransactionType.win;
      case 'commission':
        return TransactionType.commission;
      case 'refund':
        return TransactionType.refund;
      default:
        return TransactionType.deposit;
    }
  }
  
  /// Parse le statut de transaction
  static TransactionStatus _parseTransactionStatus(String? status) {
    switch (status) {
      case 'pending':
        return TransactionStatus.pending;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }
  
  /// Label lisible du type de transaction
  String get typeLabel {
    switch (type) {
      case TransactionType.deposit:
        return 'Dépôt';
      case TransactionType.withdraw:
        return 'Retrait';
      case TransactionType.bet:
        return 'Joué';
      case TransactionType.win:
        return 'Gagné';
      case TransactionType.commission:
        return 'Commission';
      case TransactionType.refund:
        return 'Remboursement';
    }
  }

  String get displayLabelWithGame {
    final g = _gameName(gameId);
    if (g.isEmpty) return typeLabel;
    if (type == TransactionType.bet) return 'Joué • $g';
    if (type == TransactionType.win) return 'Gagné • $g';
    return typeLabel;
  }

  String _gameName(String? raw) {
    if (raw == null) return '';
    final v = raw.toLowerCase();
    if (v.contains('dice')) return 'Dés';
    if (v.contains('ludo')) return 'Ludo';
    if (v.contains('card')) return 'Cartes';
    return '';
  }

  IconData get gameIcon {
    final g = gameId?.toLowerCase() ?? '';
    if (g.contains('dice')) return Icons.casino_rounded;
    if (g.contains('ludo')) return Icons.grid_on_rounded;
    if (g.contains('card')) return Icons.style_rounded;
    return Icons.sports_esports_rounded;
  }
  
  /// Couleur du type de transaction (vert = positif, rouge = négatif)
  bool get isPositive {
    return type == TransactionType.deposit || type == TransactionType.win || type == TransactionType.refund;
  }
}

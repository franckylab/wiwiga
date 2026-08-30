import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Models ===

enum TransactionType {
  deposit, withdraw, bet, win, commission, refund,
  tokenPurchase, tokenExchange, tokenTransfer, tokenGift, promoCredit,
}

class TransactionItem {
  final String id;
  final TransactionType type;
  final int amount; // En wiga
  final int balanceAfter; // En wiga
  final DateTime timestamp;
  final String reference;
  final String? gameName;
  final String status;
  final int? tokenAmount;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.timestamp,
    required this.reference,
    this.gameName,
    this.status = 'completed',
    this.tokenAmount,
  });

  bool get isCredit => type == TransactionType.deposit || type == TransactionType.win || type == TransactionType.refund || type == TransactionType.tokenPurchase || type == TransactionType.tokenGift || type == TransactionType.promoCredit;
  
  String get typeLabel {
    switch (type) {
      case TransactionType.deposit: return 'Achat Wiga';
      case TransactionType.withdraw: return 'Echange';
      case TransactionType.bet: return 'Mise';
      case TransactionType.win: return 'Gain';
      case TransactionType.commission: return 'Commission';
      case TransactionType.refund: return 'Remboursement';
      case TransactionType.tokenPurchase: return 'Achat';
      case TransactionType.tokenExchange: return 'Echange';
      case TransactionType.tokenTransfer: return 'Transfert';
      case TransactionType.tokenGift: return 'Cadeau';
      case TransactionType.promoCredit: return 'Promo';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case TransactionType.deposit: return Icons.shopping_cart;
      case TransactionType.withdraw: return Icons.swap_horiz;
      case TransactionType.bet: return Icons.casino;
      case TransactionType.win: return Icons.emoji_events;
      case TransactionType.commission: return Icons.percent;
      case TransactionType.refund: return Icons.replay;
      case TransactionType.tokenPurchase: return Icons.shopping_cart;
      case TransactionType.tokenExchange: return Icons.swap_horiz;
      case TransactionType.tokenTransfer: return Icons.send;
      case TransactionType.tokenGift: return Icons.card_giftcard;
      case TransactionType.promoCredit: return Icons.campaign;
    }
  }

  Color get typeColor {
    switch (type) {
      case TransactionType.deposit: return NeonColors.success;
      case TransactionType.withdraw: return NeonColors.error;
      case TransactionType.bet: return NeonColors.warning;
      case TransactionType.win: return NeonColors.rankGold;
      case TransactionType.commission: return NeonColors.textSecondary;
      case TransactionType.refund: return NeonColors.info;
      case TransactionType.tokenPurchase: return NeonColors.success;
      case TransactionType.tokenExchange: return NeonColors.accent;
      case TransactionType.tokenTransfer: return NeonColors.info;
      case TransactionType.tokenGift: return NeonColors.secondary;
      case TransactionType.promoCredit: return NeonColors.tokenGold;
    }
  }
}

// === Providers ===

final transactionFilterProvider = StateProvider<String>((ref) => 'all');

final transactionsProvider = FutureProvider<List<TransactionItem>>((ref) async {
  try {
    final apiService = ref.watch(apiServiceProvider);
    final walletRepo = WalletRepository(apiService: apiService);
    final result = await walletRepo.getTransactions(limit: 50);
    final rawTransactions = result['transactions'] as List? ?? [];

    return rawTransactions.map((tx) {
      final t = tx as Map<String, dynamic>;
      final typeStr = (t['type'] as String? ?? 'other').toLowerCase();
      final type = _mapTransactionType(typeStr);
      final amount = (t['amount'] as num?)?.toInt() ?? 0;

      return TransactionItem(
        id: t['id']?.toString() ?? '',
        type: type,
        amount: amount,
        balanceAfter: (t['balance_after'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.tryParse(t['created_at']?.toString() ?? '') ?? DateTime.now(),
        reference: t['reference']?.toString() ?? t['id']?.toString() ?? '',
        gameName: t['game_name'] as String?,
        status: t['status']?.toString() ?? 'completed',
        tokenAmount: (t['token_amount'] as num?)?.toInt(),
      );
    }).toList();
  } catch (e) {
    return [];
  }
});

TransactionType _mapTransactionType(String type) {
  switch (type) {
    case 'deposit': return TransactionType.deposit;
    case 'withdrawal': case 'withdraw': return TransactionType.withdraw;
    case 'bet': return TransactionType.bet;
    case 'win': case 'winnings': return TransactionType.win;
    case 'commission': return TransactionType.commission;
    case 'refund': return TransactionType.refund;
    case 'token_purchase': case 'purchase': return TransactionType.tokenPurchase;
    case 'token_exchange': case 'exchange': return TransactionType.tokenExchange;
    case 'token_transfer': case 'transfer': return TransactionType.tokenTransfer;
    case 'gift': case 'token_gift': return TransactionType.tokenGift;
    case 'promo': case 'promo_credit': return TransactionType.promoCredit;
    default: return TransactionType.commission;
  }
}

// === Écran ===

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilterBar(ref, filter),
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  final filtered = filter == 'all'
                      ? transactions
                      : transactions.where((t) => _matchesFilter(t, filter)).toList();
                  return Column(
                    children: [
                      _buildSummary(transactions),
                      Expanded(child: _buildTransactionList(filtered)),
                    ],
                  );
                },
                loading: () => const NeonLoadingSpinner.center(),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: NeonColors.error, size: 48),
                      const SizedBox(height: 12),
                      const Text('Erreur de chargement', style: TextStyle(color: NeonColors.error)),
                      const SizedBox(height: 12),
                      NeonButton(text: 'Réessayer', onPressed: () => ref.invalidate(transactionsProvider)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NeonColors.info.withValues(alpha: 0.2), NeonColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: NeonColors.primary),
            tooltip: 'Retour',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.receipt_long, color: NeonColors.info, size: 28),
          const SizedBox(width: 8),
          Text('HISTORIQUE', style: AppTypography.heading3),
        ],
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, String current) {
    final filters = [
      {'key': 'all', 'label': 'Tout'},
      {'key': 'tokens', 'label': 'Wiga'},
      {'key': 'game', 'label': 'Jeu'},
      {'key': 'promo', 'label': 'Promo'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = current == f['key'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => ref.read(transactionFilterProvider.notifier).state = f['key']!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? NeonColors.info.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? NeonColors.info : NeonColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    f['label']!,
                    style: TextStyle(
                      color: isSelected ? NeonColors.info : NeonColors.textSecondary,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummary(List<TransactionItem> transactions) {
    final deposits = transactions.where((t) => t.type == TransactionType.deposit).fold<int>(0, (sum, t) => sum + t.amount);
    final withdrawals = transactions.where((t) => t.type == TransactionType.withdraw).fold<int>(0, (sum, t) => sum + t.amount.abs());
    final winnings = transactions.where((t) => t.type == TransactionType.win).fold<int>(0, (sum, t) => sum + t.amount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeonCard(
        child: Row(
          children: [
            _SummaryItem(label: 'Déposé', amount: deposits, color: NeonColors.success),
            Container(width: 1, height: 40, color: NeonColors.border),
            _SummaryItem(label: 'Retiré', amount: withdrawals, color: NeonColors.error),
            Container(width: 1, height: 40, color: NeonColors.border),
            _SummaryItem(label: 'Gagné', amount: winnings, color: NeonColors.rankGold),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionItem> transactions) {
    // Group by date
    final grouped = <String, List<TransactionItem>>{};
    for (final t in transactions) {
      final key = _formatDate(t.timestamp);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final items = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                date,
                style: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...items.map((t) => _TransactionTile(transaction: t)),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) return "Aujourd'hui";
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day && dt.month == yesterday.month) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  bool _matchesFilter(TransactionItem t, String filter) {
    switch (filter) {
      case 'tokens': return t.type == TransactionType.tokenPurchase || t.type == TransactionType.tokenExchange || t.type == TransactionType.tokenTransfer || t.type == TransactionType.tokenGift;
      case 'game': return t.type == TransactionType.bet || t.type == TransactionType.win || t.type == TransactionType.commission;
      case 'promo': return t.type == TransactionType.promoCredit;
      default: return true;
    }
  }
}

// === Transaction Tile ===

class _TransactionTile extends StatelessWidget {
  final TransactionItem transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: transaction.typeColor.withValues(alpha: 0.15),
            ),
            child: Icon(transaction.typeIcon, color: transaction.typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      transaction.typeLabel,
                      style: const TextStyle(
                        color: NeonColors.textPrimary,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (transaction.gameName != null) ...[
                      const SizedBox(width: 6),
                      GlowBadge(text: transaction.gameName!, color: NeonColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      transaction.reference,
                      style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(transaction.timestamp),
                      style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
                    ),
                    if (transaction.status == 'pending') ...[
                      const SizedBox(width: 6),
                      const GlowBadge(text: 'EN ATTENTE', color: NeonColors.warning),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isCredit ? '+' : ''}${_formatTokens(transaction.amount)}',
                style: TextStyle(
                  color: transaction.isCredit ? NeonColors.success : NeonColors.error,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Solde: ${_formatTokens(transaction.balanceAfter)} wiga',
                style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTokens(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ',);
  }
}

// === Summary Item ===

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _SummaryItem({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTokens(amount),
            style: TextStyle(color: color, fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatTokens(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ',);
  }
}

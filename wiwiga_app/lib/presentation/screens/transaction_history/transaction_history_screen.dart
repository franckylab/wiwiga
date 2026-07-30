import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Models ===

enum TransactionType { deposit, withdraw, bet, win, commission, refund }

class TransactionItem {
  final String id;
  final TransactionType type;
  final int amount;
  final int balanceAfter;
  final DateTime timestamp;
  final String reference;
  final String? gameName;
  final String status;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.timestamp,
    required this.reference,
    this.gameName,
    this.status = 'completed',
  });

  bool get isCredit => type == TransactionType.deposit || type == TransactionType.win || type == TransactionType.refund;
  
  String get typeLabel {
    switch (type) {
      case TransactionType.deposit: return 'Dépôt';
      case TransactionType.withdraw: return 'Retrait';
      case TransactionType.bet: return 'Mise';
      case TransactionType.win: return 'Gain';
      case TransactionType.commission: return 'Commission';
      case TransactionType.refund: return 'Remboursement';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case TransactionType.deposit: return Icons.arrow_downward;
      case TransactionType.withdraw: return Icons.arrow_upward;
      case TransactionType.bet: return Icons.casino;
      case TransactionType.win: return Icons.emoji_events;
      case TransactionType.commission: return Icons.percent;
      case TransactionType.refund: return Icons.replay;
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
    }
  }
}

// === Providers ===

final transactionFilterProvider = StateProvider<String>((ref) => 'all');

final transactionsProvider = Provider<List<TransactionItem>>((ref) {
  final now = DateTime.now();
  return [
    TransactionItem(id: '1', type: TransactionType.win, amount: 85000, balanceAfter: 450000, timestamp: now.subtract(const Duration(hours: 2)), reference: 'WIN_001', gameName: 'Dice Game'),
    TransactionItem(id: '2', type: TransactionType.bet, amount: -50000, balanceAfter: 365000, timestamp: now.subtract(const Duration(hours: 2, minutes: 5)), reference: 'BET_042', gameName: 'Dice Game'),
    TransactionItem(id: '3', type: TransactionType.deposit, amount: 200000, balanceAfter: 415000, timestamp: now.subtract(const Duration(hours: 5)), reference: 'DEP_012', status: 'completed'),
    TransactionItem(id: '4', type: TransactionType.withdraw, amount: -100000, balanceAfter: 215000, timestamp: now.subtract(const Duration(hours: 24)), reference: 'WDR_008', status: 'pending'),
    TransactionItem(id: '5', type: TransactionType.win, amount: 120000, balanceAfter: 315000, timestamp: now.subtract(const Duration(days: 1, hours: 3)), reference: 'WIN_002', gameName: 'Dice Game'),
    TransactionItem(id: '6', type: TransactionType.bet, amount: -80000, balanceAfter: 195000, timestamp: now.subtract(const Duration(days: 1, hours: 4)), reference: 'BET_041', gameName: 'Dice Game'),
    TransactionItem(id: '7', type: TransactionType.commission, amount: -5000, balanceAfter: 275000, timestamp: now.subtract(const Duration(days: 1, hours: 3)), reference: 'COM_001', gameName: 'Dice Game'),
    TransactionItem(id: '8', type: TransactionType.deposit, amount: 150000, balanceAfter: 355000, timestamp: now.subtract(const Duration(days: 2)), reference: 'DEP_011', status: 'completed'),
    TransactionItem(id: '9', type: TransactionType.refund, amount: 30000, balanceAfter: 205000, timestamp: now.subtract(const Duration(days: 3)), reference: 'REF_001', gameName: 'Dice Game'),
    TransactionItem(id: '10', type: TransactionType.withdraw, amount: -50000, balanceAfter: 175000, timestamp: now.subtract(const Duration(days: 4)), reference: 'WDR_007', status: 'completed'),
  ];
});

// === Écran ===

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    final filtered = filter == 'all'
        ? transactions
        : transactions.where((t) => _matchesFilter(t, filter)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(ref, filter),
            _buildSummary(transactions),
            Expanded(child: _buildTransactionList(filtered)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NeonColors.info.withOpacity(0.2), NeonColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, color: NeonColors.info, size: 28),
          const SizedBox(width: 8),
          Text('HISTORIQUE', style: AppTypography.heading3),
        ],
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, String current) {
    final filters = [
      {'key': 'all', 'label': 'Tout'},
      {'key': 'deposit', 'label': 'Dépôts'},
      {'key': 'withdraw', 'label': 'Retraits'},
      {'key': 'game', 'label': 'Jeu'},
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
                    color: isSelected ? NeonColors.info.withOpacity(0.15) : Colors.transparent,
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
                style: TextStyle(
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
      case 'deposit': return t.type == TransactionType.deposit;
      case 'withdraw': return t.type == TransactionType.withdraw;
      case 'game': return t.type == TransactionType.bet || t.type == TransactionType.win || t.type == TransactionType.commission;
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
              color: transaction.typeColor.withOpacity(0.15),
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
                      style: TextStyle(
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
                      style: TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(transaction.timestamp),
                      style: TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
                    ),
                    if (transaction.status == 'pending') ...[
                      const SizedBox(width: 6),
                      GlowBadge(text: 'EN ATTENTE', color: NeonColors.warning),
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
                '${transaction.isCredit ? '+' : ''}${_formatFCFA(transaction.amount)}',
                style: TextStyle(
                  color: transaction.isCredit ? NeonColors.success : NeonColors.error,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Solde: ${_formatFCFA(transaction.balanceAfter)}',
                style: TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
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

  String _formatFCFA(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
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
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 4),
          Text(
            _formatFCFA(amount),
            style: TextStyle(color: color, fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatFCFA(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
  }
}

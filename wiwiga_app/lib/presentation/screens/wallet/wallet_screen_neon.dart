import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/neon_theme.dart';
import '../../core/theme/typography.dart';
import '../widgets/neon/neon_widgets.dart';

/// Écran Wallet redesigné avec style néon gaming
class WalletScreenNeon extends ConsumerStatefulWidget {
  const WalletScreenNeon({Key? key}) : super(key: key);

  @override
  ConsumerState<WalletScreenNeon> createState() => _WalletScreenNeonState();
}

class _WalletScreenNeonState extends ConsumerState<WalletScreenNeon> {
  int _currentTab = 0; // 0: Transactions, 1: Dépôt, 2: Retrait

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PORTEFEUILLE',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NeonColors.background,
      ),
      body: Column(
        children: [
          // Balance Header
          _BalanceHeader(),
          
          // Tabs
          _TabSelector(
            currentIndex: _currentTab,
            onTabChanged: (index) => setState(() => _currentTab = index),
          ),
          
          // Content
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _TransactionsTab(),
                _DepositTab(),
                _WithdrawTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: NeonGradients.cta,
      ),
      child: Column(
        children: [
          Text(
            'BALANCE ACTUELLE',
            style: TextStyle(
              fontSize: 14,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          BalanceDisplay(
            balanceCentimes: 250000,
            fontSize: 48,
            showLabel: false,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'DÉPOSER',
                  onPressed: () {},
                  variant: NeonButtonVariant.success,
                  icon: Icons.add,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonButton(
                  text: 'RETIRER',
                  onPressed: () {},
                  variant: NeonButtonVariant.outline,
                  icon: Icons.remove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabChanged;

  const _TabSelector({
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Historique',
            icon: Icons.history,
            isSelected: currentIndex == 0,
            onTap: () => onTabChanged(0),
          ),
          _TabButton(
            label: 'Dépôt',
            icon: Icons.arrow_downward,
            isSelected: currentIndex == 1,
            onTap: () => onTabChanged(1),
          ),
          _TabButton(
            label: 'Retrait',
            icon: Icons.arrow_upward,
            isSelected: currentIndex == 2,
            onTap: () => onTabChanged(2),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: NeonAnimations.standard,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? NeonColors.primary.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(NeonTheme.borderRadius - 4),
            border: isSelected
                ? Border.all(color: NeonColors.primary, width: NeonGlow.borderWidth)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final transactions = [
      {
        'type': 'deposit',
        'amount': 50000,
        'method': 'Campay',
        'date': DateTime.now().subtract(const Duration(hours: 2)),
        'status': 'completed',
      },
      {
        'type': 'bet',
        'amount': -5000,
        'method': 'Jeu de Dés',
        'date': DateTime.now().subtract(const Duration(hours: 5)),
        'status': 'completed',
      },
      {
        'type': 'win',
        'amount': 15000,
        'method': 'Jeu de Dés',
        'date': DateTime.now().subtract(const Duration(hours: 5)),
        'status': 'completed',
      },
      {
        'type': 'withdrawal',
        'amount': -20000,
        'method': 'MTN MoMo',
        'date': DateTime.now().subtract(const Duration(days: 1)),
        'status': 'pending',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _TransactionCard(transaction: transaction);
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionCard({required this.transaction});

  String _formatAmount(int centimes) {
    final francs = centimes / 100;
    final formatter = NumberFormat('#,##0', 'fr_FR');
    final sign = centimes >= 0 ? '+' : '';
    return '$sign${formatter.format(francs)} FCFA';
  }

  IconData _getIcon() {
    switch (transaction['type']) {
      case 'deposit':
        return Icons.arrow_downward;
      case 'withdrawal':
        return Icons.arrow_upward;
      case 'bet':
        return Icons.casino;
      case 'win':
        return Icons.emoji_events;
      default:
        return Icons.receipt;
    }
  }

  Color _getColor() {
    final amount = transaction['amount'] as int;
    if (amount >= 0) return NeonColors.success;
    return NeonColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final amount = transaction['amount'] as int;
    final color = _getColor();

    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getIcon(), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['method'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: NeonColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(transaction['date'] as DateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: NeonColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Orbitron',
                  ),
                ),
                const SizedBox(height: 4),
                GlowBadge(
                  text: _formatStatus(transaction['status'] as String),
                  color: _getStatusColor(transaction['status'] as String),
                  fontSize: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'completed':
        return 'Complété';
      case 'pending':
        return 'En cours';
      case 'failed':
        return 'Échoué';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return NeonColors.success;
      case 'pending':
        return NeonColors.secondary;
      case 'failed':
        return NeonColors.danger;
      default:
        return NeonColors.textSecondary;
    }
  }
}

class _DepositTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MÉTHODE DE PAIEMENT',
                    style: AppTypography.heading4,
                  ),
                  const SizedBox(height: 16),
                  _PaymentMethodOption(
                    name: 'Campay',
                    icon: Icons.payment,
                    isSelected: true,
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodOption(
                    name: 'MTN MoMo',
                    icon: Icons.phone_android,
                    isSelected: false,
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodOption(
                    name: 'Orange Money',
                    icon: Icons.phone_iphone,
                    isSelected: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MONTANT',
                    style: AppTypography.heading4,
                  ),
                  const SizedBox(height: 16),
                  NeonInput(
                    label: 'Montant (FCFA)',
                    hint: 'Entrez le montant',
                    keyboardType: TextInputType.number,
                    icon: Icons.attach_money,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1000, 2000, 5000, 10000, 20000, 50000]
                        .map((amount) => _QuickAmountButton(
                              amount: amount,
                              onTap: () {},
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          NeonButton(
            text: 'DÉPOSER MAINTENANT',
            onPressed: () {},
            variant: NeonButtonVariant.success,
            icon: Icons.check_circle,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;

  const _PaymentMethodOption({
    required this.name,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? NeonColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? NeonColors.primary : NeonColors.border,
          width: isSelected ? NeonGlow.borderWidthThick : NeonGlow.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? NeonColors.primary : NeonColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? NeonColors.primary : NeonColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(Icons.check_circle, color: NeonColors.primary, size: 20),
        ],
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
  });

  String _formatAmount() {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return '${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NeonColors.border),
        ),
        child: Text(
          _formatAmount(),
          style: TextStyle(
            color: NeonColors.primary,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WithdrawTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MÉTHODE DE RETRAIT',
                    style: AppTypography.heading4,
                  ),
                  const SizedBox(height: 16),
                  NeonInput(
                    label: 'Numéro de téléphone',
                    hint: '+237 6XX XXX XXX',
                    keyboardType: TextInputType.phone,
                    icon: Icons.phone,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MONTANT À RETIRER',
                    style: AppTypography.heading4,
                  ),
                  const SizedBox(height: 16),
                  NeonInput(
                    label: 'Montant (FCFA)',
                    hint: 'Entrez le montant',
                    keyboardType: TextInputType.number,
                    icon: Icons.attach_money,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Balance disponible: 2,500 FCFA',
                    style: TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          NeonButton(
            text: 'RETIRER MAINTENANT',
            onPressed: () {},
            variant: NeonButtonVariant.secondary,
            icon: Icons.check_circle,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

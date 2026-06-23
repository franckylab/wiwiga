// ============================================================
// Fichier: wallet_screen.dart
// Description: Écran de gestion du portefeuille avec design responsive
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../widgets/responsive_button.dart';
import '../widgets/responsive_input.dart';

/// Écran de gestion du portefeuille
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});
  
  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _amountController = TextEditingController();
  bool _showDepositDialog = false;
  
  @override
  void initState() {
    super.initState();
    // Charge le solde et les transactions au démarrage
    Future.microtask(() {
      ref.read(walletProvider.notifier).loadBalance();
      ref.read(walletProvider.notifier).loadTransactions();
    });
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  /// Affiche le dialogue de dépôt
  void _openDepositDialog() {
    setState(() => _showDepositDialog = true);
    _amountController.clear();
  }
  
  /// Effectue un dépôt
  Future<void> _handleDeposit() async {
    final amount = double.tryParse(_amountController.text);
    
    if (amount == null || amount <= 0) {
      _showError('Veuillez entrer un montant valide');
      return;
    }
    
    await ref.read(walletProvider.notifier).deposit(amount);
    
    final error = ref.read(walletProvider).error;
    if (error == null) {
      setState(() => _showDepositDialog = false);
      _showSuccess('Dépôt de ${amount.toStringAsFixed(2)} FCFA effectué !');
    }
  }
  
  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
  
  /// Affiche un message de succès
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
  
  /// Formate le montant en FCFA
  String _formatMoney(double amount) {
    return '${amount.toStringAsFixed(2)} FCFA';
  }
  
  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    
    return ResponsiveBuilder(
      builder: (context, config) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Mon Portefeuille',
              style: TextStyle(fontSize: config.fontSizeLarge),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await ref.read(walletProvider.notifier).loadBalance();
              await ref.read(walletProvider.notifier).loadTransactions();
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(config.padding),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Carte de solde
                  _buildBalanceCard(config, walletState.balance)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: -0.2, end: 0),
                  
                  SizedBox(height: config.spacingLarge),
                  
                  // Boutons d'action
                  _buildActionButtons(config),
                  
                  SizedBox(height: config.spacingLarge),
                  
                  // Titre de l'historique
                  Text(
                    'Historique des transactions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: config.fontSizeLarge * 0.8,
                        ),
                  ),
                  
                  SizedBox(height: config.spacing),
                  
                  // Liste des transactions
                  if (walletState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (walletState.transactions.isEmpty)
                    _buildEmptyTransactions(config)
                  else
                    _buildTransactionList(config, walletState.transactions),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// Construit la carte de solde
  Widget _buildBalanceCard(ResponsiveConfig config, double balance) {
    return Container(
      padding: EdgeInsets.all(config.cardPadding * 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(config.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solde disponible',
            style: TextStyle(
              fontSize: config.fontSize,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: config.spacingSmall),
          Text(
            _formatMoney(balance),
            style: TextStyle(
              fontSize: config.fontSizeLarge * 1.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit les boutons d'action
  Widget _buildActionButtons(ResponsiveConfig config) {
    return Row(
      children: [
        Expanded(
          child: ResponsiveButton(
            onPressed: _openDepositDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline),
                SizedBox(width: config.spacingSmall),
                Text(
                  'Déposer',
                  style: TextStyle(fontSize: config.fontSize),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: config.spacing),
        Expanded(
          child: ResponsiveButton(
            onPressed: () {
              // TODO: Implémenter le retrait
              _showError('Retrait bientôt disponible');
            },
            backgroundColor: AppTheme.secondaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.remove_circle_outline),
                SizedBox(width: config.spacingSmall),
                Text(
                  'Retirer',
                  style: TextStyle(fontSize: config.fontSize),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Construit le message d'absence de transactions
  Widget _buildEmptyTransactions(ResponsiveConfig config) {
    return Container(
      padding: EdgeInsets.all(config.padding * 2),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: config.iconSize * 3,
            color: Colors.white38,
          ),
          SizedBox(height: config.spacing),
          Text(
            'Aucune transaction pour le moment',
            style: TextStyle(
              fontSize: config.fontSize,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  /// Construit la liste des transactions
  Widget _buildTransactionList(
    ResponsiveConfig config,
    List<WalletTransactionModel> transactions,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => SizedBox(height: config.spacingSmall),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(config, transaction);
      },
    );
  }
  
  /// Construit un élément de transaction
  Widget _buildTransactionItem(
    ResponsiveConfig config,
    WalletTransactionModel transaction,
  ) {
    return Container(
      padding: EdgeInsets.all(config.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      child: Row(
        children: [
          // Icône du type de transaction
          Container(
            width: config.iconSize * 2,
            height: config.iconSize * 2,
            decoration: BoxDecoration(
              color: transaction.isPositive
                  ? AppTheme.successColor.withOpacity(0.2)
                  : AppTheme.errorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(config.borderRadius * 0.5),
            ),
            child: Icon(
              transaction.isPositive
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: transaction.isPositive
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
              size: config.iconSize,
            ),
          ),
          
          SizedBox(width: config.spacing),
          
          // Détails de la transaction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.typeLabel,
                  style: TextStyle(
                    fontSize: config.fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: config.spacingSmall * 0.5),
                Text(
                  transaction.description ?? '',
                  style: TextStyle(
                    fontSize: config.fontSizeSmall,
                    color: Colors.white54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Montant
          Text(
            '${transaction.isPositive ? '+' : '-'}${_formatMoney(transaction.amount.abs())}',
            style: TextStyle(
              fontSize: config.fontSize,
              fontWeight: FontWeight.bold,
              color: transaction.isPositive
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }
}

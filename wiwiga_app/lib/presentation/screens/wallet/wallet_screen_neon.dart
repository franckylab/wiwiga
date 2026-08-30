import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../../data/providers/token_provider.dart';
import '../../../data/providers/friend_provider.dart';
import '../../../data/models/token_transaction_model.dart';
import '../../providers/config_provider.dart';

/// Écran Wallet redesigné avec système de wiga
class WalletScreenNeon extends ConsumerStatefulWidget {
  const WalletScreenNeon({super.key});

  @override
  ConsumerState<WalletScreenNeon> createState() => _WalletScreenNeonState();
}

class _WalletScreenNeonState extends ConsumerState<WalletScreenNeon> {
  int _currentTab = 0; // 0: Historique, 1: Acheter, 2: Échanger, 3: Transférer, 4: Promos

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        ref.read(tokenProvider.notifier).loadSummary();
        ref.read(tokenProvider.notifier).loadTransactions();
      }
      // Promos accessibles à tous
      ref.read(tokenProvider.notifier).loadPromos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuest || authState.isUnknown;

    // Mode guest : CTA connexion (sauf pour les promos)
    if (isGuest) {
      return _GuestWalletScreen(authState: authState);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MES WIGA',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NeonColors.background,
        foregroundColor: NeonColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: NeonColors.secondary),
            onPressed: () => setState(() => _currentTab = 4),
            tooltip: 'Promotions',
          ),
        ],
      ),
      body: Column(
        children: [
          _TokenBalanceHeader(onQuickAction: (tab) => setState(() => _currentTab = tab)),
          _TabSelector(
            currentIndex: _currentTab,
            onTabChanged: (index) => setState(() => _currentTab = index),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _TransactionsTab(),
                _PurchaseTab(),
                _ExchangeTab(),
                _TransferTab(),
                _PromosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BALANCE HEADER
// ============================================================

class _TokenBalanceHeader extends ConsumerWidget {
  final void Function(int tab)? onQuickAction;
  const _TokenBalanceHeader({this.onQuickAction});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(gradient: NeonGradients.cta),
      child: Column(
        children: [
          // Solde wiga — pièce 3D hero or + LOD full
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 360;
              final coinSize = isSmall ? 36.0 : 44.0;
              final fontSize = isSmall ? 36.0 : 42.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TokenCoin(
                    size: coinSize,
                    metal: TokenMetal.gold,
                    lod: TokenCoin.autoLod(coinSize),
                    effect: TokenEffect.shimmer,
                    animated: true,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatTokens(tokenState.tokenBalance),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.textPrimary,
                      fontFamily: 'Orbitron',
                      shadows: [
                        Shadow(
                          color: NeonColors.tokenGold.withValues(alpha: 0.28),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const Text(
            'WIGA',
            style: TextStyle(
              fontSize: 12,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          // Boutons d'action rapide
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'ACHETER',
                  onPressed: () => onQuickAction?.call(1),
                  variant: NeonButtonVariant.success,
                  icon: Icons.add,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'ÉCHANGER',
                  onPressed: () => onQuickAction?.call(2),
                  variant: NeonButtonVariant.outline,
                  icon: Icons.swap_horiz,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'CADEAU',
                  onPressed: () => onQuickAction?.call(3),
                  variant: NeonButtonVariant.secondary,
                  icon: Icons.card_giftcard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    return tokens.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}

// ============================================================
// TAB SELECTOR
// ============================================================

class _TabSelector extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabChanged;

  const _TabSelector({required this.currentIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
        border: Border.all(color: NeonColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabButton(label: 'Historique', icon: Icons.history, isSelected: currentIndex == 0, onTap: () => onTabChanged(0)),
            _TabButton(label: 'Acheter', icon: Icons.shopping_cart, isSelected: currentIndex == 1, onTap: () => onTabChanged(1)),
            _TabButton(label: 'Échanger', icon: Icons.swap_horiz, isSelected: currentIndex == 2, onTap: () => onTabChanged(2)),
            _TabButton(label: 'Transférer', icon: Icons.send, isSelected: currentIndex == 3, onTap: () => onTabChanged(3)),
            _TabButton(label: 'Promos', icon: Icons.campaign, isSelected: currentIndex == 4, onTap: () => onTabChanged(4)),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NeonAnimations.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(NeonTheme.borderRadius - 4),
          border: isSelected ? Border.all(color: NeonColors.primary, width: NeonGlow.borderWidth) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? NeonColors.primary : NeonColors.textSecondary, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TRANSACTIONS TAB
// ============================================================

class _TransactionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);

    if (tokenState.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: NeonColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Aucune transaction', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tokenState.transactions.length,
      itemBuilder: (context, index) {
        final tx = tokenState.transactions[index];
        return _TokenTransactionCard(transaction: tx);
      },
    );
  }
}

class _TokenTransactionCard extends StatelessWidget {
  final TokenTransactionModel transaction;

  const _TokenTransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.tokenAmount > 0;
    final color = isCredit ? NeonColors.success : NeonColors.danger;

    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getIcon(), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.typeLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NeonColors.textPrimary, fontFamily: 'Inter')),
                  const SizedBox(height: 2),
                  Text(_formatDate(transaction.createdAt), style: const TextStyle(fontSize: 11, color: NeonColors.textSecondary, fontFamily: 'Inter')),
                  if (transaction.monetaryValue != null && transaction.monetaryValue! > 0) ...[
                    const SizedBox(height: 2),
                    Text('≈ ${(transaction.monetaryValue! / 100).toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 10, color: NeonColors.secondary, fontFamily: 'Inter')),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isCredit ? '+' : ''}${transaction.tokenAmount}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, fontFamily: 'Orbitron'),
                ),
                const SizedBox(width: 4),
                TokenCoin(size: 14, metal: TokenMetal.emerald, lod: TokenLod.flat, showShadow: false, withW: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (transaction.type) {
      case TokenTransactionType.purchase: return Icons.shopping_cart;
      case TokenTransactionType.exchange: return Icons.swap_horiz;
      case TokenTransactionType.bet: return Icons.casino;
      case TokenTransactionType.winnings: return Icons.emoji_events;
      case TokenTransactionType.transferOut: return Icons.send;
      case TokenTransactionType.transferIn: return Icons.call_received;
      case TokenTransactionType.giftSent: return Icons.card_giftcard;
      case TokenTransactionType.giftReceived: return Icons.redeem;
      case TokenTransactionType.promoCredit: return Icons.campaign;
      case TokenTransactionType.promoDebit: return Icons.remove_circle;
      case TokenTransactionType.commission: return Icons.receipt;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }
}

// ============================================================
// PURCHASE TAB
// ============================================================

class _PurchaseTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends ConsumerState<_PurchaseTab> {
  final _controller = TextEditingController();
  int _selectedAmount = 0;
  String _selectedPayment = 'Campay';

  final _quickAmounts = [500, 1000, 2000, 5000, 10000, 20000];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenState = ref.watch(tokenProvider);
    final featureConfigAsync = ref.watch(featureConfigProvider);
    final paymentsConfigAsync = ref.watch(paymentsConfigProvider);

    // Valeurs par défaut si config non chargée
    final minDeposit = featureConfigAsync.when(
      data: (c) => c.minDepositAmount,
      loading: () => 500,
      error: (_, __) => 500,
    );
    final maxDeposit = featureConfigAsync.when(
      data: (c) => c.maxDepositAmount,
      loading: () => 1000000,
      error: (_, __) => 1000000,
    );

    // Providers de paiement actifs
    final activeProviders = paymentsConfigAsync.when(
      data: (c) => c.providers.entries.where((e) => e.value.isEnabled).map((e) => e.key).toList(),
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    final isAmountValid = _selectedAmount >= minDeposit && _selectedAmount <= maxDeposit;
    final tokensPreview = _selectedAmount > 0
        ? (_selectedAmount * tokenState.exchangeRate).floor()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Méthode de paiement
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MÉTHODE DE PAIEMENT', style: AppTypography.heading4),
                  const SizedBox(height: 12),
                  if (activeProviders.isEmpty) ...[
                    _PaymentMethod(name: 'Campay', icon: Icons.payment, isSelected: _selectedPayment == 'Campay', onTap: () => setState(() => _selectedPayment = 'Campay')),
                    const SizedBox(height: 8),
                    _PaymentMethod(name: 'MTN MoMo', icon: Icons.phone_android, isSelected: _selectedPayment == 'MTN', onTap: () => setState(() => _selectedPayment = 'MTN')),
                    const SizedBox(height: 8),
                    _PaymentMethod(name: 'Orange Money', icon: Icons.phone_iphone, isSelected: _selectedPayment == 'OM', onTap: () => setState(() => _selectedPayment = 'OM')),
                  ] else ...[
                    ...activeProviders.asMap().entries.map((entry) {
                      final i = entry.key;
                      final key = entry.value;
                      final labels = {'campay': ('Campay', Icons.payment), 'mtn_momo': ('MTN MoMo', Icons.phone_android), 'orange_money': ('Orange Money', Icons.phone_iphone)};
                      final (name, icon) = labels[key] ?? (key.toUpperCase(), Icons.payment);
                      return Padding(
                        padding: EdgeInsets.only(bottom: i < activeProviders.length - 1 ? 8 : 0),
                        child: _PaymentMethod(name: name, icon: icon, isSelected: _selectedPayment == key, onTap: () => setState(() => _selectedPayment = key)),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Montant
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTANT À PAYER', style: AppTypography.heading4),
                  const SizedBox(height: 12),
                  NeonInput(
                    label: 'Montant',
                    hint: 'Entrez le montant',
                    keyboardType: TextInputType.number,
                    icon: Icons.attach_money,
                    controller: _controller,
                    onChanged: (val) => setState(() => _selectedAmount = int.tryParse(val) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts.map((amount) => _QuickAmountButton(
                      amount: amount,
                      isSelected: _selectedAmount == amount,
                      onTap: () {
                        _controller.text = amount.toString();
                        setState(() => _selectedAmount = amount);
                      },
                    ),).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Aperçu wiga 3D — pile + montant
          if (tokensPreview > 0)
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TokenStack(
                      count: (tokensPreview / 2000).clamp(1, 6).round(),
                      size: 32,
                      metal: TokenMetal.gold,
                      altMetal: TokenMetal.emerald,
                    ),
                    const SizedBox(width: 14),
                    const Text('Vous recevrez:', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
                    const Spacer(),
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TokenCoin(size: 20, metal: TokenMetal.gold, lod: TokenLod.bevel, showShadow: false),
                            const SizedBox(width: 6),
                            Text('+${tokensPreview.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NeonColors.success, fontFamily: 'Orbitron')),
                          ],
                        ),
                        const Text('wiga', style: TextStyle(fontSize: 10, color: NeonColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Validation min/max
          if (_selectedAmount > 0 && !isAmountValid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _selectedAmount < minDeposit
                    ? 'Montant minimum: ${minDeposit.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA'
                    : 'Montant maximum: ${maxDeposit.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
                style: const TextStyle(color: NeonColors.error, fontSize: 12, fontFamily: 'Inter'),
              ),
            ),
          NeonButton(
            text: 'ACHETER DES WIGA',
            onPressed: () {
              if (isAmountValid) {
                ref.read(tokenProvider.notifier).purchaseTokens(_selectedAmount);
              }
            },
            variant: NeonButtonVariant.success,
            icon: Icons.shopping_cart,
            width: double.infinity,
            isEnabled: isAmountValid,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXCHANGE TAB
// ============================================================

class _ExchangeTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ExchangeTab> createState() => _ExchangeTabState();
}

class _ExchangeTabState extends ConsumerState<_ExchangeTab> {
  final _controller = TextEditingController();
  int _selectedTokens = 0;

  final _quickAmounts = [100, 500, 1000, 5000, 10000, 50000];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenState = ref.watch(tokenProvider);
    final monetaryPreview = _selectedTokens > 0
        ? (_selectedTokens / tokenState.exchangeRate)
        : 0.0;
    final isValid = _selectedTokens >= tokenState.minExchange &&
        _selectedTokens <= tokenState.maxExchange &&
        _selectedTokens <= tokenState.tokenBalance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info limites
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Min. échange', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
                      Text('${tokenState.minExchange} wiga', style: const TextStyle(color: NeonColors.primary, fontFamily: 'Orbitron', fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Max. échange', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
                      Text('${tokenState.maxExchange.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} wiga', style: const TextStyle(color: NeonColors.primary, fontFamily: 'Orbitron', fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Solde disponible', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
                      Text('${tokenState.tokenBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} wiga', style: const TextStyle(color: NeonColors.success, fontFamily: 'Orbitron', fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Nombre de wiga
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WIGA À ÉCHANGER', style: AppTypography.heading4),
                  const SizedBox(height: 12),
                  NeonInput(
                    label: 'Nombre de wiga',
                    hint: 'Entrez le nombre',
                    keyboardType: TextInputType.number,
                    icon: Icons.monetization_on,
                    controller: _controller,
                    onChanged: (val) => setState(() => _selectedTokens = int.tryParse(val) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts.map((amount) => _QuickAmountButton(
                      amount: amount,
                      isSelected: _selectedTokens == amount,
                      onTap: () {
                        _controller.text = amount.toString();
                        setState(() => _selectedTokens = amount);
                      },
                    ),).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Aperçu valeur 3D
          if (monetaryPreview > 0)
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TokenCoin(size: 36, metal: TokenMetal.silver, effect: TokenEffect.float, animated: true),
                    const SizedBox(width: 12),
                    const Text('Vous recevrez:', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
                    const Spacer(),
                    Column(
                      children: [
                        Text('${monetaryPreview.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NeonColors.success, fontFamily: 'Orbitron')),
                        const Text('monnaie', style: TextStyle(fontSize: 10, color: NeonColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Validation
          if (_selectedTokens > 0 && !isValid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _selectedTokens < tokenState.minExchange
                    ? 'Minimum ${tokenState.minExchange} wiga'
                    : _selectedTokens > tokenState.tokenBalance
                        ? 'Solde insuffisant'
                        : 'Maximum ${tokenState.maxExchange} wiga',
                style: const TextStyle(color: NeonColors.danger, fontFamily: 'Inter', fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          NeonButton(
            text: 'ÉCHANGER MAINTENANT',
            onPressed: () {
              if (isValid) {
                ref.read(tokenProvider.notifier).exchangeTokens(_selectedTokens);
              }
            },
            variant: NeonButtonVariant.secondary,
            icon: Icons.swap_horiz,
            width: double.infinity,
            isEnabled: isValid,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TRANSFER TAB
// ============================================================

class _TransferTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends ConsumerState<_TransferTab> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  int _selectedTokens = 0;
  bool _isGift = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenState = ref.watch(tokenProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Type: Transfert ou Cadeau
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TYPE D\'OPÉRATION', style: AppTypography.heading4),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeSelector(
                          label: 'Transfert',
                          icon: Icons.send,
                          isSelected: !_isGift,
                          onTap: () => setState(() => _isGift = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TypeSelector(
                          label: 'Cadeau',
                          icon: Icons.card_giftcard,
                          isSelected: _isGift,
                          onTap: () => setState(() => _isGift = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Destinataire
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DESTINATAIRE', style: AppTypography.heading4),
                  const SizedBox(height: 12),
                  NeonInput(
                    label: 'Numéro de téléphone',
                    hint: '+237 6XX XXX XXX',
                    keyboardType: TextInputType.phone,
                    icon: Icons.person,
                    controller: _phoneController,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Montant
          NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTANT EN WIGA', style: AppTypography.heading4),
                  const SizedBox(height: 12),
                  NeonInput(
                    label: 'Nombre de wiga',
                    hint: 'Entrez le nombre',
                    keyboardType: TextInputType.number,
                    icon: Icons.monetization_on,
                    controller: _amountController,
                    onChanged: (val) => setState(() => _selectedTokens = int.tryParse(val) ?? 0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Solde: ${tokenState.tokenBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} wiga',
                    style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ),
          // Message cadeau
          if (_isGift) ...[
            const SizedBox(height: 12),
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NeonInput(
                  label: 'Message (optionnel)',
                  hint: 'Joyeux anniversaire!',
                  icon: Icons.message,
                  controller: _messageController,
                  maxLines: 2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          NeonButton(
            text: _isGift ? 'ENVOYER LE CADEAU' : 'TRANSFÉRER',
            onPressed: () async {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty || _selectedTokens <= 0) return;

              // Vérifier solde suffisant
              if (_selectedTokens > tokenState.tokenBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solde insuffisant'), backgroundColor: NeonColors.error),
                );
                return;
              }

              // Rechercher le destinataire par téléphone
              try {
                final friendRepo = ref.read(friendRepositoryProvider);
                final results = await friendRepo.searchPlayer(phone);

                if (results.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aucun joueur trouvé avec ce numéro'), backgroundColor: NeonColors.error),
                  );
                  return;
                }

                final recipient = results.first;

                // Exécuter le transfert ou le cadeau
                if (_isGift) {
                  await ref.read(tokenProvider.notifier).sendGift(
                    recipient.id.toString(), _selectedTokens, message: _messageController.text,
                  );
                } else {
                  await ref.read(tokenProvider.notifier).transferTokens(
                    recipient.id.toString(), _selectedTokens,
                  );
                }

                if (!context.mounted) return;
                final tokenStateAfter = ref.read(tokenProvider);
                if (tokenStateAfter.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tokenStateAfter.error!), backgroundColor: NeonColors.error),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isGift ? 'Cadeau envoyé à ${recipient.name}!' : 'Transfert réussi à ${recipient.name}!'),
                      backgroundColor: NeonColors.success,
                    ),
                  );
                  _phoneController.clear();
                  _amountController.clear();
                  _messageController.clear();
                  setState(() => _selectedTokens = 0);
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: NeonColors.error),
                );
              }
            },
            variant: _isGift ? NeonButtonVariant.success : NeonButtonVariant.primary,
            icon: _isGift ? Icons.card_giftcard : Icons.send,
            width: double.infinity,
            isEnabled: _selectedTokens > 0 && _phoneController.text.isNotEmpty,
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeSelector({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NeonAnimations.standard,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.15) : NeonColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? NeonColors.primary : NeonColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? NeonColors.primary : NeonColors.textSecondary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? NeonColors.primary : NeonColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROMOS TAB
// ============================================================

class _PromosTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);

    // Erreur de chargement des promos
    if (tokenState.promosError != null && tokenState.availablePromos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: NeonColors.error.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Promotions indisponibles', style: TextStyle(color: NeonColors.error, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger les offres. Réessayez plus tard.',
              style: TextStyle(color: NeonColors.textSecondary.withValues(alpha: 0.6), fontFamily: 'Inter', fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.read(tokenProvider.notifier).loadPromos(),
              icon: const Icon(Icons.refresh, color: NeonColors.primary),
              label: const Text('Réessayer', style: TextStyle(color: NeonColors.primary)),
            ),
          ],
        ),
      );
    }

    // Aucune promo
    if (tokenState.availablePromos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: NeonColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Aucune promotion disponible', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            Text('Revenez bientôt pour des offres!', style: TextStyle(color: NeonColors.textSecondary.withValues(alpha: 0.6), fontFamily: 'Inter', fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tokenState.availablePromos.length,
      itemBuilder: (context, index) {
        final promo = tokenState.availablePromos[index];
        return _PromoCard(
          promo: promo,
          onRedeem: () => ref.read(tokenProvider.notifier).redeemPromo(promo.id),
        );
      },
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoTokenModel promo;
  final VoidCallback onRedeem;

  const _PromoCard({required this.promo, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TokenCoin(
                  size: 48,
                  metal: TokenMetal.gold,
                  lod: TokenLod.full,
                  effect: TokenEffect.shimmer,
                  animated: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(promo.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NeonColors.textPrimary, fontFamily: 'Inter')),
                      if (promo.description != null)
                        Text(promo.description!, style: const TextStyle(fontSize: 12, color: NeonColors.textSecondary, fontFamily: 'Inter')),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+${promo.tokenAmount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: NeonColors.success, fontFamily: 'Orbitron')),
                    const Text('wiga', style: TextStyle(fontSize: 9, color: NeonColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Conditions
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: NeonColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(promo.conditionsText, style: const TextStyle(fontSize: 11, color: NeonColors.textSecondary, fontFamily: 'Inter')),
                  ),
                ],
              ),
            ),
            if (promo.daysRemaining != null) ...[
              const SizedBox(height: 8),
              Text(
                'Expire dans ${promo.daysRemaining} jours',
                style: const TextStyle(fontSize: 11, color: NeonColors.secondary, fontFamily: 'Inter'),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: 'RÉCLAMER',
                onPressed: onRedeem,
                variant: NeonButtonVariant.success,
                icon: Icons.check_circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS PARTAGÉS
// ============================================================

class _PaymentMethod extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethod({required this.name, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? NeonColors.primary : NeonColors.border, width: isSelected ? NeonGlow.borderWidthThick : NeonGlow.borderWidth),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? NeonColors.primary : NeonColors.textSecondary),
            const SizedBox(width: 12),
            Text(name, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? NeonColors.primary : NeonColors.textPrimary, fontFamily: 'Inter')),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: NeonColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final int amount;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.amount, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.2) : NeonColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? NeonColors.primary : NeonColors.border),
        ),
        child: Text(
          amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} '),
          style: TextStyle(
            color: isSelected ? NeonColors.primary : NeonColors.textPrimary,
            fontFamily: 'Orbitron',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MODE GUEST : ÉCRAN CTA CONNEXION
// ============================================================

class _GuestWalletScreen extends ConsumerWidget {
  final AuthState authState;

  const _GuestWalletScreen({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton retour pour mode guest
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: NeonColors.primary),
                  tooltip: 'Retour',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TokenCoin(
                        size: 80,
                        metal: TokenMetal.gold,
                        lod: TokenLod.full,
                        effect: TokenEffect.float,
                        animated: true,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Connectez-vous pour gérer vos wiga',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NeonColors.textPrimary,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Achetez des wiga, échangez-les contre des gains\net suivez votre historique de transactions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: NeonColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 32),
                      NeonButton(
                        text: 'SE CONNECTER',
                        icon: Icons.login,
                        onPressed: () {
                          ref.read(authProvider.notifier).setRedirectTo('/tokens');
                          context.go('/auth');
                        },
                        width: 220,
                      ),
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
}

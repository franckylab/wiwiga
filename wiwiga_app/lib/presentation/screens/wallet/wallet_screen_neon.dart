import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/constants/currency.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../../data/providers/token_provider.dart';
import '../../../data/models/token_transaction_model.dart';
import '../../providers/config_provider.dart';

/// Écran Mes Wiga refondé — 3 onglets uniquement (Historique / Acheter / Promos)
/// - Transfert & Échange supprimés (seuls achat + cadeau ami + promos)
/// - Cadeau déplacé vers Amis (GiftSheet)
/// - Ergonomie & responsabilité renforcées
class WalletScreenNeon extends ConsumerStatefulWidget {
  const WalletScreenNeon({super.key});

  @override
  ConsumerState<WalletScreenNeon> createState() => _WalletScreenNeonState();
}

class _WalletScreenNeonState extends ConsumerState<WalletScreenNeon> {
  int _currentTab = 0; // 0: Historique, 1: Acheter, 2: Promos

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        ref.read(tokenProvider.notifier).loadSummary();
        ref.read(tokenProvider.notifier).loadTransactions();
      }
      ref.read(tokenProvider.notifier).loadPromos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuest || authState.isUnknown;

    if (isGuest) {
      return _GuestWalletScreen(authState: authState);
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text(
          'MES WIGA',
          style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NeonColors.background,
        foregroundColor: NeonColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: NeonColors.secondary),
            onPressed: () => setState(() => _currentTab = 2),
            tooltip: 'Promotions',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: NeonColors.textSecondary),
            onPressed: () => context.push('/responsible-gaming/limits'),
            tooltip: 'Jeu responsable',
          ),
        ],
      ),
      body: Column(
        children: [
          _WigaBalanceHeader(onQuickAction: (tab) => setState(() => _currentTab = tab)),
          _WigaTabSelector(
            currentIndex: _currentTab,
            onTabChanged: (index) => setState(() => _currentTab = index),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: const [
                _HistoryTab(),
                _PurchaseTab(),
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
// HEADER SOLDE FACTORISÉ
// ============================================================

class _WigaBalanceHeader extends ConsumerWidget {
  final void Function(int tab)? onQuickAction;
  const _WigaBalanceHeader({this.onQuickAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);
    final tokensConfig = ref.watch(tokensConfigProvider);
    final giftEnabled = tokenState.giftEnabled;
    final dailyGiftLimit = tokensConfig.when(
      data: (c) => c.dailyGiftLimit,
      loading: () => 10000,
      error: (_, __) => 10000,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(gradient: NeonGradients.cta),
      child: Column(
        children: [
          // Solde hero
          LayoutBuilder(
            builder: (context, c) {
              final isSmall = c.maxWidth < 360;
              final coinSize = isSmall ? 36.0 : 44.0;
              final fontSize = isSmall ? 32.0 : 38.0;
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
                  Flexible(
                    child: Text(
                      formatWigaAmount(tokenState.tokenBalance),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: NeonColors.textPrimary,
                        fontFamily: 'Orbitron',
                        shadows: [Shadow(color: NeonColors.tokenGold.withValues(alpha: 0.28), blurRadius: 10)],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 2),
          const Text('WIGA',
              style: TextStyle(fontSize: 11, color: NeonColors.textSecondary, fontFamily: 'Inter', letterSpacing: 3)),
          const SizedBox(height: 4),
          Text('≈ ${tokenState.monetaryValueFcfa.toStringAsFixed(0)} FCFA  •  1 wiga = 1 FCFA',
              style: TextStyle(color: NeonColors.textSecondary.withValues(alpha: 0.9), fontFamily: 'Inter', fontSize: 11)),
          const SizedBox(height: 14),
          // Actions rapides (3 boutons)
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'ACHETER',
                  onPressed: () => onQuickAction?.call(1),
                  variant: NeonButtonVariant.success,
                  icon: Icons.add_shopping_cart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'CADEAU',
                  onPressed: giftEnabled ? () => context.push('/friends') : null,
                  variant: NeonButtonVariant.secondary,
                  icon: Icons.card_giftcard,
                  isEnabled: giftEnabled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeonButton(
                  text: 'HISTORIQUE',
                  onPressed: () => onQuickAction?.call(0),
                  variant: NeonButtonVariant.outline,
                  icon: Icons.receipt_long,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bannière responsabilité / limite
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: NeonColors.background.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeonColors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: NeonColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    giftEnabled
                        ? 'Cadeaux entre amis • Limite ${formatWiga(dailyGiftLimit)} / jour • Jeu responsable'
                        : 'Cadeaux temporairement désactivés',
                    style: const TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter', fontSize: 11),
                  ),
                ),
                InkWell(
                  onTap: () => context.push('/responsible-gaming/limits'),
                  child: const Text('Gérer',
                      style: TextStyle(color: NeonColors.info, fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB SELECTOR 3 ONGLETS
// ============================================================

class _WigaTabSelector extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabChanged;
  const _WigaTabSelector({required this.currentIndex, required this.onTabChanged});

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
      child: Row(
        children: [
          Expanded(child: _TabButton(label: 'Historique', icon: Icons.history, isSelected: currentIndex == 0, onTap: () => onTabChanged(0))),
          Expanded(child: _TabButton(label: 'Acheter', icon: Icons.shopping_cart, isSelected: currentIndex == 1, onTap: () => onTabChanged(1))),
          Expanded(child: _TabButton(label: 'Promos', icon: Icons.campaign, isSelected: currentIndex == 2, onTap: () => onTabChanged(2))),
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
  const _TabButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NeonAnimations.standard,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? NeonColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(NeonTheme.borderRadius - 4),
          border: isSelected ? Border.all(color: NeonColors.primary, width: NeonGlow.borderWidth) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? NeonColors.primary : NeonColors.textSecondary, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HISTORIQUE TAB — filtre + pagination + empty
// ============================================================

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);
    final isLoading = tokenState.isLoading && tokenState.transactions.isEmpty;

    if (isLoading) {
      return const NeonLoadingSpinner.center();
    }

    if (tokenState.transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: NeonColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('Aucune transaction', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Vos achats, cadeaux et gains apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeonColors.textSecondary.withValues(alpha: 0.7), fontFamily: 'Inter', fontSize: 12)),
              const SizedBox(height: 16),
              NeonButton(text: 'Acheter des wiga', icon: Icons.shopping_cart, variant: NeonButtonVariant.success, onPressed: () {}),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: NeonColors.primary,
      onRefresh: () async {
        await ref.read(tokenProvider.notifier).loadSummary();
        await ref.read(tokenProvider.notifier).loadTransactions();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: tokenState.transactions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HistorySummary(transactions: tokenState.transactions),
            );
          }
          final tx = tokenState.transactions[index - 1];
          return _TransactionCard(transaction: tx);
        },
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final List<TokenTransactionModel> transactions;
  const _HistorySummary({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final achats = transactions.where((t) => t.type == TokenTransactionType.purchase).fold<int>(0, (s, t) => s + t.tokenAmount.abs());
    final cadeauxSent = transactions.where((t) => t.type == TokenTransactionType.giftSent).fold<int>(0, (s, t) => s + t.tokenAmount.abs());
    final gains = transactions.where((t) => t.type == TokenTransactionType.winnings).fold<int>(0, (s, t) => s + t.tokenAmount);

    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            _SummaryItem(label: 'Acheté', amount: achats, color: NeonColors.success),
            Container(width: 1, height: 36, color: NeonColors.border),
            _SummaryItem(label: 'Cadeaux', amount: cadeauxSent, color: NeonColors.secondary),
            Container(width: 1, height: 36, color: NeonColors.border),
            _SummaryItem(label: 'Gagné', amount: gains, color: NeonColors.rankGold),
          ],
        ),
      ),
    );
  }
}

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
          Text(label, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(formatWigaAmount(amount), style: TextStyle(color: color, fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold)),
          const Text('wiga', style: TextStyle(color: NeonColors.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TokenTransactionModel transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.tokenAmount > 0;
    final color = isCredit ? NeonColors.success : NeonColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeonCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_getIcon(), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.typeLabel,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NeonColors.textPrimary, fontFamily: 'Inter')),
                    const SizedBox(height: 2),
                    Text(_formatDate(transaction.createdAt),
                        style: const TextStyle(fontSize: 11, color: NeonColors.textSecondary, fontFamily: 'Inter')),
                    if (transaction.counterpartyId != null)
                      Text('Avec #${transaction.counterpartyId}',
                          style: const TextStyle(fontSize: 10, color: NeonColors.textSecondary, fontFamily: 'Inter')),
                    if (transaction.metadata != null && (transaction.metadata!['message'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('"${transaction.metadata!['message']}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: NeonColors.info, fontStyle: FontStyle.italic, fontFamily: 'Inter')),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${isCredit ? '+' : ''}${formatWigaAmount(transaction.tokenAmount)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color, fontFamily: 'Orbitron')),
                      const SizedBox(width: 4),
                      const TokenCoin(size: 14, metal: TokenMetal.emerald, lod: TokenLod.flat, showShadow: false, withW: true),
                    ],
                  ),
                  Text('Solde ${formatWigaAmount(transaction.balanceAfter)}',
                      style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10, fontFamily: 'Inter')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (transaction.type) {
      case TokenTransactionType.purchase:
        return Icons.shopping_cart;
      case TokenTransactionType.bet:
        return Icons.casino;
      case TokenTransactionType.winnings:
        return Icons.emoji_events;
      case TokenTransactionType.giftSent:
        return Icons.card_giftcard;
      case TokenTransactionType.giftReceived:
        return Icons.redeem;
      case TokenTransactionType.promoCredit:
        return Icons.campaign;
      case TokenTransactionType.promoDebit:
        return Icons.remove_circle;
      case TokenTransactionType.commission:
        return Icons.receipt;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }
}

// ============================================================
// PURCHASE TAB — factorisé + responsable
// ============================================================

class _PurchaseTab extends ConsumerStatefulWidget {
  const _PurchaseTab();
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

    final minDeposit = featureConfigAsync.when(data: (c) => c.minDepositAmount, loading: () => 500, error: (_, __) => 500);
    final maxDeposit = featureConfigAsync.when(data: (c) => c.maxDepositAmount, loading: () => 1000000, error: (_, __) => 1000000);

    final activeProviders = paymentsConfigAsync.when(
      data: (c) => c.providers.entries.where((e) => e.value.isEnabled).map((e) => e.key).toList(),
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    final isAmountValid = _selectedAmount >= minDeposit && _selectedAmount <= maxDeposit;
    final tokensPreview = _selectedAmount > 0 ? (_selectedAmount * tokenState.exchangeRate).floor() : 0;
    final afterBalance = tokenState.tokenBalance + tokensPreview;

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
                  ] else
                    ...activeProviders.asMap().entries.map((e) {
                      final labels = {'campay': ('Campay', Icons.payment), 'mtn_momo': ('MTN MoMo', Icons.phone_android), 'orange_money': ('Orange Money', Icons.phone_iphone)};
                      final (name, icon) = labels[e.value] ?? (e.value.toUpperCase(), Icons.payment);
                      return Padding(
                        padding: EdgeInsets.only(bottom: e.key < activeProviders.length - 1 ? 8 : 0),
                        child: _PaymentMethod(name: name, icon: icon, isSelected: _selectedPayment == e.value, onTap: () => setState(() => _selectedPayment = e.value)),
                      );
                    }),
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
                  Text('MONTANT À PAYER (FCFA)', style: AppTypography.heading4),
                  const SizedBox(height: 4),
                  const Text('1 FCFA = 1 wiga • Paiement sécurisé Mobile Money',
                      style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter', fontSize: 11)),
                  const SizedBox(height: 12),
                  NeonInput(
                    label: 'Montant',
                    hint: 'Ex: 1000',
                    keyboardType: TextInputType.number,
                    icon: Icons.attach_money,
                    controller: _controller,
                    onChanged: (val) => setState(() => _selectedAmount = int.tryParse(val) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts
                        .map((amount) => _QuickAmountButton(
                              amount: amount,
                              isSelected: _selectedAmount == amount,
                              onTap: () {
                                _controller.text = amount.toString();
                                setState(() => _selectedAmount = amount);
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Aperçu
          if (tokensPreview > 0)
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        TokenStack(count: (tokensPreview / 2000).clamp(1, 6).round(), size: 32, metal: TokenMetal.gold, altMetal: TokenMetal.emerald),
                        const SizedBox(width: 14),
                        const Text('Vous recevrez :', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter', fontSize: 13)),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const TokenCoin(size: 20, metal: TokenMetal.gold, lod: TokenLod.bevel, showShadow: false),
                                const SizedBox(width: 6),
                                Text('+${formatWigaAmount(tokensPreview)}',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: NeonColors.success, fontFamily: 'Orbitron')),
                              ],
                            ),
                            const Text('wiga', style: TextStyle(fontSize: 10, color: NeonColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: NeonColors.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Solde après achat', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter', fontSize: 12)),
                        Text('${formatWigaAmount(afterBalance)} wiga',
                            style: const TextStyle(color: NeonColors.primary, fontFamily: 'Orbitron', fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedAmount > 0 && !isAmountValid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _selectedAmount < minDeposit ? 'Minimum : ${_fmt(minDeposit)} FCFA' : 'Maximum : ${_fmt(maxDeposit)} FCFA',
                style: const TextStyle(color: NeonColors.error, fontSize: 12, fontFamily: 'Inter'),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 14),
          NeonButton(
            text: 'ACHETER DES WIGA',
            onPressed: isAmountValid ? () => ref.read(tokenProvider.notifier).purchaseTokens(_selectedAmount) : () {},
            variant: NeonButtonVariant.success,
            icon: Icons.shopping_cart,
            width: double.infinity,
            isEnabled: isAmountValid,
          ),
          const SizedBox(height: 12),
          // Tips cadeau amis
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeonColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeonColors.secondary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, size: 16, color: NeonColors.secondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Envie d’offrir ? Va dans Amis → Offrir des wiga (réservé aux amis).',
                      style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter', fontSize: 11)),
                ),
                TextButton(
                  onPressed: () => context.push('/friends'),
                  child: const Text('Y aller', style: TextStyle(color: NeonColors.secondary, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ============================================================
// PROMOS TAB
// ============================================================

class _PromosTab extends ConsumerWidget {
  const _PromosTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenState = ref.watch(tokenProvider);

    if (tokenState.promosError != null && tokenState.availablePromos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 64, color: NeonColors.error.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text('Promotions indisponibles', style: TextStyle(color: NeonColors.error, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Impossible de charger les offres. Réessayez plus tard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeonColors.textSecondary.withValues(alpha: 0.6), fontFamily: 'Inter', fontSize: 12)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.read(tokenProvider.notifier).loadPromos(),
                icon: const Icon(Icons.refresh, color: NeonColors.primary),
                label: const Text('Réessayer', style: TextStyle(color: NeonColors.primary)),
              ),
            ],
          ),
        ),
      );
    }

    if (tokenState.availablePromos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined, size: 64, color: NeonColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('Aucune promotion disponible', style: TextStyle(color: NeonColors.textSecondary, fontFamily: 'Inter')),
              const SizedBox(height: 8),
              Text('Revenez bientôt pour des offres !',
                  style: TextStyle(color: NeonColors.textSecondary.withValues(alpha: 0.6), fontFamily: 'Inter', fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: NeonColors.primary,
      onRefresh: () => ref.read(tokenProvider.notifier).loadPromos(),
      child: LayoutBuilder(
        builder: (context, c) {
          final crossAxisCount = c.maxWidth > 900 ? 2 : 1;
          if (crossAxisCount == 1) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tokenState.availablePromos.length,
              itemBuilder: (context, index) => _PromoCard(promo: tokenState.availablePromos[index], onRedeem: () => ref.read(tokenProvider.notifier).redeemPromo(tokenState.availablePromos[index].id)),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6),
            itemCount: tokenState.availablePromos.length,
            itemBuilder: (context, index) => _PromoCard(promo: tokenState.availablePromos[index], onRedeem: () => ref.read(tokenProvider.notifier).redeemPromo(tokenState.availablePromos[index].id)),
          );
        },
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const TokenCoin(size: 44, metal: TokenMetal.gold, lod: TokenLod.full, effect: TokenEffect.shimmer, animated: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(promo.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: NeonColors.textPrimary, fontFamily: 'Inter')),
                      if (promo.description != null)
                        Text(promo.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: NeonColors.textSecondary, fontFamily: 'Inter')),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+${formatWigaAmount(promo.tokenAmount)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NeonColors.success, fontFamily: 'Orbitron')),
                    const Text('wiga', style: TextStyle(fontSize: 9, color: NeonColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: NeonColors.surface, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: NeonColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(promo.conditionsText, style: const TextStyle(fontSize: 11, color: NeonColors.textSecondary, fontFamily: 'Inter'))),
                ],
              ),
            ),
            if (promo.daysRemaining != null) ...[
              const SizedBox(height: 8),
              Text('Expire dans ${promo.daysRemaining} jours', style: const TextStyle(fontSize: 11, color: NeonColors.secondary, fontFamily: 'Inter')),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: NeonButton(text: 'RÉCLAMER', onPressed: onRedeem, variant: NeonButtonVariant.success, icon: Icons.check_circle)),
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
          formatWigaAmount(amount),
          style: TextStyle(color: isSelected ? NeonColors.primary : NeonColors.textPrimary, fontFamily: 'Orbitron', fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, fontSize: 12),
        ),
      ),
    );
  }
}

// ============================================================
// MODE GUEST
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(icon: const Icon(Icons.arrow_back, color: NeonColors.primary), tooltip: 'Retour', onPressed: () => context.pop()),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const TokenCoin(size: 80, metal: TokenMetal.gold, lod: TokenLod.full, effect: TokenEffect.float, animated: true),
                      const SizedBox(height: 24),
                      const Text('Connectez-vous pour gérer vos wiga',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NeonColors.textPrimary, fontFamily: 'Orbitron')),
                      const SizedBox(height: 12),
                      const Text('Achetez des wiga, offrez à vos amis\net suivez votre historique.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: NeonColors.textSecondary, fontFamily: 'Inter')),
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

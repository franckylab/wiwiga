// ============================================================
// WIWIGA - Historique des Transactions V2
// Écran professionnel, fluide, responsive extrême
// Auteur: WIWIGA Team - 2026-09-18
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Modèle d'affichage unifié (wiga + monétaire) ===
enum TxFilter { all, wiga, game, promo }

enum TxKind {
  deposit,
  withdraw,
  bet,
  win,
  commission,
  refund,
  purchase,
  gift,
  promo;

  String get label {
    switch (this) {
      case TxKind.deposit:
        return 'Achat Wiga';
      case TxKind.withdraw:
        return 'Retrait';
      case TxKind.bet:
        return 'Joué';
      case TxKind.win:
        return 'Gagné';
      case TxKind.commission:
        return 'Commission';
      case TxKind.refund:
        return 'Remboursement';
      case TxKind.purchase:
        return 'Achat';
      case TxKind.gift:
        return 'Cadeau';
      case TxKind.promo:
        return 'Promo';
    }
  }

  IconData get icon {
    switch (this) {
      case TxKind.deposit:
        return Icons.account_balance_wallet_rounded;
      case TxKind.withdraw:
        return Icons.payments_rounded;
      case TxKind.bet:
        return Icons.casino_rounded;
      case TxKind.win:
        return Icons.emoji_events_rounded;
      case TxKind.commission:
        return Icons.percent_rounded;
      case TxKind.refund:
        return Icons.replay_rounded;
      case TxKind.purchase:
        return Icons.shopping_cart_rounded;
      case TxKind.gift:
        return Icons.card_giftcard_rounded;
      case TxKind.promo:
        return Icons.campaign_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TxKind.deposit:
        return NeonColors.success;
      case TxKind.withdraw:
        return NeonColors.error;
      case TxKind.bet:
        return NeonColors.warning;
      case TxKind.win:
        return NeonColors.rankGold;
      case TxKind.commission:
        return NeonColors.textSecondary;
      case TxKind.refund:
        return NeonColors.info;
      case TxKind.purchase:
        return NeonColors.success;
      case TxKind.gift:
        return NeonColors.secondary;
      case TxKind.promo:
        return NeonColors.tokenGold;
    }
  }

  bool get isCredit =>
      this == TxKind.deposit ||
      this == TxKind.win ||
      this == TxKind.refund ||
      this == TxKind.purchase ||
      this == TxKind.promo;
}

class TxItem {
  final String id;
  final TxKind kind;
  final int
      amount; // wiga (positif crédit, négatif débit) — pour wallet monétaire, amount est en centimes mais on affiche wiga
  final int balanceAfter;
  final DateTime ts;
  final String ref;
  final String? game;
  final String status;
  final String rawType;

  TxItem({
    required this.id,
    required this.kind,
    required this.amount,
    required this.balanceAfter,
    required this.ts,
    required this.ref,
    this.game,
    required this.status,
    required this.rawType,
  });

  bool get isCredit => amount > 0;
}

TxKind _mapKind(String s) {
  final v = s.toLowerCase().trim();
  switch (v) {
    case 'deposit':
      return TxKind.deposit;
    case 'withdraw':
    case 'withdrawal':
      return TxKind.withdraw;
    case 'bet':
      return TxKind.bet;
    case 'win':
    case 'winnings':
      return TxKind.win;
    case 'commission':
      return TxKind.commission;
    case 'refund':
      return TxKind.refund;
    case 'purchase':
    case 'token_purchase':
      return TxKind.purchase;
    case 'gift':
    case 'gift_sent':
    case 'gift_received':
    case 'token_gift':
    case 'transfer':
    case 'transfer_out':
    case 'transfer_in':
      return TxKind.gift;
    case 'promo':
    case 'promo_credit':
    case 'promo_debit':
      return TxKind.promo;
    case 'token_exchange':
      return TxKind.purchase;
    default:
      return TxKind.commission;
  }
}

// === State notifier pour filtres + pagination ===
class TxHistoryState {
  final TxFilter filter;
  final String search;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;
  const TxHistoryState(
      {this.filter = TxFilter.all,
      this.search = '',
      this.from,
      this.to,
      this.page = 1,
      this.limit = 20});
  TxHistoryState copyWith(
          {TxFilter? filter,
          String? search,
          DateTime? from,
          DateTime? to,
          int? page,
          int? limit}) =>
      TxHistoryState(
          filter: filter ?? this.filter,
          search: search ?? this.search,
          from: from ?? this.from,
          to: to ?? this.to,
          page: page ?? this.page,
          limit: limit ?? this.limit);
}

class TxHistoryNotifier extends StateNotifier<TxHistoryState> {
  TxHistoryNotifier() : super(const TxHistoryState());
  void setFilter(TxFilter f) => state = state.copyWith(filter: f, page: 1);
  void setSearch(String s) => state = state.copyWith(search: s, page: 1);
  void setRange(DateTime? f, DateTime? t) =>
      state = state.copyWith(from: f, to: t, page: 1);
  void nextPage() => state = state.copyWith(page: state.page + 1);
  void reset() => state = const TxHistoryState();
}

final txHistoryStateProvider =
    StateNotifierProvider<TxHistoryNotifier, TxHistoryState>(
        (_) => TxHistoryNotifier());

// Provider paginé — single ledger wiga, filtrage serveur pour pagination correcte
final txHistoryProvider =
    FutureProvider.family<Map<String, dynamic>, TxHistoryState>((ref, s) async {
  final api = ref.watch(apiServiceProvider);
  final repo = WalletRepository(apiService: api);
  String? apiType;
  switch (s.filter) {
    case TxFilter.promo:
      apiType = 'promo';
      break;
    case TxFilter.wiga:
      apiType = 'wiga';
      break;
    case TxFilter.game:
      apiType = 'game';
      break;
    case TxFilter.all:
      apiType = null;
      break;
  }
  final res = await repo.getTokenTransactions(
      page: s.page,
      limit: s.limit,
      type: apiType,
      from: s.from,
      to: s.to,
      search: s.search.isEmpty ? null : s.search);
  final raw = res['transactions'] as List? ?? [];
  var items = raw.map((e) {
    final m = e as Map<String, dynamic>;
    final t = m['type']?.toString() ?? 'commission';
    final kind = _mapKind(t);
    final amt = (m['wiga_amount'] as num? ??
            m['token_amount'] as num? ??
            m['amount'] as num? ??
            0)
        .toInt();
    final bal =
        (m['wiga_balance_after'] as num? ?? m['balance_after'] as num? ?? 0)
            .toInt();
    final ts = DateTime.tryParse(m['inserted_at']?.toString() ??
            m['created_at']?.toString() ??
            '') ??
        DateTime.now();
    return TxItem(
      id: m['id']?.toString() ?? '',
      kind: kind,
      amount: amt,
      balanceAfter: bal,
      ts: ts,
      ref: m['idempotency_key']?.toString() ?? m['id']?.toString() ?? '',
      game: m['game_id']?.toString(),
      status: m['status']?.toString() ?? 'completed',
      rawType: t,
    );
  }).toList();

  // Recherche client en complément (le serveur filtre déjà type/from/to/search)
  if (s.search.isNotEmpty) {
    final q = s.search.toLowerCase();
    // Garde-fou si le serveur n'a pas filtré (ex: cache)
    items = items
        .where((x) =>
            x.ref.toLowerCase().contains(q) ||
            (x.game?.toLowerCase().contains(q) ?? false) ||
            x.rawType.toLowerCase().contains(q))
        .toList();
  }

  final pagination = res['pagination'] as Map<String, dynamic>? ?? {};
  return {'items': items, 'pagination': pagination};
});

// === Écran ===
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Le bouton "Charger plus" gère la pagination de manière explicite pour plus de contrôle
    // Le scroll infini automatique est désactivé pour éviter les requêtes redondantes
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final histState = ref.watch(txHistoryStateProvider);
    final async = ref.watch(txHistoryProvider(histState));
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: NeonColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/tokens'),
              searchCtrl: _searchCtrl,
              onSearch: (v) =>
                  ref.read(txHistoryStateProvider.notifier).setSearch(v),
              onClearSearch: () {
                _searchCtrl.clear();
                ref.read(txHistoryStateProvider.notifier).setSearch('');
              },
              onPickRange: _pickRange,
              hasRange: histState.from != null || histState.to != null,
              onClearRange: () => ref
                  .read(txHistoryStateProvider.notifier)
                  .setRange(null, null),
            ),
            _FilterBar(
              current: histState.filter,
              onChanged: (f) =>
                  ref.read(txHistoryStateProvider.notifier).setFilter(f),
            ),
            Expanded(
              child: async.when(
                data: (data) {
                  final items = (data['items'] as List).cast<TxItem>();
                  final pagination = data['pagination'] as Map<String, dynamic>;
                  final hasNext = pagination['has_next'] == true;
                  if (items.isEmpty)
                    return _EmptyState(
                        filter: histState.filter,
                        hasRange: histState.from != null);
                  return Column(
                    children: [
                      _SummaryStrip(items: items),
                      Expanded(
                        child: RefreshIndicator(
                          color: NeonColors.primary,
                          backgroundColor: NeonColors.surface,
                          onRefresh: () async {
                            ref.invalidate(txHistoryProvider(histState));
                          },
                          child: isWide
                              ? _TableView(items: items, onTap: _showDetail)
                              : _GroupedList(
                                  items: items,
                                  onTap: _showDetail,
                                  scrollCtrl: _scrollCtrl),
                        ),
                      ),
                      if (hasNext)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(txHistoryStateProvider.notifier)
                                  .nextPage(),
                              icon: const Icon(Icons.expand_more_rounded,
                                  size: 18),
                              label: const Text('Charger plus'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: NeonColors.primary,
                                  side: const BorderSide(
                                      color: NeonColors.primary)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => ListView(
                  padding: const EdgeInsets.all(16),
                  children: List.generate(
                      6,
                      (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: ShimmerLoader(height: 72))),
                ),
                error: (e, _) => _ErrorView(
                    error: e.toString(),
                    onRetry: () =>
                        ref.invalidate(txHistoryProvider(histState))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: NeonColors.primary, surface: NeonColors.surface)),
          child: child!),
    );
    if (picked != null) {
      ref.read(txHistoryStateProvider.notifier).setRange(
          picked.start,
          picked.end
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)));
    }
  }

  void _showDetail(TxItem tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TxDetailSheet(tx: tx),
    );
  }
}

// === Header ===
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onPickRange;
  final bool hasRange;
  final VoidCallback onClearRange;
  const _Header(
      {required this.onBack,
      required this.searchCtrl,
      required this.onSearch,
      required this.onClearSearch,
      required this.onPickRange,
      required this.hasRange,
      required this.onClearRange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(bottom: BorderSide(color: NeonColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: NeonColors.primary),
                  onPressed: onBack),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: NeonGradients.cta,
                    boxShadow: [
                      BoxShadow(
                          color: NeonColors.info.withValues(alpha: 0.22),
                          blurRadius: 8)
                    ]),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Historique',
                      style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          color: NeonColors.textPrimary,
                          fontSize: 16))),
              IconButton(
                  icon: Icon(
                      hasRange
                          ? Icons.filter_alt_off_rounded
                          : Icons.date_range_rounded,
                      color: hasRange
                          ? NeonColors.warning
                          : NeonColors.textSecondary),
                  tooltip:
                      hasRange ? 'Effacer filtre date' : 'Filtrer par date',
                  onPressed: hasRange ? onClearRange : onPickRange),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            onSubmitted: onSearch,
            style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher référence, jeu, type…',
              hintStyle: const TextStyle(
                  color: NeonColors.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: NeonColors.textSecondary, size: 18),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: onClearSearch)
                  : null,
              isDense: true,
              filled: true,
              fillColor: NeonColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: NeonColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: NeonColors.primary, width: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

// === Filtres ===
class _FilterBar extends StatelessWidget {
  final TxFilter current;
  final ValueChanged<TxFilter> onChanged;
  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (TxFilter.all, 'Tout', Icons.all_inclusive_rounded),
      (TxFilter.wiga, 'Wiga', Icons.monetization_on_rounded),
      (TxFilter.game, 'Jeu', Icons.casino_rounded),
      (TxFilter.promo, 'Promo', Icons.campaign_rounded),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: NeonColors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((e) {
            final sel = current == e.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.$3,
                      size: 14,
                      color: sel ? Colors.white : NeonColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(e.$2)
                ]),
                selected: sel,
                onSelected: (_) => onChanged(e.$1),
                selectedColor: NeonColors.primary,
                backgroundColor: NeonColors.surface,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : NeonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500),
                side: BorderSide(
                    color: sel ? NeonColors.primary : NeonColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// === Résumé ===
class _SummaryStrip extends StatelessWidget {
  final List<TxItem> items;
  const _SummaryStrip({required this.items});
  @override
  Widget build(BuildContext context) {
    final dep = items
        .where((x) => x.kind == TxKind.purchase || x.kind == TxKind.deposit)
        .fold<int>(0, (a, b) => a + b.amount.abs());
    final gift = items
        .where((x) => x.kind == TxKind.gift)
        .fold<int>(0, (a, b) => a + b.amount.abs());
    final win = items
        .where((x) => x.kind == TxKind.win)
        .fold<int>(0, (a, b) => a + b.amount);
    final bet = items
        .where((x) => x.kind == TxKind.bet)
        .fold<int>(0, (a, b) => a + b.amount.abs());
    final perdu = (bet - win).clamp(0, bet);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: NeonCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            _Sum(
                label: 'Acheté',
                v: dep,
                c: NeonColors.success,
                icon: Icons.shopping_cart_rounded),
            Container(width: 1, height: 36, color: NeonColors.border),
            _Sum(
                label: 'Perdue',
                v: perdu,
                c: NeonColors.error,
                icon: Icons.trending_down_rounded),
            Container(width: 1, height: 36, color: NeonColors.border),
            _Sum(
                label: 'Gagné',
                v: win,
                c: NeonColors.rankGold,
                icon: Icons.emoji_events_rounded),
            Container(width: 1, height: 36, color: NeonColors.border),
            _Sum(
                label: 'Cadeaux',
                v: gift,
                c: NeonColors.secondary,
                icon: Icons.card_giftcard_rounded),
          ],
        ),
      ),
    );
  }
}

class _Sum extends StatelessWidget {
  final String label;
  final int v;
  final Color c;
  final IconData icon;
  const _Sum(
      {required this.label,
      required this.v,
      required this.c,
      required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            FittedBox(
                child: Text(_fmt(v),
                    style: TextStyle(
                        color: c,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: 11))),
          ],
        ),
      );
  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// === Liste groupée ===
class _GroupedList extends StatelessWidget {
  final List<TxItem> items;
  final ValueChanged<TxItem> onTap;
  final ScrollController scrollCtrl;
  const _GroupedList(
      {required this.items, required this.onTap, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<TxItem>>{};
    for (final t in items) {
      final k = _dateKey(t.ts);
      grouped.putIfAbsent(k, () => []).add(t);
    }
    final keys = grouped.keys.toList();
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: keys.length,
      itemBuilder: (c, i) {
        final k = keys[i];
        final list = grouped[k]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(k,
                  style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ),
            ...list.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TxTile(tx: e, onTap: () => onTap(e)))),
          ],
        );
      },
    );
  }

  String _dateKey(DateTime d) {
    try {
      final now = DateTime.now();
      final a = DateTime(d.year, d.month, d.day);
      final b = DateTime(now.year, now.month, now.day);
      final diff = b.difference(a).inDays;
      if (diff == 0) return "Aujourd'hui";
      if (diff == 1) return 'Hier';
      if (diff < 7) {
        try {
          return DateFormat('EEEE', 'fr_FR').format(d);
        } catch (_) {
          return DateFormat('EEEE').format(d);
        }
      }
      try {
        return DateFormat('dd MMM yyyy', 'fr_FR').format(d);
      } catch (_) {
        return DateFormat('dd/MM/yyyy').format(d);
      }
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }
}

// === Table desktop ===
class _TableView extends StatelessWidget {
  final List<TxItem> items;
  final ValueChanged<TxItem> onTap;
  const _TableView({required this.items, required this.onTap});

  String _gameName(String? raw) {
    if (raw == null) return '';
    final v = raw.toLowerCase();
    if (v.contains('dice')) return 'Dés';
    if (v.contains('ludo')) return 'Ludo';
    if (v.contains('card')) return 'Cartes';
    return raw;
  }

  IconData _gameIcon(String? raw) {
    if (raw == null) return Icons.sports_esports_rounded;
    final v = raw.toLowerCase();
    if (v.contains('dice')) return Icons.casino_rounded;
    if (v.contains('ludo')) return Icons.grid_on_rounded;
    if (v.contains('card')) return Icons.style_rounded;
    return Icons.sports_esports_rounded;
  }

  String _labelFor(TxItem e) {
    if (e.kind == TxKind.bet ||
        e.kind == TxKind.win ||
        e.kind == TxKind.commission) {
      final g = _gameName(e.game);
      if (g.isNotEmpty) {
        if (e.kind == TxKind.bet) return 'Joué • $g';
        if (e.kind == TxKind.win) return 'Gagné • $g';
        return '$g • ${e.kind.label}';
      }
    }
    return e.kind.label;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: NeonCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                  color: NeonColors.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12))),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Type',
                          style: TextStyle(
                              color: NeonColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 2,
                      child: Text('Montant',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: NeonColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 2,
                      child: Text('Solde',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: NeonColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 3,
                      child: Text('Date',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: NeonColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const Divider(height: 1, color: NeonColors.border),
            ...items.map(
              (e) => InkWell(
                onTap: () => onTap(e),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: NeonColors.border))),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Icon(e.kind.icon, size: 16, color: e.kind.color),
                            if (e.game != null) ...[
                              const SizedBox(width: 4),
                              Icon(_gameIcon(e.game),
                                  size: 12,
                                  color: NeonColors.primary
                                      .withValues(alpha: 0.85)),
                            ],
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(_labelFor(e),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: NeonColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      Expanded(
                          flex: 2,
                          child: Text(
                              '${e.isCredit ? '+' : ''}${_fmt(e.amount)} wiga',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: e.isCredit
                                      ? NeonColors.success
                                      : NeonColors.error,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12))),
                      Expanded(
                          flex: 2,
                          child: Text(_fmt(e.balanceAfter),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: NeonColors.textSecondary,
                                  fontSize: 11))),
                      Expanded(
                          flex: 3,
                          child: Text(DateFormat('dd/MM HH:mm').format(e.ts),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: NeonColors.textSecondary,
                                  fontSize: 11))),
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

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// === Tuile ===
class _TxTile extends StatelessWidget {
  final TxItem tx;
  final VoidCallback onTap;
  const _TxTile({required this.tx, required this.onTap});

  String _gameName(String? raw) {
    if (raw == null) return '';
    final v = raw.toLowerCase();
    if (v.contains('dice')) return 'Dés';
    if (v.contains('ludo')) return 'Ludo';
    if (v.contains('card')) return 'Cartes';
    if (v.contains('room')) return 'Salon';
    return raw;
  }

  IconData _gameIcon(String? raw) {
    if (raw == null) return Icons.sports_esports_rounded;
    final v = raw.toLowerCase();
    if (v.contains('dice')) return Icons.casino_rounded;
    if (v.contains('ludo')) return Icons.grid_on_rounded;
    if (v.contains('card')) return Icons.style_rounded;
    return Icons.sports_esports_rounded;
  }

  String _displayLabel() {
    if (tx.kind == TxKind.bet ||
        tx.kind == TxKind.win ||
        tx.kind == TxKind.commission) {
      final g = _gameName(tx.game);
      if (g.isNotEmpty) {
        if (tx.kind == TxKind.bet) return 'Joué • $g';
        if (tx.kind == TxKind.win) return 'Gagné • $g';
        return '$g • ${tx.kind.label}';
      }
    }
    return tx.kind.label;
  }

  @override
  Widget build(BuildContext context) {
    final label = _displayLabel();
    final isGame = tx.kind == TxKind.bet ||
        tx.kind == TxKind.win ||
        tx.kind == TxKind.commission;
    return NeonCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: tx.kind.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(tx.kind.icon, color: tx.kind.color, size: 20),
              ),
              if (isGame && tx.game != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                        color: NeonColors.surface,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: NeonColors.primary, width: 1.2)),
                    child: Icon(_gameIcon(tx.game),
                        size: 10, color: NeonColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: NeonColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13))),
                    if (isGame && tx.game != null) ...[
                      const SizedBox(width: 6),
                      GlowBadge(
                          text: _gameName(tx.game), color: NeonColors.primary)
                    ],
                    const Spacer(),
                    if (tx.status == 'pending')
                      const GlowBadge(
                          text: 'EN ATTENTE', color: NeonColors.warning),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    '${tx.ref.isEmpty ? tx.id : tx.ref} • ${DateFormat('HH:mm').format(tx.ts)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NeonColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${tx.isCredit ? '+' : ''}${_fmt(tx.amount)}',
                  style: TextStyle(
                      color:
                          tx.isCredit ? NeonColors.success : NeonColors.error,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text('Solde ${_fmt(tx.balanceAfter)}',
                  style: const TextStyle(
                      color: NeonColors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// === Detail sheet ===
class _TxDetailSheet extends StatelessWidget {
  final TxItem tx;
  const _TxDetailSheet({required this.tx});
  String _gameName(String? raw) {
    if (raw == null) return '';
    final v = raw.toLowerCase();
    if (v.contains('dice')) return 'Jeu de Dés';
    if (v.contains('ludo')) return 'Ludo';
    if (v.contains('card')) return 'Cartes';
    return raw;
  }

  IconData _gameIcon(String? raw) {
    if (raw == null) return Icons.sports_esports_rounded;
    final v = raw.toLowerCase();
    if (v.contains('dice')) return Icons.casino_rounded;
    if (v.contains('ludo')) return Icons.grid_on_rounded;
    if (v.contains('card')) return Icons.style_rounded;
    return Icons.sports_esports_rounded;
  }

  String _labelFor() {
    if (tx.kind == TxKind.bet ||
        tx.kind == TxKind.win ||
        tx.kind == TxKind.commission) {
      final g = _gameName(tx.game);
      if (g.isNotEmpty) {
        if (tx.kind == TxKind.bet) return 'Joué • $g';
        if (tx.kind == TxKind.win) return 'Gagné • $g';
        return '$g • ${tx.kind.label}';
      }
    }
    return tx.kind.label;
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'completed':
        return 'Terminée';
      case 'failed':
        return 'Échouée';
      case 'cancelled':
        return 'Annulée';
      default:
        return s;
    }
  }

  String _rawTypeLabel(String s) {
    final v = s.toLowerCase();
    switch (v) {
      case 'deposit':
        return 'Dépôt';
      case 'withdraw':
      case 'withdrawal':
        return 'Retrait';
      case 'bet':
        return 'Joué';
      case 'win':
      case 'winnings':
        return 'Gagné';
      case 'commission':
        return 'Commission';
      case 'refund':
        return 'Remboursement';
      case 'purchase':
      case 'token_purchase':
        return 'Achat';
      case 'gift':
      case 'gift_sent':
      case 'gift_received':
        return 'Cadeau';
      case 'promo':
      case 'promo_credit':
      case 'promo_debit':
        return 'Promo';
      default:
        return s;
    }
  }

  String _dateLabel() {
    try {
      return DateFormat('EEEE dd MMMM yyyy • HH:mm', 'fr_FR').format(tx.ts);
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(tx.ts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: NeonColors.border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: tx.kind.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child:
                            Icon(tx.kind.icon, color: tx.kind.color, size: 26)),
                    if (tx.game != null)
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                              color: NeonColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: NeonColors.primary, width: 1.4)),
                          child: Icon(_gameIcon(tx.game),
                              size: 12, color: NeonColors.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_labelFor(),
                          style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(_dateLabel(),
                          style: const TextStyle(
                              color: NeonColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Text('${tx.isCredit ? '+' : ''}${_fmt(tx.amount)} wiga',
                    style: TextStyle(
                        color:
                            tx.isCredit ? NeonColors.success : NeonColors.error,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            _row('Référence', tx.ref.isEmpty ? tx.id : tx.ref),
            _row('Statut', _statusLabel(tx.status),
                color: tx.status.toLowerCase() == 'pending'
                    ? NeonColors.warning
                    : NeonColors.success),
            _row('Type brut', _rawTypeLabel(tx.rawType)),
            if (tx.game != null) _row('Jeu', _gameName(tx.game)),
            _row('Solde après', '${_fmt(tx.balanceAfter)} wiga'),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: NeonButton(
                    text: 'Fermer',
                    variant: NeonButtonVariant.outline,
                    onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: const TextStyle(
                    color: NeonColors.textSecondary, fontSize: 12)),
            Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: color ?? NeonColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      );
  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// === Empty / Error ===
class _EmptyState extends StatelessWidget {
  final TxFilter filter;
  final bool hasRange;
  const _EmptyState({required this.filter, required this.hasRange});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  filter == TxFilter.promo
                      ? Icons.campaign_outlined
                      : Icons.receipt_long_rounded,
                  size: 64,
                  color: NeonColors.textSecondary.withValues(alpha: 0.32)),
              const SizedBox(height: 12),
              Text(
                  filter == TxFilter.all
                      ? 'Aucune transaction'
                      : 'Aucun résultat',
                  style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  hasRange
                      ? 'Essayez une autre période ou filtre.'
                      : 'Vos achats, mises et gains apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: NeonColors.textSecondary.withValues(alpha: 0.72),
                      fontSize: 12)),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: NeonColors.error, size: 48),
            const SizedBox(height: 10),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: NeonColors.error, fontSize: 12))),
            const SizedBox(height: 12),
            NeonButton(
                text: 'Réessayer',
                icon: Icons.refresh_rounded,
                onPressed: onRetry),
          ],
        ),
      );
}

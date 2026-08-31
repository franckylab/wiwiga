// ============================================================
// Fichier: game_detail_screen.dart
// Description: Page détail d'un jeu (Aperçu, Classement, Règles, Astuces)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-30
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_room_model.dart';
import '../../../data/models/game_stats_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/game_stats_providers.dart';
import '../../widgets/auth/auth_gate.dart';
import '../../widgets/neon/neon_widgets.dart';

final _tokenFormat = NumberFormat('#,##0', 'fr_FR');

/// Formate un montant en wiga
String formatTokens(int tokens) => _tokenFormat.format(tokens);

/// Écran Détail d'un jeu : héro + 4 onglets + CTA sticky
class GameDetailScreen extends ConsumerStatefulWidget {
  final String gameType;

  const GameDetailScreen({super.key, required this.gameType});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailProvider(widget.gameType));

    return Scaffold(
      backgroundColor: NeonColors.surface,
      body: gameAsync.when(
        data: (game) => _buildContent(game),
        loading: () => ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            ShimmerLoader(height: 140),
            SizedBox(height: 16),
            ShimmerLoader(height: 300),
          ],
        ),
        error: (error, _) => _buildError(),
      ),
      bottomNavigationBar: gameAsync.maybeWhen(
        data: (game) => game.comingSoon ? null : _buildStickyCta(game),
        orElse: () => null,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: NeonColors.error),
          const SizedBox(height: 12),
          const Text('Jeu introuvable',
              style: TextStyle(color: NeonColors.textSecondary, fontSize: 15),),
          const SizedBox(height: 16),
          NeonButton(
            text: 'Retour au catalogue',
            width: 220,
            variant: NeonButtonVariant.outline,
            onPressed: () => context.go('/games'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(GameModel game) {
    return Column(
      children: [
        _buildHero(game),
        Container(
          decoration: const BoxDecoration(
            color: NeonColors.background,
            border: Border(bottom: BorderSide(color: NeonColors.border)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: NeonColors.primary,
            labelColor: NeonColors.primary,
            unselectedLabelColor: NeonColors.textSecondary,
            labelStyle: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13,),
            tabs: const [
              Tab(text: 'Aperçu'),
              Tab(text: 'Classement'),
              Tab(text: 'Règles'),
              Tab(text: 'Astuces'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(gameType: widget.gameType),
              _LeaderboardTab(gameType: widget.gameType),
              _RulesTab(gameType: widget.gameType),
              _TipsTab(gameType: widget.gameType),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(GameModel game) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: NeonColors.background,
        border: Border(bottom: BorderSide(color: NeonColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: NeonColors.primary),
            tooltip: 'Retour au catalogue',
            onPressed: () => context.go('/games'),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: NeonGradients.cta,
              boxShadow: [
                BoxShadow(
                  color: NeonColors.primary.withValues(alpha: NeonGlow.opacityMedium),
                  blurRadius: NeonGlow.blurSmall,
                ),
              ],
            ),
            child: const Icon(Icons.casino_outlined,
                size: 34, color: NeonColors.background,),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NeonColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GlowBadge(
                      text: '${game.playersOnline} en ligne',
                      color: NeonColors.success,
                    ),
                    GlowBadge(
                      text:
                          'Mise ${_tokenFormat.format(game.minBet.toInt())} - ${_tokenFormat.format(game.maxBet.toInt())} wiga',
                      color: NeonColors.secondary,
                    ),
                    GlowBadge(
                      text:
                          'Commission ${(game.houseEdge * 100).toStringAsFixed(0)}%',
                      color: NeonColors.info,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyCta(GameModel game) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: NeonColors.background,
        border: const Border(
          top: BorderSide(color: NeonColors.primary, width: NeonGlow.borderWidth),
        ),
        boxShadow: [
          BoxShadow(
            color: NeonColors.primary.withValues(alpha: NeonGlow.opacityLow),
            blurRadius: NeonGlow.blurSmall,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: AuthGate(
                type: AuthGateType.softWall,
                action: () => context.go('/games/${widget.gameType}/lobby'),
                child: const NeonButton(
                  text: 'JOUER',
                  icon: Icons.sports_esports,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AuthGate(
                type: AuthGateType.softWall,
                action: () => _showQuickMatchSheet(game),
                child: const NeonButton(
                  text: 'Partie rapide',
                  icon: Icons.bolt,
                  variant: NeonButtonVariant.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickMatchSheet(GameModel game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickMatchSheet(gameType: widget.gameType, game: game),
    );
  }
}

// ============================================================
// BOTTOM SHEET PARTIE RAPIDE
// ============================================================

class _QuickMatchSheet extends ConsumerStatefulWidget {
  final String gameType;
  final GameModel game;

  const _QuickMatchSheet({required this.gameType, required this.game});

  @override
  ConsumerState<_QuickMatchSheet> createState() => _QuickMatchSheetState();
}

class _QuickMatchSheetState extends ConsumerState<_QuickMatchSheet> {
  static const List<int> _betPresets = [10, 25, 50, 100, 250, 500, 1000];

  int _betAmount = 50;
  String _ruleType = 'normal';
  bool _isSearching = false;
  String? _error;

  Future<void> _startQuickMatch() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final repo = ref.read(gameRepositoryProvider);
      final result = await repo.joinGame(
        gameId: widget.gameType,
        betAmount: _betAmount,
      );

      if (!mounted) return;
      final status = result['status'] as String?;

      if (status == 'matched') {
        final gameId = result['game_id'] as String? ?? '';
        Navigator.of(context).pop();
        context.push(
          '/games/${widget.gameType}/session/$gameId',
          extra: {'bet_amount': _betAmount},
        );
      } else {
        // En file d'attente : rediriger vers le lobby en attendant l'adversaire
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'En file d\'attente... un adversaire arrive bientôt !',
              style: TextStyle(color: NeonColors.primary),
            ),
          ),
        );
        context.go('/games/${widget.gameType}/lobby');
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'GameDetail._startQuickMatch');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = ErrorHandler.userMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: NeonColors.secondary),
              SizedBox(width: 8),
              Text(
                'Partie rapide',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choisissez votre mise, on vous trouve un adversaire.',
            style: TextStyle(fontSize: 13, color: NeonColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Mise (wiga)',
                  style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              TokenStack(count: (_betAmount / 50).clamp(1, 5).round(), size: 20, metal: TokenMetal.emerald, altMetal: TokenMetal.gold),
            ],
          ),
          const SizedBox(height: 8),
          TokenChipGroup(
            amounts: _betPresets,
            selectedAmount: _betAmount,
            onSelected: (v) => setState(() => _betAmount = v),
            chipSize: 38,
          ),
          const SizedBox(height: 20),
          const Text('Règle',
              style: TextStyle(
                  color: NeonColors.textPrimary, fontWeight: FontWeight.bold,),),
          const SizedBox(height: 8),
          Row(
            children: [
              _ruleChip('normal', 'Normal'),
              const SizedBox(width: 8),
              _ruleChip('cible', 'Cible'),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: NeonColors.error, fontSize: 13),),
          ],
          const SizedBox(height: 24),
          NeonButton(
            text: _isSearching ? 'Recherche...' : 'Trouver un adversaire',
            icon: Icons.bolt,
            width: double.infinity,
            isLoading: _isSearching,
            onPressed: _isSearching ? () {} : _startQuickMatch,
          ),
        ],
      ),
    );
  }

  Widget _ruleChip(String value, String label) {
    final isSelected = _ruleType == value;
    return GestureDetector(
      onTap: () => setState(() => _ruleType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? NeonColors.primary.withValues(alpha: 0.2)
              : NeonColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? NeonColors.primary : NeonColors.border,),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? NeonColors.primary : NeonColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ONGLET APERÇU
// ============================================================

class _OverviewTab extends ConsumerWidget {
  final String gameType;

  const _OverviewTab({required this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gameStatsProvider(gameType));
    final myStatsAsync = ref.watch(myGameStatsProvider(gameType));
    final activityAsync = ref.watch(gameActivityProvider(gameType));
    final roomsAsync = ref.watch(waitingRoomsProvider(gameType));

    return RefreshIndicator(
      color: NeonColors.primary,
      backgroundColor: NeonColors.card,
      onRefresh: () async {
        ref.invalidate(gameStatsProvider(gameType));
        ref.invalidate(myGameStatsProvider(gameType));
        ref.invalidate(gameActivityProvider(gameType));
        ref.invalidate(waitingRoomsProvider(gameType));
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          statsAsync.when(
            data: (stats) => _buildStatsGrid(stats),
            loading: () => const ShimmerLoader(height: 160),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _buildMyStatsCard(myStatsAsync),
          const SizedBox(height: 20),
          _buildSectionTitle('Salles en attente', Icons.meeting_room_outlined),
          const SizedBox(height: 8),
          roomsAsync.when(
            data: (rooms) => _buildWaitingRooms(context, ref, rooms),
            loading: () => const ShimmerLoader(height: 70),
            error: (_, __) => _mutedText('Salles indisponibles'),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Activité récente', Icons.local_fire_department),
          const SizedBox(height: 8),
          activityAsync.when(
            data: (events) => _buildActivityFeed(events),
            loading: () => const ShimmerLoader(height: 120),
            error: (_, __) => _mutedText('Activité indisponible'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: NeonColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: NeonColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _mutedText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: const TextStyle(color: NeonColors.textMuted, fontSize: 13),),
    );
  }

  Widget _buildStatsGrid(GameGlobalStats stats) {
    // Backend désormais en wiga purs
    final items = [
      ('Joueurs en ligne', '${stats.playersOnline}', Icons.wifi_tethering),
      ('Parties du jour', '${stats.matchesToday}', Icons.sports_esports),
      ('Distribué aujourd\'hui', formatTokens(stats.totalDistributedToday),
          Icons.payments_outlined),
      ('Plus gros gain du jour', formatTokens(stats.biggestWinToday),
          Icons.emoji_events_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 92,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final (label, value, icon) = items[index];
        return NeonCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: NeonColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: NeonColors.textSecondary,),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: NeonColors.textPrimary,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyStatsCard(AsyncValue<MyGameStats> myStatsAsync) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: NeonColors.accent),
              SizedBox(width: 8),
              Text(
                'Mes statistiques',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NeonColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          myStatsAsync.when(
            data: (stats) => Row(
              children: [
                _myStatItem('Parties', '${stats.matchesPlayed}'),
                _myStatItem('Victoires', '${stats.wins}'),
                _myStatItem('Taux vict.', '${stats.winRate.toStringAsFixed(0)}%'),
                _myStatItem('Série', '${stats.currentStreak}'),
              ],
            ),
            loading: () => const ShimmerLoader(height: 44),
            error: (_, __) => const Text(
              'Connectez-vous pour voir vos statistiques',
              style: TextStyle(color: NeonColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Expanded : les 4 items se partagent la largeur sans déborder sur mobile
  Widget _myStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NeonColors.primary,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 11, color: NeonColors.textSecondary),),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRooms(
      BuildContext context, WidgetRef ref, List<GameRoomModel> rooms,) {
    if (rooms.isEmpty) {
      return _mutedText('Aucune salle en attente — créez la vôtre !');
    }

    return Column(
      children: rooms.take(5).map((room) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NeonCard(
            padding: const EdgeInsets.all(12),
            onTap: () => _joinRoom(context, ref, room),
            child: Row(
              children: [
                if (room.isStaked)
                  TokenCoin(size: 28, metal: TokenMetal.emerald, lod: TokenLod.bevel, showShadow: false)
                else
                  const Icon(Icons.people_outline, color: NeonColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomCode,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        room.isStaked
                            ? '${room.betAmount} wiga · ${room.playersCount}/${room.maxPlayers} joueurs · ${room.modeShortLabel}'
                            : '${room.modeShortLabel} · ${room.playersCount}/${room.maxPlayers} joueurs',
                        style: const TextStyle(
                            fontSize: 12, color: NeonColors.textSecondary,),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.login, size: 20, color: NeonColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _joinRoom(
      BuildContext context, WidgetRef ref, GameRoomModel room,) async {
    try {
      final roomRepo = ref.read(roomRepositoryProvider);
      final joined = await roomRepo.joinRoom(room.roomId);
      if (!context.mounted) return;
      context.push('/games/$gameType/room/${joined.roomId}', extra: joined);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de rejoindre la salle',
            style: TextStyle(color: NeonColors.error),
          ),
        ),
      );
    }
  }

  Widget _buildActivityFeed(List<GameActivityEvent> events) {
    if (events.isEmpty) {
      return _mutedText('Aucune victoire récente — soyez le premier !');
    }

    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: events.take(8).map((event) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.emoji_events,
                    size: 18, color: NeonColors.secondary,),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${event.name} a gagné ${formatTokens(event.amount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: NeonColors.textPrimary,),
                  ),
                ),
                Text(
                  _relativeTime(event.insertedAt),
                  style:
                      const TextStyle(fontSize: 11, color: NeonColors.textMuted),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }
}

// ============================================================
// ONGLET CLASSEMENT
// ============================================================

class _LeaderboardTab extends ConsumerStatefulWidget {
  final String gameType;

  const _LeaderboardTab({required this.gameType});

  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> {
  String _metric = 'wins';
  String _period = 'all';

  static const _metrics = [
    ('wins', 'Victoires'),
    ('total_won', 'Gains totaux'),
    ('biggest_win', 'Plus gros gain'),
  ];

  static const _periods = [
    ('day', 'Jour'),
    ('week', 'Semaine'),
    ('month', 'Mois'),
    ('all', 'Toujours'),
  ];

  bool get _isAmountMetric => _metric != 'wins';

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(gameLeaderboardProvider(
        (gameType: widget.gameType, metric: _metric, period: _period),),);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChipRow(
                _metrics,
                _metric,
                (value) => setState(() => _metric = value),
                NeonColors.primary,
              ),
              const SizedBox(height: 10),
              _buildChipRow(
                _periods,
                _period,
                (value) => setState(() => _period = value),
                NeonColors.accent,
              ),
            ],
          ),
        ),
        Expanded(
          child: leaderboardAsync.when(
            data: (board) => _buildBoard(board),
            loading: () => ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                ShimmerLoader(height: 120),
                SizedBox(height: 12),
                ShimmerLoader(height: 200),
              ],
            ),
            error: (_, __) => const Center(
              child: Text('Classement indisponible',
                  style: TextStyle(color: NeonColors.textMuted),),
            ),
          ),
        ),
        leaderboardAsync.maybeWhen(
          data: (board) => _buildMyRankBanner(board),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildChipRow(
    List<(String, String)> options,
    String selected,
    ValueChanged<String> onSelected,
    Color color,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final (value, label) = option;
          final isSelected = selected == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : NeonColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected ? color : NeonColors.border,),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? color : NeonColors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatValue(int value) =>
      _isAmountMetric ? formatTokens(value) : '$value';

  Widget _buildBoard(GameLeaderboard board) {
    if (board.entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 48, color: NeonColors.textMuted,),
            SizedBox(height: 12),
            Text(
              'Aucun classement sur cette période',
              style: TextStyle(color: NeonColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final podium = board.entries.take(3).toList();
    final rest = board.entries.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildPodium(podium),
        const SizedBox(height: 16),
        ...rest.map(_buildEntryRow),
      ],
    );
  }

  Widget _buildPodium(List<GameLeaderboardEntry> podium) {
    // Ordre visuel : 2e, 1er, 3e
    final ordered = <GameLeaderboardEntry?>[
      podium.length > 1 ? podium[1] : null,
      podium.isNotEmpty ? podium[0] : null,
      podium.length > 2 ? podium[2] : null,
    ];
    final colors = [NeonColors.rankSilver, NeonColors.rankGold, NeonColors.rankBronze];
    final heights = [86.0, 110.0, 74.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        final entry = ordered[index];
        if (entry == null) return const Expanded(child: SizedBox.shrink());
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Icon(Icons.emoji_events, color: colors[index], size: 26),
                const SizedBox(height: 4),
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: heights[index],
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors[index].withValues(alpha: 0.18),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border.all(color: colors[index].withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${entry.rank}',
                        style: TextStyle(
                          color: colors[index],
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            _formatValue(entry.value),
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEntryRow(GameLeaderboardEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeonCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  color: NeonColors.primary,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: NeonColors.textPrimary),
              ),
            ),
            Text(
              _formatValue(entry.value),
              style: const TextStyle(
                color: NeonColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRankBanner(GameLeaderboard board) {
    if (board.myRank == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: NeonColors.background,
        border: Border(
          top: BorderSide(color: NeonColors.accent, width: 1),
        ),
      ),
      child: Text(
        'Votre rang : #${board.myRank}'
        '${board.myValue != null ? '  ·  ${_formatValue(board.myValue!)}' : ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: NeonColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ============================================================
// ONGLET RÈGLES
// ============================================================

class _RulesTab extends ConsumerWidget {
  final String gameType;

  const _RulesTab({required this.gameType});

  static const Map<String, String> _configLabels = {
    'sets_count': 'Nombre de sets',
    'dice_count': 'Nombre de dés',
    'min_bet': 'Mise minimum',
    'max_bet': 'Mise maximum',
    'max_players': 'Joueurs max',
    'tie_break': 'Égalités',
    'target_mode': 'Mode cible',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(gameRulesProvider(gameType));

    return rulesAsync.when(
      data: (rules) {
        if (rules.isEmpty) {
          return const Center(
            child: Text('Règles indisponibles',
                style: TextStyle(color: NeonColors.textMuted),),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: rules.map((rule) => _buildRuleCard(rule)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: ShimmerLoader(height: 200),
      ),
      error: (_, __) => const Center(
        child: Text('Règles indisponibles',
            style: TextStyle(color: NeonColors.textMuted),),
      ),
    );
  }

  Widget _buildRuleCard(GameRuleInfo rule) {
    final entries = rule.config.entries
        .where((e) => e.value is! Map && e.value is! List)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlowBadge(
                  text: rule.ruleType == 'cible' ? 'CIBLE' : 'NORMAL',
                  color: rule.ruleType == 'cible'
                      ? NeonColors.accent
                      : NeonColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rule.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              rule.description,
              style: const TextStyle(
                fontSize: 13,
                color: NeonColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NeonColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NeonColors.border),
                ),
                child: Column(
                  children: entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _configLabels[entry.key] ?? entry.key,
                            style: const TextStyle(
                                fontSize: 12,
                                color: NeonColors.textSecondary,),
                          ),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: NeonColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ONGLET ASTUCES
// ============================================================

class _TipsTab extends ConsumerWidget {
  final String gameType;

  const _TipsTab({required this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipsAsync = ref.watch(gameTipsProvider(gameType));

    return tipsAsync.when(
      data: (tips) {
        if (tips.isEmpty) {
          return const Center(
            child: Text('Aucune astuce pour le moment',
                style: TextStyle(color: NeonColors.textMuted),),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: tips.length,
          itemBuilder: (context, index) {
            final tip = tips[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeonCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeonColors.secondary.withValues(alpha: 0.15),
                      ),
                      child: const Icon(Icons.lightbulb_outline,
                          size: 20, color: NeonColors.secondary,),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: NeonColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tip.body,
                            style: const TextStyle(
                              fontSize: 13,
                              color: NeonColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: ShimmerLoader(height: 200),
      ),
      error: (_, __) => const Center(
        child: Text('Astuces indisponibles',
            style: TextStyle(color: NeonColors.textMuted),),
      ),
    );
  }
}

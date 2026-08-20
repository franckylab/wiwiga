// ============================================================
// Fichier: friends_screen.dart
// Description: Écran principal du système d'amis
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/friend_provider.dart' hide apiServiceProvider;
import '../../../data/repositories/friend_repository.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Masque partiellement un numéro de téléphone pour la confidentialité.
/// Ex: "+237691234567" → "+237 6** *** 567"
/// Garde l'indicatif et les 3 derniers chiffres, masque le reste.
String _maskPhoneNumber(String phone) {
  // Nettoyer : garder uniquement les chiffres et le '+' initial
  final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.length <= 6) return cleaned; // Trop court pour masquer

  // Extraire l'indicatif pays (2-4 chiffres après +) et les derniers chiffres
  final hasPlus = cleaned.startsWith('+');
  final digits = hasPlus ? cleaned.substring(1) : cleaned;

  // Indicatif : 3 premiers chiffres, visibles : 3 derniers, reste masqué
  const prefixLen = 3;
  const visibleEnd = 3;
  final middleLen = digits.length - prefixLen - visibleEnd;

  if (middleLen <= 0) return phone; // Numéro trop court

  final prefix = hasPlus ? '+${digits.substring(0, prefixLen)}' : digits.substring(0, prefixLen);
  final masked = '*' * middleLen;
  final visible = digits.substring(digits.length - visibleEnd);

  // Formater avec espaces pour lisibilité
  return '$prefix $masked $visible';
}

/// Écran principal des amis avec tabs
/// Si l'utilisateur est guest, affiche un écran de bienvenue avec CTA connexion
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuest || authState.isUnknown;

    // Mode guest : écran CTA
    if (isGuest) {
      return _GuestFriendsScreen(authState: authState);
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Amis'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NeonColors.primary,
          labelColor: NeonColors.primary,
          unselectedLabelColor: NeonColors.textSecondary,
          tabs: const [
            Tab(text: 'Amis', icon: Icon(Icons.people_outline, size: 18)),
            Tab(text: 'Demandes', icon: Icon(Icons.mail_outline, size: 18)),
            Tab(text: 'Activité', icon: Icon(Icons.dynamic_feed_outlined, size: 18)),
            Tab(text: 'Classement', icon: Icon(Icons.emoji_events_outlined, size: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            color: NeonColors.primary,
            onPressed: _showSearchSheet,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FriendsListTab(),
          _RequestsListTab(),
          _ActivityTab(),
          _LeaderboardTab(),
        ],
      ),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      builder: (_) => const _FriendSearchSheet(),
    );
  }
}

// === Tab 1: Liste d'amis ===

class _FriendsListTab extends ConsumerWidget {
  const _FriendsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: NeonColors.error))),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, color: NeonColors.textSecondary, size: 64),
                SizedBox(height: 16),
                Text('Aucun ami pour le moment', style: TextStyle(color: NeonColors.textSecondary, fontSize: 16)),
                SizedBox(height: 8),
                Text('Recherchez des joueurs par téléphone ou nom', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: NeonColors.primary,
          onRefresh: () async => ref.invalidate(friendsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _FriendCard(friend: friend);
            },
          ),
        );
      },
    );
  }
}

class _FriendCard extends ConsumerWidget {
  final FriendModel friend;

  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeonCard(
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: friend.isOnline ? NeonColors.success.withValues(alpha: 0.2) : NeonColors.surface,
                  child: Text(
                    friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (friend.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: NeonColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: NeonColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    friend.isInGame ? 'En partie' : (friend.isOnline ? 'En ligne' : 'Hors ligne'),
                    style: TextStyle(
                      color: friend.isInGame ? NeonColors.warning : (friend.isOnline ? NeonColors.success : NeonColors.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Bouton Jouer
            IconButton(
              icon: const Icon(Icons.sports_esports_outlined, color: NeonColors.primary),
              onPressed: () {
                context.push('/games/dice/create');
              },
              tooltip: 'Inviter à jouer',
            ),
            // Menu
            PopupMenuButton<String>(
              color: NeonColors.surface,
              icon: const Icon(Icons.more_vert, color: NeonColors.textSecondary),
              onSelected: (value) async {
                final repo = ref.read(friendRepositoryProvider);
                try {
                  if (value == 'remove') {
                    await repo.removeFriend(friend.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ami supprimé'), backgroundColor: NeonColors.success),
                      );
                    }
                  } else if (value == 'block') {
                    await repo.blockUser(friend.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Utilisateur bloqué'), backgroundColor: NeonColors.warning),
                      );
                    }
                  }
                  ref.invalidate(friendsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: NeonColors.error),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'remove', child: Text('Supprimer', style: TextStyle(color: NeonColors.error))),
                const PopupMenuItem(value: 'block', child: Text('Bloquer', style: TextStyle(color: NeonColors.error))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === Tab 2: Demandes en attente ===

class _RequestsListTab extends ConsumerWidget {
  const _RequestsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return requestsAsync.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: NeonColors.error))),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, color: NeonColors.textSecondary, size: 64),
                SizedBox(height: 16),
                Text('Aucune demande en attente', style: TextStyle(color: NeonColors.textSecondary)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: NeonColors.primary,
          onRefresh: () async => ref.invalidate(pendingRequestsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _RequestCard(request: request);
            },
          ),
        );
      },
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final FriendRequestModel request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeonCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: NeonColors.primary.withValues(alpha: 0.2),
              child: Text(
                request.fromUser.name.isNotEmpty ? request.fromUser.name[0].toUpperCase() : '?',
                style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.fromUser.name, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
                  if (request.fromUser.phone != null)
                    Text(_maskPhoneNumber(request.fromUser.phone!), style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            // Accepter
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () async {
                try {
                  final repo = ref.read(friendRepositoryProvider);
                  await repo.acceptRequest(request.id);
                  ref.invalidate(pendingRequestsProvider);
                  ref.invalidate(friendsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demande acceptée'), backgroundColor: NeonColors.success),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: NeonColors.error),
                    );
                  }
                }
              },
            ),
            // Refuser
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: () async {
                try {
                  final repo = ref.read(friendRepositoryProvider);
                  await repo.rejectRequest(request.id);
                  ref.invalidate(pendingRequestsProvider);
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }
}

// === Tab 3: Activité ===

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(friendActivityProvider);

    return activityAsync.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: NeonColors.error))),
      data: (activities) {
        if (activities.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dynamic_feed_outlined, color: NeonColors.textSecondary, size: 64),
                SizedBox(height: 16),
                Text('Aucune activité', style: TextStyle(color: NeonColors.textSecondary)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: NeonColors.primary,
          onRefresh: () async => ref.invalidate(friendActivityProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _ActivityCard(activity: activity);
            },
          ),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final FriendActivityModel activity;

  const _ActivityCard({required this.activity});

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'game_won': return Icons.emoji_events;
      case 'game_lost': return Icons.sentiment_dissatisfied;
      case 'friend_added': return Icons.person_add;
      case 'level_up': return Icons.trending_up;
      case 'bet_placed': return Icons.monetization_on;
      default: return Icons.info_outline;
    }
  }

  String _getActionText(String action) {
    switch (action) {
      case 'game_won': return 'a gagné une partie';
      case 'game_lost': return 'a perdu une partie';
      case 'friend_added': return 'a ajouté un ami';
      case 'level_up': return 'est monté de niveau';
      case 'bet_placed': return 'a placé une mise';
      case 'achievement_unlocked': return 'a débloqué un succès';
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: NeonCard(
        child: Row(
          children: [
            Icon(_getActionIcon(activity.action), color: NeonColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: activity.user.name, style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold)),
                    TextSpan(text: ' ${_getActionText(activity.action)}', style: const TextStyle(color: NeonColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Tab 4: Leaderboard ===

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(friendLeaderboardProvider);

    return leaderboardAsync.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: NeonColors.error))),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, color: NeonColors.textSecondary, size: 64),
                SizedBox(height: 16),
                Text('Classement vide', style: TextStyle(color: NeonColors.textSecondary)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: NeonColors.primary,
          onRefresh: () async => ref.invalidate(friendLeaderboardProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _LeaderboardRow(entry: entry, rank: index + 1);
            },
          ),
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final FriendLeaderboardEntry entry;
  final int rank;

  const _LeaderboardRow({required this.entry, required this.rank});

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return Colors.grey.shade300;
      case 3: return Colors.brown.shade300;
      default: return NeonColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: NeonCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getRankColor(rank).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(color: _getRankColor(rank), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(entry.name, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: NeonColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.wins} V',
                style: const TextStyle(color: NeonColors.success, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Sheet Recherche d'ami ===

class _FriendSearchSheet extends ConsumerStatefulWidget {
  const _FriendSearchSheet();

  @override
  ConsumerState<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends ConsumerState<_FriendSearchSheet> {
  final _controller = TextEditingController();
  List<PlayerSearchResult> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Rechercher un joueur', style: TextStyle(color: NeonColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(color: NeonColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Téléphone ou nom...',
              hintStyle: const TextStyle(color: NeonColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: NeonColors.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: NeonColors.primary),
                onPressed: _search,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: NeonColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: NeonColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: NeonColors.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const NeonLoadingSpinner.center()
          else
            ..._results.map((result) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: NeonColors.primary.withValues(alpha: 0.2),
                    child: Text(result.name.isNotEmpty ? result.name[0].toUpperCase() : '?', style: const TextStyle(color: NeonColors.primary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.name, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
                        if (result.phone != null) Text(_maskPhoneNumber(result.phone!), style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  NeonButton(
                    text: 'Ajouter',
                    onPressed: () => _sendFriendRequest(result),
                    height: 36,
                    fontSize: 12,
                    variant: NeonButtonVariant.outline,
                  ),
                ],
              ),
            ),),
        ],
      ),
    );
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final results = await FriendRepository(apiService).searchPlayer(query);
      setState(() { _results = results; _isSearching = false; });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(PlayerSearchResult result) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await FriendRepository(apiService).sendRequest(userId: result.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande envoyée à ${result.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}

// === Mode guest : écran CTA connexion ===

class _GuestFriendsScreen extends ConsumerWidget {
  final AuthState authState;

  const _GuestFriendsScreen({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: NeonGradients.cta,
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 40,
                  color: NeonColors.background,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Connectez-vous pour voir vos amis',
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
                'Retrouvez vos amis, invitez-les à jouer\net suivez leurs performances en temps réel.',
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
                  ref.read(authProvider.notifier).setRedirectTo('/friends');
                  context.go('/auth');
                },
                width: 220,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

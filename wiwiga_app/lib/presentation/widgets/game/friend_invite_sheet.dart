// ============================================================
// Fichier: friend_invite_sheet.dart
// Description: Bottom sheet pour inviter un ami à jouer
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/friend_model.dart';
import '../../widgets/neon/neon_button.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/friend_provider.dart';

/// Bottom sheet pour inviter un ami à rejoindre une salle
///
/// Flow:
/// 1. Affiche la liste d'amis avec statut en ligne
/// 2. Barre de recherche (phone/username)
/// 3. Bouton "Inviter" par ami
/// 4. Affichage du code de salle en backup
/// 5. Timer 30s → si pas de réponse, affiche le code
class FriendInviteSheet extends ConsumerStatefulWidget {
  final String roomCode;
  final String roomId;
  final List<String>? excludePlayerIds;

  const FriendInviteSheet({
    super.key,
    required this.roomCode,
    required this.roomId,
    this.excludePlayerIds,
  });

  @override
  ConsumerState<FriendInviteSheet> createState() => _FriendInviteSheetState();

  /// Affiche le bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String roomCode,
    required String roomId,
    List<String>? excludePlayerIds,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      isScrollControlled: true,
      builder: (_) => FriendInviteSheet(
        roomCode: roomCode,
        roomId: roomId,
        excludePlayerIds: excludePlayerIds,
      ),
    );
  }
}

class _FriendInviteSheetState extends ConsumerState<FriendInviteSheet> {
  final _searchController = TextEditingController();
  Timer? _timer;
  int _remainingSeconds = 30;
  bool _showCode = false;
  bool _isSearching = false;
  List<PlayerSearchResult> _searchResults = [];
  List<FriendModel> _friends = [];
  bool _isLoadingFriends = true;
  String? _invitedFriendId;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _startTimer();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) setState(() => _showCode = true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _loadFriends() async {
    try {
      final repo = ref.read(friendRepositoryProvider);
      final friends = await repo.listFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final repo = ref.read(friendRepositoryProvider);
      final results = await repo.searchPlayer(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  void _inviteFriend(String friendId, String friendName) {
    setState(() => _invitedFriendId = friendId);
    // Envoyer invitation via WebSocket
    final gameWs = ref.read(gameWebSocketServiceProvider);
    gameWs.sendGameInvite(friendId: friendId, roomCode: widget.roomCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation envoyée à $friendName !', style: const TextStyle(color: NeonColors.success)),
        backgroundColor: NeonColors.surface,
      ),
    );
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inviter un ami',
                style: TextStyle(color: NeonColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: NeonColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Timer
          if (!_showCode)
            Center(
              child: Text(
                'En attente de réponse... ${_remainingSeconds}s',
                style: const TextStyle(color: NeonColors.warning, fontSize: 14),
              ),
            ),

          // Code de salle (visible après timeout ou toujours en backup)
          if (_showCode) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: NeonColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Code de la salle', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié !')),
                      );
                    },
                    child: Text(
                      widget.roomCode,
                      style: const TextStyle(color: NeonColors.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Appuyez pour copier', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Barre de recherche
          TextField(
            controller: _searchController,
            style: const TextStyle(color: NeonColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher par téléphone ou nom...',
              hintStyle: const TextStyle(color: NeonColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: NeonColors.primary, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: NeonColors.primary, size: 20),
                onPressed: _search,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),

          // Résultats de recherche
          if (_isSearching)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: NeonColors.primary)))
          else if (_searchResults.isNotEmpty)
            ..._searchResults.map((r) => _buildSearchResult(r)),

          // Liste d'amis
          if (_isLoadingFriends)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: NeonColors.primary)))
          else if (_friends.isNotEmpty) ...[
            const Text('Mes amis', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _friends.length,
                itemBuilder: (context, index) => _buildFriendCard(_friends[index]),
              ),
            ),
          ] else if (!_isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun ami pour le moment', style: TextStyle(color: NeonColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendModel friend) {
    final isExcluded = widget.excludePlayerIds?.contains(friend.id.toString()) ?? false;
    final isInvited = _invitedFriendId == friend.id.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: friend.isOnline ? NeonColors.success.withValues(alpha: 0.2) : NeonColors.surface,
                child: Text(friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold),),
              ),
              if (friend.isOnline)
                Positioned(right: 0, bottom: 0, child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: NeonColors.success, shape: BoxShape.circle,
                      border: Border.all(color: NeonColors.surface, width: 2),),
                ),),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(friend.isOnline ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(color: friend.isOnline ? NeonColors.success : NeonColors.textSecondary, fontSize: 11),),
              ],
            ),
          ),
          if (isExcluded)
            const Text('Déjà dans la salle', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11))
          else if (isInvited)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: NeonColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Text('Invité ✓', style: TextStyle(color: NeonColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            NeonButton(
              text: 'Inviter',
              onPressed: () => _inviteFriend(friend.id.toString(), friend.name),
              height: 32,
              fontSize: 11,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              variant: NeonButtonVariant.outline,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResult(PlayerSearchResult result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: NeonColors.secondary.withValues(alpha: 0.2),
            child: Text(result.name.isNotEmpty ? result.name[0].toUpperCase() : '?',
                style: const TextStyle(color: NeonColors.secondary),),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                if (result.phone != null) Text(result.phone!, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          NeonButton(
            text: 'Ajouter',
            onPressed: () async {
              try {
                final repo = ref.read(friendRepositoryProvider);
                await repo.sendRequest(userId: result.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Demande envoyée à ${result.name}')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            height: 32,
            fontSize: 11,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            variant: NeonButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}

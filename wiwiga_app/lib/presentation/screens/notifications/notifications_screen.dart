// ============================================================
// Fichier: notifications_screen.dart
// Description: Inbox notifications joueur (canal in_app)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/providers/notification_provider.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Filtres d'inbox
enum _InboxFilter { all, unread, security, transactional, social, game, marketing }

extension _InboxFilterLabel on _InboxFilter {
  String get label {
    switch (this) {
      case _InboxFilter.all:
        return 'Toutes';
      case _InboxFilter.unread:
        return 'Non lues';
      case _InboxFilter.security:
        return 'Sécurité';
      case _InboxFilter.transactional:
        return 'Jetons';
      case _InboxFilter.social:
        return 'Amis';
      case _InboxFilter.game:
        return 'Jeux';
      case _InboxFilter.marketing:
        return 'Promos';
    }
  }
}

/// Écran inbox des notifications joueur
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _InboxFilter _filter = _InboxFilter.all;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Recherche serveur debouncée (400ms), reset la pagination.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(inboxProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        actions: [
          // Préférences (matrice catégories × canaux)
          IconButton(
            tooltip: 'Préférences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/notifications/preferences'),
          ),
          // Tout marquer comme lu
          IconButton(
            tooltip: 'Tout marquer comme lu',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final content = inbox.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoader(height: 88),
              ),
            ),
            error: (error, _) => _buildError(error),
            data: (page) => _buildList(page, isWide),
          );

          return Column(
            children: [
              _buildSearch(),
              _buildFilters(),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  /// Recherche serveur dans titre + corps.
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher…',
          hintStyle: const TextStyle(color: NeonColors.textSecondary, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: NeonColors.textSecondary, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, color: NeonColors.textSecondary, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: NeonColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            borderSide: const BorderSide(color: NeonColors.primary),
          ),
        ),
      ),
    );
  }

  /// Filtres par catégorie — ChoiceChip néon
  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _InboxFilter.values.map((filter) {
          final selected = _filter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              selectedColor: NeonColors.primary.withValues(alpha: 0.25),
              backgroundColor: NeonColors.surface,
              labelStyle: TextStyle(
                color: selected ? NeonColors.primary : NeonColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: selected ? NeonColors.primary : NeonColors.border,
              ),
              onSelected: (_) => setState(() => _filter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Liste filtrée avec pull-to-refresh, suppression swipe et pagination.
  Widget _buildList(InboxPage page, bool isWide) {
    final items = page.items;
    final filtered = items.where((notif) {
      switch (_filter) {
        case _InboxFilter.all:
          return true;
        case _InboxFilter.unread:
          return !notif.isRead;
        case _InboxFilter.security:
          return notif.category == 'security';
        case _InboxFilter.transactional:
          return notif.category == 'transactional';
        case _InboxFilter.social:
          return notif.category == 'social';
        case _InboxFilter.game:
          return notif.category == 'game';
        case _InboxFilter.marketing:
          return notif.category == 'marketing';
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: NeonColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucune notification',
              style: TextStyle(color: NeonColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            NeonButton(
              text: 'Découvrir les jeux',
              onPressed: () => context.go('/games'),
              variant: NeonButtonVariant.secondary,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: NeonColors.primary,
      backgroundColor: NeonColors.surface,
      onRefresh: () async {
        await ref.read(inboxProvider.notifier).refreshInbox();
        ref.invalidate(unreadNotificationsCountProvider);
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 12,
          vertical: 8,
        ),
        itemCount: filtered.length + (page.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filtered.length) return _buildLoadMore(page);
          return _buildItem(filtered[index]);
        },
      ),
    );
  }

  /// Bouton de pagination ("12 sur 48").
  Widget _buildLoadMore(InboxPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: NeonButton(
          text: 'Charger plus (${page.items.length}/${page.total})',
          onPressed: () => ref.read(inboxProvider.notifier).loadMore(),
          variant: NeonButtonVariant.outline,
        ),
      ),
    );
  }

  /// Carte notification — tap = ouvrir, poubelle = supprimer (confirmée).
  Widget _buildItem(NotificationModel notif) {
    final accent = _categoryColor(notif.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonCard(
        onTap: () => _openNotification(notif),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pastille catégorie
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(_categoryIcon(notif.category), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: NeonColors.textPrimary,
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // Point non-lu avec pulse
                      if (!notif.isRead)
                        GlowBadge(text: '', color: accent),
                      // Suppression explicite (48px, accessible)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: NeonColors.textSecondary,
                        tooltip: 'Supprimer',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        padding: EdgeInsets.zero,
                        onPressed: () => _confirmDelete(notif),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: const TextStyle(color: NeonColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notif.insertedAt),
                    style: TextStyle(
                      color: NeonColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: NeonColors.error),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger les notifications',
            style: TextStyle(color: NeonColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          NeonButton(
            text: 'Réessayer',
            onPressed: () => ref.invalidate(inboxProvider),
            variant: NeonButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  /// Tap : marque comme lue puis navigue vers l'écran concerné.
  Future<void> _openNotification(NotificationModel notif) async {
    await _markAsRead(notif);
    if (!mounted) return;

    final route = _routeFor(notif);
    if (route != null) context.push(route);
  }

  /// Destination : deep-link serveur (allowlist) puis repli par événement.
  String? _routeFor(NotificationModel notif) {
    final action = notif.safeAction;
    if (action != null) return action;

    switch (notif.eventType) {
      case 'friend_request':
      case 'friend_accepted':
        return '/friends';
      case 'wallet_credit':
      case 'wallet_debit':
      case 'cash_withdraw':
        return '/transactions';
      case 'match_result':
        return '/games';
      case 'achievement_unlocked':
        return '/profile';
      case 'promo_broadcast':
      case 'admin_broadcast':
        return null;
      default:
        return notif.category == 'social' ? '/friends' : null;
    }
  }

  Future<void> _markAsRead(NotificationModel notif) async {
    if (notif.isRead) return;
    try {
      await ref.read(notificationRepositoryProvider).markAsRead(notif.id);
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // Erreur silencieuse : l'inbox reste cohérente au prochain refresh
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // Erreur silencieuse
    }
  }

  Future<void> _deleteNotification(NotificationModel notif) async {
    try {
      await ref.read(inboxProvider.notifier).deleteNotification(notif.id);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suppression impossible, réessayez')),
        );
      }
    }
  }

  /// Confirmation de suppression (pas d'annulation possible côté serveur).
  Future<void> _confirmDelete(NotificationModel notif) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: const Text('Supprimer ?', style: TextStyle(color: NeonColors.textPrimary, fontSize: 16)),
        content: const Text(
          'Cette notification sera définitivement supprimée de votre inbox.',
          style: TextStyle(color: NeonColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: NeonColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteNotification(notif);
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'security':
        return NeonColors.error;
      case 'transactional':
        return NeonColors.success;
      case 'social':
        return NeonColors.accent;
      case 'game':
        return NeonColors.secondary;
      case 'marketing':
        return NeonColors.tokenGold;
      default:
        return NeonColors.primary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'security':
        return Icons.shield_rounded;
      case 'transactional':
        return Icons.monetization_on_rounded;
      case 'social':
        return Icons.people_rounded;
      case 'game':
        return Icons.casino_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _relativeTime(String iso) {
    try {
      final date = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return "À l'instant";
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      return 'Il y a ${diff.inDays} j';
    } catch (_) {
      return '';
    }
  }
}

// ============================================================
// Fichier: notification_provider.dart
// Description: Providers Riverpod pour les notifications joueur
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../repositories/notification_repository.dart';
import '../models/notification_model.dart';
import '../services/push_notification_service.dart';
import 'app_providers.dart';

/// Provider pour le NotificationRepository — réutilise l'ApiService centralisé
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return NotificationRepository(apiService);
});

/// Page d'inbox (pagination "Charger plus")
typedef InboxPage = ({List<NotificationModel> items, int total, bool hasMore});

/// Inbox paginée : pull-to-refresh, ajout de pages, suppression optimiste.
class InboxNotifier extends AutoDisposeAsyncNotifier<InboxPage> {
  static const _limit = 20;
  int _page = 1;
  String _query = '';

  @override
  Future<InboxPage> build() async {
    _page = 1;
    return _loadPage(1, previous: null);
  }

  /// Recherche serveur (debouncée côté écran), reset la pagination.
  Future<void> setQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed == _query) return;
    _query = trimmed;
    await refreshInbox();
  }

  /// Recharge depuis la première page.
  Future<void> refreshInbox() async {
    state = const AsyncLoading();
    _page = 1;
    state = await AsyncValue.guard(() => _loadPage(1, previous: null));
  }

  /// Charge la page suivante et fusionne (sans doublon).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || state.isLoading) return;
    final nextPage = _page + 1;
    try {
      final next = await _loadPage(nextPage, previous: current);
      _page = nextPage;
      state = AsyncData(next);
    } catch (_) {
      // Page suivante indisponible : on garde l'existant
    }
  }

  /// Suppression optimiste (rollback visuel au prochain refresh si échec).
  Future<void> deleteNotification(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(notificationRepositoryProvider);
    final kept = current.items.where((n) => n.id != id).toList();
    state = AsyncData((items: kept, total: current.total - 1, hasMore: current.hasMore));
    try {
      await repo.deleteNotification(id);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // Échec : recharge l'état serveur
      await refreshInbox();
      rethrow;
    }
  }

  Future<InboxPage> _loadPage(int page, {InboxPage? previous}) async {
    final repo = ref.read(notificationRepositoryProvider);
    final result = await repo.listNotifications(
      page: page,
      limit: _limit,
      query: _query.isEmpty ? null : _query,
    );
    final items = [...?previous?.items, ...result.items];
    // Déduplique par id (chevauchement éventuel entre pages)
    final seen = <int>{};
    final unique = items.where((n) => seen.add(n.id)).toList();
    return (
      items: unique,
      total: result.total,
      hasMore: unique.length < result.total,
    );
  }
}

/// Provider de l'inbox paginée.
final inboxProvider = AutoDisposeAsyncNotifierProvider<InboxNotifier, InboxPage>(
  InboxNotifier.new,
);

/// Provider pour le compteur de non-lues (badge cloche) — 30s
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final repo = ref.watch(notificationRepositoryProvider);
  try {
    return await repo.getUnreadCount();
  } catch (e) {
    return 0;
  }
});

/// Provider pour les préférences de notification
final notificationPreferencesProvider =
    FutureProvider.autoDispose<List<NotificationPreferenceModel>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  try {
    return await repo.listPreferences();
  } catch (e) {
    rethrow;
  }
});

/// Provider du service push FCM (dégradation gracieuse si non configuré)
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

/// Initialisation push : permissions, token → backend, tap → inbox.
/// À watcher une fois au démarrage (voir WiwigaApp).
final pushInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(pushNotificationServiceProvider);
  final repo = ref.watch(notificationRepositoryProvider);

  await service.initialize(
    onToken: (token) async {
      try {
        await repo.registerDeviceToken(platform: service.platform, token: token);
      } catch (_) {
        // Backend injoignable : le token sera renvoyé au prochain refresh
      }
    },
    onTap: (_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.go('/notifications');
      }
    },
  );
  // Permission demandée au login (registerPushToken), pas aux invités.
});

/// Enregistre le token FCM courant (après login).
Future<void> registerPushToken(WidgetRef ref) async {
  try {
    final service = ref.read(pushNotificationServiceProvider);
    await service.requestPermission();
    final token = await service.getToken();
    if (token == null || token.isEmpty) return;
    await ref.read(notificationRepositoryProvider).registerDeviceToken(
          platform: service.platform,
          token: token,
        );
  } catch (_) {
    // Push optionnel : l'inbox in_app reste disponible
  }
}

/// Supprime le token FCM (logout).
Future<void> unregisterPushToken(WidgetRef ref) async {
  try {
    final service = ref.read(pushNotificationServiceProvider);
    final token = await service.getToken();
    if (token != null && token.isNotEmpty) {
      await ref.read(notificationRepositoryProvider).unregisterDeviceToken(token);
    }
    await service.deleteToken();
  } catch (_) {}
}

// ============================================================
// Fichier: notification_provider.dart
// Description: Providers Riverpod pour les notifications joueur
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../presentation/widgets/notifications/in_app_notification_banner.dart';
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
    state = AsyncData(
        (items: kept, total: current.total - 1, hasMore: current.hasMore),);
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
final inboxProvider =
    AutoDisposeAsyncNotifierProvider<InboxNotifier, InboxPage>(
  InboxNotifier.new,
);

/// Provider pour le compteur de non-lues (badge cloche) — 30s
final unreadNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
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
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
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
        await repo.registerDeviceToken(
            platform: service.platform, token: token,);
        if (kDebugMode) {
          // ignore: avoid_print
          debugPrint('[Push] token renouvelé enregistré (${service.platform})');
        }
      } catch (_) {
        // Backend injoignable : le token sera renvoyé au prochain refresh
        if (kDebugMode) {
          // ignore: avoid_print
          debugPrint(
              '[Push] échec enregistrement token (repli au prochain refresh)',);
        }
      }
    },
    onTap: (_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.go('/notifications');
      }
    },
    // Foreground : l'inbox se rafraîchit sur toutes plateformes ; sur Web
    // (pas de notification locale FCM) on affiche en plus la bannière basse
    // unifiée (dual-surface : toast fiable + OS best-effort, comme
    // Slack/Gmail/Discord). Fermer = masque local, Supprimer = efface
    // l'inbox serveur, Voir = ouvre l'inbox.
    onForeground: (message) async {
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      if (!kIsWeb) return;
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final data = message.data;
      final title = (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : (message.notification?.title ?? 'WIWIGA');
      final body = (data['body'] as String?)?.trim().isNotEmpty == true
          ? (data['body'] as String).trim()
          : (message.notification?.body ?? '');
      showInAppNotificationBanner(
        context,
        data: (
          id: parseInAppNotificationId(data),
          title: title,
          body: body,
          category: parseInAppCategory(data['category']),
          priority: parseInAppPriority(data['priority']),
        ),
        onView: () {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) ctx.go('/notifications');
        },
        onDelete: () => deleteInAppNotification(ref, data),
      );
    },
  );
  // Permission demandée au login (registerPushToken), pas aux invités.
});

/// Enregistre le token FCM courant (après login).
/// `requestPermission: false` = tentative silencieuse (sans prompt OS) :
/// n'enregistre que si un token est déjà disponible (permission déjà
/// accordée). Utilisé quand l'utilisateur reporte l'opt-in.
Future<void> registerPushToken(WidgetRef ref,
    {bool requestPermission = true,}) async {
  try {
    final service = ref.read(pushNotificationServiceProvider);
    if (requestPermission) {
      await service.requestPermission();
    }
    final token = await service.getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        // ignore: avoid_print
        debugPrint(
            '[Push] non enregistré : ${service.lastDiagnostic ?? 'raison inconnue'}',);
      }
      return;
    }
    await ref.read(notificationRepositoryProvider).registerDeviceToken(
          platform: service.platform,
          token: token,
        );
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint('[Push] token enregistré (${service.platform})');
    }
  } catch (_) {
    // Push optionnel : l'inbox in_app reste disponible
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint('[Push] enregistrement impossible (backend injoignable ?)');
    }
  }
}

/// Extrait l'id de notification depuis un payload temps réel.
///
/// Pourquoi tolérant : FCM `data` et WS `notification_created` n'utilisent
/// pas toujours la même clé (`notification_id` vs `id`). Sans id, la
/// bannière masque simplement le bouton Supprimer (jamais de bouton mort).
int? parseInAppNotificationId(Map<String, dynamic> data) {
  for (final key in const ['notification_id', 'id', 'notificationId']) {
    final raw = data[key];
    if (raw == null) continue;
    if (raw is int && raw > 0) return raw;
    final parsed = int.tryParse(raw.toString());
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

/// Catégorie validée (repli `transactional`, jamais de valeur exotique).
String parseInAppCategory(Object? raw) {
  const allowed = {
    'security',
    'transactional',
    'social',
    'game',
    'marketing',
  };
  final value = raw?.toString().trim() ?? '';
  return allowed.contains(value) ? value : 'transactional';
}

/// Priorité validée (repli `normal`, jamais de valeur exotique).
String parseInAppPriority(Object? raw) {
  const allowed = {'urgent', 'high', 'normal', 'low'};
  final value = raw?.toString().trim().toLowerCase() ?? '';
  return allowed.contains(value) ? value : 'normal';
}

/// Suppression serveur depuis la bannière basse (optimiste + refresh).
///
/// Pourquoi via le notifier d'abord : suppression optimiste immédiate dans
/// la liste si elle est montée, sinon suppression directe au repository.
/// Dans les deux cas, le compteur non-lues est invalidé.
///
/// Pourquoi des callbacks plutôt qu'un `Ref` : les deux appelants n'ont pas
/// le même type (`Ref` côté provider FCM, `WidgetRef` côté shell). Les
/// callbacks gardent un seul cœur testable sans dépendance au type de ref.
Future<void> deleteInAppNotificationWith({
  required int? id,
  required Future<void> Function(int id) deleteOptimistic,
  required Future<void> Function(int id) deleteDirect,
  required void Function() invalidateUnread,
}) async {
  if (id == null) return;
  try {
    await deleteOptimistic(id);
  } catch (_) {
    // Inbox pas montée (autre onglet) ou échec optimiste : repli direct.
    await deleteDirect(id);
  }
  invalidateUnread();
}

/// Suppression serveur depuis la bannière basse (contexte provider FCM).
Future<void> deleteInAppNotification(
  Ref ref,
  Map<String, dynamic> data,
) async {
  final id = parseInAppNotificationId(data);
  await deleteInAppNotificationWith(
    id: id,
    deleteOptimistic: (target) =>
        ref.read(inboxProvider.notifier).deleteNotification(target),
    deleteDirect: (target) =>
        ref.read(notificationRepositoryProvider).deleteNotification(target),
    invalidateUnread: () =>
        ref.invalidate(unreadNotificationsCountProvider),
  );
}

/// Suppression serveur depuis la bannière basse (contexte widget / shell).
///
/// Pourquoi un doublon plutôt qu'un cast : `WidgetRef` n'est pas un `Ref`
/// (hiérarchies Riverpod distinctes). Le cœur reste partagé ci-dessus.
Future<void> deleteInAppNotificationFromWidget(
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final id = parseInAppNotificationId(data);
  await deleteInAppNotificationWith(
    id: id,
    deleteOptimistic: (target) =>
        ref.read(inboxProvider.notifier).deleteNotification(target),
    deleteDirect: (target) =>
        ref.read(notificationRepositoryProvider).deleteNotification(target),
    invalidateUnread: () =>
        ref.invalidate(unreadNotificationsCountProvider),
  );
}

/// État push de CET appareil (à distinguer des préférences serveur).
typedef PushDeviceStatus = ({
  bool available,
  AuthorizationStatus? permission,
  String? diagnostic,
});

/// État push courant de l'appareil (lecture seule, sans prompt).
final pushDeviceStatusProvider =
    FutureProvider.autoDispose<PushDeviceStatus>((ref) async {
  final service = ref.watch(pushNotificationServiceProvider);
  final permission = await service.permissionStatus();
  return (
    available: service.isAvailable,
    permission: permission,
    diagnostic: service.lastDiagnostic,
  );
});

/// Résultat lisible d'une tentative d'activation push (affichable en UI).
typedef PushSetupResult = ({bool ok, String message});

/// Active le push de bout en bout : permission OS (avec prompt sauf si
/// bloquée) → token FCM → enregistrement backend. Ne lève jamais :
/// le résultat dit quoi faire (ex. débloquer via le cadenas Chrome).
Future<PushSetupResult> ensurePushEnabled(WidgetRef ref) async {
  try {
    await ref.read(pushInitProvider.future);
    final service = ref.read(pushNotificationServiceProvider);
    if (!service.isAvailable) {
      return (
        ok: false,
        message: service.lastDiagnostic ??
            'Notifications indisponibles sur cet appareil.',
      );
    }
    // Bloqué côté OS/navigateur : prompter est inutile (silence garanti),
    // on guide vers le déblocage manuel.
    final status = await service.permissionStatus();
    if (status == AuthorizationStatus.denied) {
      const hint = kIsWeb
          ? 'Notifications bloquées par le navigateur. Cliquez le cadenas à gauche de la barre d\u2019adresse → Notifications → Autoriser, puis touchez Réessayer.'
          : 'Notifications bloquées. Autorisez WIWIGA dans les réglages de l\u2019appareil, puis touchez Réessayer.';
      return (ok: false, message: hint);
    }
    final granted = await service.requestPermission();
    if (!granted) {
      return (
        ok: false,
        message:
            service.lastDiagnostic ?? 'Permission de notification refusée.',
      );
    }
    // Timeout : sans lui, un réseau poussif suspend l'activation
    // indéfiniment (aucun feedback, aucun retry possible).
    final token = await service.getToken().timeout(
          const Duration(seconds: 25),
          onTimeout: () => throw TimeoutException('token FCM'),
        );
    if (token == null || token.isEmpty) {
      return (
        ok: false,
        message: service.lastDiagnostic ?? 'Token push indisponible.',
      );
    }
    await ref.read(notificationRepositoryProvider).registerDeviceToken(
          platform: service.platform,
          token: token,
        );
    return (ok: true, message: 'Notifications push activées sur cet appareil.');
  } on TimeoutException {
    return (
      ok: false,
      message: 'Délai dépassé pour le token push (réseau ?). Réessayez.',
    );
  } catch (_) {
    return (ok: false, message: 'Activation impossible (réseau ?). Réessayez.');
  }
}

/// Guidance de déblocage quand la permission est bloquée (aucun prompt
/// possible : ni l'opt-in ni "Réessayer" ne peuvent afficher le prompt OS).
String get pushBlockedHint => kIsWeb
    ? 'Les notifications sont bloquées pour ce site : aucun message ne peut s\u2019afficher.\n\n1. Cliquez le cadenas à gauche de la barre d\u2019adresse\n2. Notifications → Autoriser\n3. Touchez « J\u2019ai autorisé » ci-dessous.'
    : 'Les notifications sont bloquées pour WIWIGA.\n\nAutorisez-les dans les réglages de l\u2019appareil, puis touchez « J\u2019ai autorisé » ci-dessous.';

/// Supprime le token FCM (logout).
Future<void> unregisterPushToken(WidgetRef ref) async {
  try {
    final service = ref.read(pushNotificationServiceProvider);
    final token = await service.getToken();
    if (token != null && token.isNotEmpty) {
      await ref
          .read(notificationRepositoryProvider)
          .unregisterDeviceToken(token);
    }
    await service.deleteToken();
  } catch (_) {}
}

// ============================================================
// Fichier: presence_provider.dart
// Description: Provider temps réel pour le comptage des joueurs en ligne
//              Total + par type de jeu via Phoenix Presence
// Auteur: WIWIGA Team - 2026-09-03
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_websocket_service.dart';
import 'app_providers.dart';

/// État de présence en ligne
class PresenceState {
  final int totalOnline;
  final Map<String, int> perGameOnline;
  final bool isConnected;

  const PresenceState({
    this.totalOnline = 0,
    this.perGameOnline = const {},
    this.isConnected = false,
  });

  PresenceState copyWith({
    int? totalOnline,
    Map<String, int>? perGameOnline,
    bool? isConnected,
  }) {
    return PresenceState(
      totalOnline: totalOnline ?? this.totalOnline,
      perGameOnline: perGameOnline ?? this.perGameOnline,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  int forGame(String gameType) => perGameOnline[gameType] ?? 0;
}

/// Notifier qui gère la présence en temps réel via WebSocket
/// S'abonne à `online:lobby` (global) et `online:game:{type}` à la demande
class PresenceNotifier extends StateNotifier<PresenceState> {
  final GameWebSocketService _ws;
  final Ref _ref;
  Timer? _fallbackTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  final Set<String> _subscribedGames = {};

  PresenceNotifier(this._ws, this._ref) : super(const PresenceState()) {
    _init();
  }

  void _init() {
    _setupWsHandlers();
    // Écoute les changements de connexion WS
    _ws.addListener(_onWsChanged);
    // S'assurer que le WS est connecté pour le comptage (global)
    if (!_ws.isConnected && _ws.connectionStatus == GameConnectionStatus.disconnected) {
      // Ne pas attendre, laisser le WS se connecter en arrière-plan
      Future.microtask(() {
        if (!_disposed) _ws.connect();
      });
    }
    _onWsChanged();

    // Fallback polling léger si WS déconnecté (30s)
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_ws.isConnected) {
        _fetchViaRest();
      }
    });
  }

  void _onWsChanged() {
    final isConnected = _ws.isConnected;
    state = state.copyWith(isConnected: isConnected);
    if (isConnected) {
      _subscribeGlobal();
      // Re-souscrire aux jeux déjà demandés
      for (final gt in _subscribedGames) {
        _subscribeGame(gt);
      }
    } else if (_ws.connectionStatus == GameConnectionStatus.disconnected ||
        _ws.connectionStatus == GameConnectionStatus.fallbackRest) {
      // Tenter de reconnecter automatiquement pour le comptage en ligne.
      // Timer traqué + annulé au dispose (évite fuite + timer.pending en tests).
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (!_disposed && !_ws.isConnected) {
          _ws.connect();
        }
      });
    }
  }

  void _subscribeGlobal() {
    if (!_ws.isConnected) return;
    // Rejoindre le topic global pour recevoir presence_state/diff
    _ws.joinPresenceChannel('online:lobby');
  }

  void _subscribeGame(String gameType) {
    if (!_ws.isConnected) return;
    _ws.joinPresenceChannel('online:game:$gameType');
  }

  /// Appelé par l'UI quand elle affiche un jeu (catalogue ou détail)
  void ensureGameSubscribed(String gameType) {
    if (_subscribedGames.contains(gameType)) return;
    _subscribedGames.add(gameType);
    _subscribeGame(gameType);
  }

  void _setupWsHandlers() {
    _ws.onPresenceState = (payload) {
      // payload: {topic: "online:lobby", presences: {userId: {metas: [...]}}}
      // ou {topic: "online:game:dice", presences: {...}}
      final topic = payload['topic'] as String? ?? '';
      final presences = payload['presences'] as Map<String, dynamic>? ?? {};
      // Le serveur envoie déjà le comptage via presence_state, mais on peut aussi compter localement
      final count = presences.length;
      if (topic == 'online:lobby' || topic == 'online:lobby:presence_state') {
        state = state.copyWith(totalOnline: count);
      } else if (topic.startsWith('online:game:')) {
        final gameType = topic.split(':').last;
        final newMap = Map<String, int>.from(state.perGameOnline);
        newMap[gameType] = count;
        state = state.copyWith(perGameOnline: newMap);
      }
    };

    _ws.onPresenceDiff = (payload) {
      // payload: {topic: "...", joins: {...}, leaves: {...}}
      final topic = payload['topic'] as String? ?? '';
      final joins = payload['joins'] as Map<String, dynamic>? ?? {};
      final leaves = payload['leaves'] as Map<String, dynamic>? ?? {};
      if (topic == 'online:lobby') {
        final newTotal = (state.totalOnline + joins.length - leaves.length).clamp(0, 999999);
        state = state.copyWith(totalOnline: newTotal);
      } else if (topic.startsWith('online:game:')) {
        final gameType = topic.split(':').last;
        final current = state.perGameOnline[gameType] ?? 0;
        final newCount = (current + joins.length - leaves.length).clamp(0, 999999);
        final newMap = Map<String, int>.from(state.perGameOnline);
        newMap[gameType] = newCount;
        state = state.copyWith(perGameOnline: newMap);
      }
    };
  }

  Future<void> _fetchViaRest() async {
    // Fallback REST si WS non connecté: utilise l'endpoint actif qui contient total_online dans meta
    try {
      final repo = _ref.read(gameRepositoryProvider);
      final games = await repo.getGames();
      // On peut estimer le total comme somme des per-game, mais le backend fournit déjà total_online dans meta
      // Pour l'instant, on ne fait rien, on laisse le polling des providers s'en charger
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _fallbackTimer?.cancel();
    _ws.removeListener(_onWsChanged);
    super.dispose();
  }
}

final presenceProvider = StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  final ws = ref.watch(gameWebSocketServiceProvider);
  return PresenceNotifier(ws, ref);
});

/// Provider dédié pour le total en ligne (pour la page Jeux)
final totalOnlineProvider = Provider<int>((ref) {
  final presence = ref.watch(presenceProvider);
  // Si WS connecté, utilise le temps réel, sinon fallback sur le provider REST qui poll toutes les 60s
  if (presence.isConnected) {
    return presence.totalOnline;
  }
  // Fallback: la valeur du catalogue (sera mise à jour via le polling 60s)
  return presence.totalOnline;
});

/// Provider pour le per-game (ex: dice)
final perGameOnlineProvider = Provider.family<int, String>((ref, gameType) {
  final presence = ref.watch(presenceProvider);
  // S'assure que le jeu est souscrit
  ref.read(presenceProvider.notifier).ensureGameSubscribed(gameType);
  if (presence.isConnected) {
    return presence.forGame(gameType);
  }
  return presence.forGame(gameType);
});

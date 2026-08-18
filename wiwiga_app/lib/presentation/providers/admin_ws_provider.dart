// ============================================================
// Fichier: admin_ws_provider.dart
// Description: Provider WebSocket pour mises à jour temps réel admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État de la connexion WebSocket admin
enum AdminWsStatus { disconnected, connecting, connected, reconnecting }

/// État du provider WebSocket admin
class AdminWsState {
  final AdminWsStatus status;
  final Map<String, dynamic>? latestDashboard;
  final List<dynamic> latestAlerts;
  final int reconnectAttempts;
  final DateTime? lastUpdate;

  const AdminWsState({
    this.status = AdminWsStatus.disconnected,
    this.latestDashboard,
    this.latestAlerts = const [],
    this.reconnectAttempts = 0,
    this.lastUpdate,
  });

  AdminWsState copyWith({
    AdminWsStatus? status,
    Map<String, dynamic>? latestDashboard,
    List<dynamic>? latestAlerts,
    int? reconnectAttempts,
    DateTime? lastUpdate,
  }) {
    return AdminWsState(
      status: status ?? this.status,
      latestDashboard: latestDashboard ?? this.latestDashboard,
      latestAlerts: latestAlerts ?? this.latestAlerts,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Provider WebSocket admin avec reconnexion automatique
class AdminWsNotifier extends StateNotifier<AdminWsState> {
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30; // secondes

  AdminWsNotifier() : super(const AdminWsState());

  /// Connecte au canal WebSocket admin
  Future<void> connect() async {
    if (state.status == AdminWsStatus.connected || state.status == AdminWsStatus.connecting) return;

    state = state.copyWith(status: AdminWsStatus.connecting);

    try {
      // Simulation de connexion WebSocket
      // En production, utiliser le Phoenix WebSocket existant
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
        status: AdminWsStatus.connected,
        reconnectAttempts: 0,
        lastUpdate: DateTime.now(),
      );

      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  /// Déconnecte du WebSocket
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    state = state.copyWith(status: AdminWsStatus.disconnected);
  }

  /// Reçoit une mise à jour dashboard
  void onDashboardUpdate(Map<String, dynamic> data) {
    state = state.copyWith(
      latestDashboard: data,
      lastUpdate: DateTime.now(),
    );
  }

  /// Reçoit une nouvelle alerte
  void onNewAlert(dynamic alert) {
    state = state.copyWith(
      latestAlerts: [alert, ...state.latestAlerts].take(50).toList(),
      lastUpdate: DateTime.now(),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Vérifier que la connexion est toujours active
      if (state.status != AdminWsStatus.connected) {
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delay = (_reconnectAttempts * 2).clamp(1, _maxReconnectDelay);

    state = state.copyWith(
      status: AdminWsStatus.reconnecting,
      reconnectAttempts: _reconnectAttempts,
    );

    Timer(Duration(seconds: delay), () {
      connect();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

/// Provider WebSocket admin
final adminWsProvider = StateNotifierProvider<AdminWsNotifier, AdminWsState>((ref) {
  return AdminWsNotifier();
});

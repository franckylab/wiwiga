// ============================================================
// Fichier: notification_repository.dart
// Description: Repository inbox notifications joueur
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'dart:convert';
import '../services/api_service.dart';
import '../models/notification_model.dart';
import '../../core/constants/api_constants.dart';

/// Repository pour l'inbox notifications du joueur
class NotificationRepository {
  final ApiService _apiService;

  NotificationRepository(this._apiService);

  /// Liste l'inbox paginée — tolérant si data null
  Future<({List<NotificationModel> items, int total})> listNotifications({
    int page = 1,
    int limit = 20,
    String? isRead,
    String? category,
    String? query,
  }) async {
    final queryParams = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (isRead != null) 'is_read': isRead,
      if (category != null) 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final response = await _apiService.get(ApiEndpoints.notifications, queryParams: queryParams);
    final raw = response['data'];
    if (raw == null) return (items: <NotificationModel>[], total: 0);
    final data = raw as Map<String, dynamic>;
    final list = (data['notifications'] as List<dynamic>?)
            ?.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final total = (data['total'] as num?)?.toInt() ?? list.length;
    return (items: list, total: total);
  }

  /// Compteur de non-lues (badge cloche)
  Future<int> getUnreadCount() async {
    final response = await _apiService.get(ApiEndpoints.notificationsUnreadCount);
    final raw = response['data'];
    if (raw == null) return 0;
    return (raw['unread_count'] as num?)?.toInt() ?? 0;
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(int id) async {
    await _apiService.put('${ApiEndpoints.notifications}/$id/read');
  }

  /// Marque toute l'inbox comme lue
  Future<void> markAllAsRead() async {
    await _apiService.put('${ApiEndpoints.notifications}/read-all');
  }

  /// Supprime une notification de l'inbox
  Future<void> deleteNotification(int id) async {
    await _apiService.delete('${ApiEndpoints.notifications}/$id');
  }

  /// Liste les préférences de l'utilisateur
  Future<List<NotificationPreferenceModel>> listPreferences() async {
    final response = await _apiService.get(ApiEndpoints.notificationsPreferences);
    final raw = response['data'];
    if (raw == null) return [];
    final data = raw as List<dynamic>;
    return data.map((e) => NotificationPreferenceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Active/désactive un canal pour une catégorie
  Future<void> updatePreference({
    required String category,
    required String channel,
    required bool enabled,
  }) async {
    await _apiService.put(
      ApiEndpoints.notificationsPreferences,
      body: {'category': category, 'channel': channel, 'enabled': enabled},
    );
  }

  /// Enregistre le token push (Phase push — FCM)
  Future<void> registerDeviceToken({
    required String platform,
    required String token,
    String? appVersion,
  }) async {
    await _apiService.post(
      ApiEndpoints.notificationsDeviceToken,
      body: jsonEncode({'platform': platform, 'token': token, 'app_version': appVersion}),
    );
  }

  /// Supprime le token push (logout)
  Future<void> unregisterDeviceToken(String token) async {
    await _apiService.delete(
      ApiEndpoints.notificationsDeviceToken,
      queryParams: {'token': token},
    );
  }
}

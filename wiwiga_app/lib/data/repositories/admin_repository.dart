// ============================================================
// Fichier: admin_repository.dart
// Description: Repository pour les opérations admin (CRUD users, rôles, stats)
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository pour les opérations d'administration
class AdminRepository {
  final ApiService _apiService;

  AdminRepository({required ApiService apiService}) : _apiService = apiService;

  /// Liste des utilisateurs avec filtres et pagination
  Future<Map<String, dynamic>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? role,
    String? status,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _apiService.get(
      '${ApiEndpoints.adminUsers}?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}',
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    final users = (data['users'] as List)
        .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
        .toList();

    return {
      'users': users,
      'total': data['total'] ?? users.length,
      'page': data['page'] ?? page,
      'page_size': data['page_size'] ?? pageSize,
    };
  }

  /// Détail d'un utilisateur
  Future<UserModel> getUser(String userId) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminUsers}/$userId',
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Créer un utilisateur (super_admin)
  Future<UserModel> createUser({
    String? phone,
    String? email,
    required String username,
    String? role,
    String? avatarType,
  }) async {
    final body = <String, dynamic>{
      'username': username,
    };
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (role != null) body['role'] = role;
    if (avatarType != null) body['avatar_type'] = avatarType;

    final response = await _apiService.post(
      ApiEndpoints.adminUsers,
      body: body,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Changer le rôle d'un utilisateur
  Future<UserModel> updateUserRole(String userId, String newRole) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminUsers}/$userId/role',
      body: {'role': newRole},
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Activer/désactiver un utilisateur
  Future<UserModel> toggleUserActive(String userId, bool activate) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminUsers}/$userId/activate',
      body: {'is_active': activate},
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Statistiques admin
  Future<Map<String, dynamic>> getStats() async {
    final response = await _apiService.get(
      ApiEndpoints.adminStats,
      requiresAuth: true,
    );

    return response['data'] as Map<String, dynamic>;
  }

  /// Liste des logs d'audit
  Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? entityType,
    String? userId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (action != null && action.isNotEmpty) queryParams['action'] = action;
    if (entityType != null && entityType.isNotEmpty) queryParams['entity_type'] = entityType;
    if (userId != null && userId.isNotEmpty) queryParams['user_id'] = userId;
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

    final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminAuditLogs}?$queryString',
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return {
      'logs': data['logs'] as List? ?? [],
      'total': data['total'] ?? 0,
      'page': page,
      'limit': limit,
    };
  }

  /// Santé du système (supervision)
  Future<Map<String, dynamic>> getSystemHealth() async {
    final response = await _apiService.get(
      ApiEndpoints.adminSystemHealth,
      requiresAuth: true,
    );

    return response['data'] as Map<String, dynamic>;
  }

  /// Résoudre une alerte
  Future<Map<String, dynamic>> resolveAlert(String alertId) async {
    final response = await _apiService.post(
      ApiEndpoints.adminAlertResolve(alertId),
      body: {},
      requiresAuth: true,
    );

    return response['data'] as Map<String, dynamic>? ?? response;
  }

  /// Liste des rôles avec permissions
  Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await _apiService.get(
      ApiEndpoints.adminRoles,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return (data['roles'] as List).cast<Map<String, dynamic>>();
  }

  // ========================================
  // MÉTRIQUES
  // ========================================

  /// Résumé du dashboard (toutes métriques)
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final response = await _apiService.get(
      ApiEndpoints.adminMetricsDashboard,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Métriques financières
  Future<Map<String, dynamic>> getFinancialMetrics({
    String period = '24h',
    String? from,
    String? to,
  }) async {
    final params = 'period=$period${from != null ? '&from=$from' : ''}${to != null ? '&to=$to' : ''}';
    final response = await _apiService.get(
      '${ApiEndpoints.adminMetricsFinancial}?$params',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Métriques jeux
  Future<Map<String, dynamic>> getGameMetrics({String period = '24h'}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminMetricsGames}?period=$period',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Métriques utilisateurs
  Future<Map<String, dynamic>> getUserMetrics({String period = '24h'}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminMetricsUsers}?period=$period',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Métriques paiements
  Future<Map<String, dynamic>> getPaymentMetrics({String period = '24h'}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminMetricsPayments}?period=$period',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Métriques sécurité
  Future<Map<String, dynamic>> getSecurityMetrics({String period = '24h'}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminMetricsSecurity}?period=$period',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Données timeseries pour graphiques
  Future<List<dynamic>> getTimeseries({
    required String metric,
    String period = '7d',
  }) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminMetricsTimeseries}?metric=$metric&period=$period',
      requiresAuth: true,
    );
    return response['data']?['timeseries'] as List<dynamic>? ?? [];
  }

  // ========================================
  // GESTION DES PARTIES
  // ========================================

  /// Parties actives
  Future<Map<String, dynamic>> getActiveGames() async {
    final response = await _apiService.get(
      ApiEndpoints.adminGamesActive,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Résumé stats jeux
  Future<Map<String, dynamic>> getGamesStatsSummary() async {
    final response = await _apiService.get(
      ApiEndpoints.adminGamesStatsSummary,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Forcer la clôture d'une partie
  Future<Map<String, dynamic>> forceCloseGame(String gameId, {String? reason}) async {
    final response = await _apiService.post(
      '/api/admin/games/$gameId/force-close',
      body: {'reason': reason ?? 'Admin forced closure'},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // SÉCURITÉ
  // ========================================

  /// Vue d'ensemble sécurité
  Future<Map<String, dynamic>> getSecurityOverview() async {
    final response = await _apiService.get(
      ApiEndpoints.adminSecurityOverview,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Logs d'auth échouées
  Future<Map<String, dynamic>> getFailedAuths({int page = 1, int limit = 20}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminSecurityFailedAuths}?page=$page&limit=$limit',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Statistiques rate limiting
  Future<Map<String, dynamic>> getRateLimits() async {
    final response = await _apiService.get(
      ApiEndpoints.adminSecurityRateLimits,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Liste IP whitelist
  Future<List<dynamic>> getIpWhitelist() async {
    final response = await _apiService.get(
      ApiEndpoints.adminSecurityIpWhitelist,
      requiresAuth: true,
    );
    return response['data']?['whitelist'] as List<dynamic>? ?? [];
  }

  /// Ajouter IP à la whitelist
  Future<Map<String, dynamic>> addIpToWhitelist(String ip, {String? description}) async {
    final response = await _apiService.post(
      ApiEndpoints.adminSecurityIpWhitelist,
      body: {'ip_address': ip, 'description': description ?? ''},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Retirer IP de la whitelist
  Future<void> removeIpFromWhitelist(String ip) async {
    await _apiService.delete(
      '${ApiEndpoints.adminSecurityIpWhitelist}/$ip',
      requiresAuth: true,
    );
  }

  /// Bannir un utilisateur
  Future<Map<String, dynamic>> banUser(String userId, {required String reason, bool isPermanent = true}) async {
    final response = await _apiService.post(
      '/api/admin/security/ban-user/$userId',
      body: {'reason': reason, 'is_permanent': isPermanent},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Débannir un utilisateur
  Future<void> unbanUser(String userId) async {
    await _apiService.delete(
      '/api/admin/security/ban-user/$userId',
      requiresAuth: true,
    );
  }

  // ========================================
  // JEU RESPONSABLE
  // ========================================

  /// Vue d'ensemble jeu responsable
  Future<Map<String, dynamic>> getResponsibleGamingOverview() async {
    final response = await _apiService.get(
      ApiEndpoints.adminResponsibleGamingOverview,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Fixer limites personnalisées pour un utilisateur
  Future<Map<String, dynamic>> setUserLimits(String userId, Map<String, dynamic> limits) async {
    final response = await _apiService.put(
      '/api/admin/responsible-gaming/users/$userId/limits',
      body: limits,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Liste des auto-exclusions
  Future<Map<String, dynamic>> getSelfExclusions({int page = 1, int limit = 20}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminResponsibleGamingSelfExclusions}?page=$page&limit=$limit',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Indicateurs de risque
  Future<Map<String, dynamic>> getRiskIndicators() async {
    final response = await _apiService.get(
      ApiEndpoints.adminResponsibleGamingRiskIndicators,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // NOTIFICATIONS
  // ========================================

  /// Liste des notifications
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (type != null) params['type'] = type;
    if (isRead != null) params['is_read'] = isRead.toString();

    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminNotifications}?$queryString',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Marquer une notification comme lue
  Future<void> markNotificationRead(String notificationId) async {
    await _apiService.put(
      '${ApiEndpoints.adminNotifications}/$notificationId/read',
      requiresAuth: true,
    );
  }

  /// Diffuser un message à tous les utilisateurs
  Future<Map<String, dynamic>> broadcastNotification(String title, String message) async {
    final response = await _apiService.post(
      ApiEndpoints.adminNotificationsBroadcast,
      body: {'title': title, 'message': message},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Compteur notifications non lues
  Future<int> getUnreadNotificationCount() async {
    final response = await _apiService.get(
      ApiEndpoints.adminNotificationsUnreadCount,
      requiresAuth: true,
    );
    return response['data']?['unread_count'] as int? ?? 0;
  }

  // ========================================
  // CONFIG HISTORIQUE & ROLLBACK
  // ========================================

  /// Historique des changements de configuration
  Future<Map<String, dynamic>> getConfigHistory({String? type, int limit = 50}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (type != null) params['type'] = type;

    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminConfigHistory}?$queryString',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Restaurer une configuration précédente
  Future<Map<String, dynamic>> rollbackConfig(String logId) async {
    final response = await _apiService.post(
      '${ApiEndpoints.adminConfigHistory}/$logId/rollback',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // EXPORT
  // ========================================

  /// URL d'export utilisateurs (pour téléchargement direct)
  String getExportUsersUrl() => ApiEndpoints.adminExportUsers;

  /// URL d'export transactions
  String getExportTransactionsUrl({String? from, String? to}) {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${ApiEndpoints.adminExportTransactions}${qs.isNotEmpty ? '?$qs' : ''}';
  }

  /// URL d'export jeux
  String getExportGamesUrl({String? from, String? to}) {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${ApiEndpoints.adminExportGames}${qs.isNotEmpty ? '?$qs' : ''}';
  }

  // ========================================
  // CRM JOUEURS
  // ========================================

  /// Segments de joueurs
  Future<List<dynamic>> getCrmSegments() async {
    final response = await _apiService.get(
      ApiEndpoints.adminCrmSegments,
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>? ?? [];
  }

  /// Résumé d'un joueur
  Future<Map<String, dynamic>> getPlayerSummary(String userId) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminCrmPlayerSummary}/$userId/summary',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Notes d'un joueur
  Future<List<dynamic>> getPlayerNotes(String userId, {int page = 1, int limit = 20}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminCrmPlayerNotes}/$userId/notes?page=$page&limit=$limit',
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>? ?? [];
  }

  /// Ajouter une note
  Future<Map<String, dynamic>> addPlayerNote(String userId, String note, {String category = 'general'}) async {
    final response = await _apiService.post(
      '${ApiEndpoints.adminCrmPlayerNotes}/$userId/notes',
      body: {'note': note, 'category': category},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Joueurs VIP
  Future<List<dynamic>> getVipPlayers({int limit = 50}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminCrmVip}?limit=$limit',
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>? ?? [];
  }

  /// Définir le tier VIP
  Future<Map<String, dynamic>> setVipTier(String userId, String tier) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminCrmVipTier}/$userId/vip-tier',
      body: {'tier': tier},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Joueurs à risque
  Future<List<dynamic>> getAtRiskPlayers() async {
    final response = await _apiService.get(
      ApiEndpoints.adminCrmAtRisk,
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>? ?? [];
  }

  // ========================================
  // RÉCONCILIATION FINANCIÈRE
  // ========================================

  /// Résumé journalier
  Future<Map<String, dynamic>> getDailyReconciliation({String? date}) async {
    final url = date != null
        ? '${ApiEndpoints.adminReconciliationDaily}?date=$date'
        : ApiEndpoints.adminReconciliationDaily;
    final response = await _apiService.get(url, requiresAuth: true);
    return response['data'] as Map<String, dynamic>;
  }

  /// Écarts détectés
  Future<Map<String, dynamic>> getDiscrepancies({String period = '24h'}) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminReconciliationDiscrepancies}?period=$period',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Rapport commissions
  Future<Map<String, dynamic>> getCommissionReport({String period = '30d', String? gameType}) async {
    final params = 'period=$period${gameType != null ? '&game_type=$gameType' : ''}';
    final response = await _apiService.get(
      '${ApiEndpoints.adminReconciliationCommissions}?$params',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Solde plateforme
  Future<Map<String, dynamic>> getPlatformBalance() async {
    final response = await _apiService.get(
      ApiEndpoints.adminReconciliationBalance,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // SETTINGS SYSTÈME
  // ========================================

  /// Tous les settings groupés par catégorie
  Future<Map<String, dynamic>> getAllSettings() async {
    final response = await _apiService.get(
      ApiEndpoints.adminSettings,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Settings par catégorie
  Future<List<dynamic>> getSettingsByCategory(String category) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminSettingsCategory}/$category',
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>? ?? [];
  }

  /// Mettre à jour un setting
  Future<Map<String, dynamic>> updateSetting(String key, String value) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminSettings}/$key',
      body: {'value': value},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // IMPERSONATION
  // ========================================

  /// Démarrer l'impersonation
  Future<Map<String, dynamic>> startImpersonation(String userId) async {
    final response = await _apiService.post(
      '${ApiEndpoints.adminImpersonateStart}/$userId/start',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Arrêter l'impersonation
  Future<void> stopImpersonation() async {
    await _apiService.post(
      ApiEndpoints.adminImpersonateStop,
      requiresAuth: true,
    );
  }

  /// Statut impersonation
  Future<Map<String, dynamic>> getImpersonationStatus() async {
    final response = await _apiService.get(
      ApiEndpoints.adminImpersonateStatus,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // ANALYTICS KPI GAMING (V3)
  // ========================================

  /// Analytics revenue (GGR, NGR, ARPU, ARPPU, commissions)
  Future<Map<String, dynamic>> getRevenueAnalytics({String period = '30d', String? from, String? to}) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminAnalyticsRevenue}?$qs',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Analytics joueurs (DAU, WAU, MAU, stickiness, Reg2Dep)
  Future<Map<String, dynamic>> getPlayerAnalytics({String period = '30d', String? from, String? to}) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminAnalyticsPlayers}?$qs',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Cohortes de retention
  Future<Map<String, dynamic>> getRetentionCohorts() async {
    final response = await _apiService.get(
      ApiEndpoints.adminAnalyticsCohorts,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Estimation LTV
  Future<Map<String, dynamic>> getLtvEstimate() async {
    final response = await _apiService.get(
      ApiEndpoints.adminAnalyticsLtv,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Performance par jeu
  Future<Map<String, dynamic>> getGameAnalytics({String period = '30d', String? from, String? to}) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminAnalyticsGames}?$qs',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Flux monétaire
  Future<Map<String, dynamic>> getMonetaryFlow({String period = '30d', String? from, String? to}) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _apiService.get(
      '${ApiEndpoints.adminAnalyticsMonetaryFlow}?$qs',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Distribution richesse joueurs
  Future<Map<String, dynamic>> getWealthDistribution() async {
    final response = await _apiService.get(
      ApiEndpoints.adminAnalyticsWealthDistribution,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Entonnoir de conversion
  Future<Map<String, dynamic>> getConversionFunnel() async {
    final response = await _apiService.get(
      ApiEndpoints.adminAnalyticsConversionFunnel,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // GAME CONFIG (V3)
  // ========================================

  /// Liste des configurations de jeux
  Future<List<dynamic>> getGameConfigs() async {
    final response = await _apiService.get(
      ApiEndpoints.adminGameConfigs,
      requiresAuth: true,
    );
    return response['configs'] as List<dynamic>? ?? response['data'] as List<dynamic>? ?? [];
  }

  /// Mettre à jour la config d'un jeu
  Future<Map<String, dynamic>> updateGameConfig(String gameType, Map<String, dynamic> config) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminGameConfigs}/$gameType',
      body: config,
      requiresAuth: true,
    );
    return response['config'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? response;
  }

  /// Créer une config de jeu
  Future<Map<String, dynamic>> createGameConfig(Map<String, dynamic> config) async {
    final response = await _apiService.post(
      ApiEndpoints.adminGameConfigs,
      body: config,
      requiresAuth: true,
    );
    return response['config'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? response;
  }

  // ========================================
  // BONUSES & PROMOTIONS (V3)
  // ========================================

  /// Liste des bonus
  Future<List<dynamic>> getBonuses({String? type, bool? isActive}) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (isActive != null) params['is_active'] = isActive.toString();
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final url = '${ApiEndpoints.adminBonuses}${qs.isNotEmpty ? '?$qs' : ''}';
    final response = await _apiService.get(url, requiresAuth: true);
    return response['bonuses'] as List<dynamic>? ?? response['data'] as List<dynamic>? ?? [];
  }

  /// Créer un bonus
  Future<Map<String, dynamic>> createBonus(Map<String, dynamic> bonus) async {
    final response = await _apiService.post(
      ApiEndpoints.adminBonuses,
      body: bonus,
      requiresAuth: true,
    );
    return response['bonus'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? response;
  }

  /// Mettre à jour un bonus
  Future<Map<String, dynamic>> updateBonus(String bonusId, Map<String, dynamic> bonus) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminBonuses}/$bonusId',
      body: bonus,
      requiresAuth: true,
    );
    return response['bonus'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? response;
  }

  /// Activer/désactiver un bonus
  Future<Map<String, dynamic>> toggleBonus(String bonusId, bool isActive) async {
    final response = await _apiService.post(
      '${ApiEndpoints.adminBonuses}/$bonusId/toggle',
      body: {'is_active': isActive},
      requiresAuth: true,
    );
    return response['bonus'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? response;
  }

  /// Stats d'un bonus
  Future<Map<String, dynamic>> getBonusStats(String bonusId) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminBonuses}/$bonusId/stats',
      requiresAuth: true,
    );
    return response;
  }

  // ========================================
  // REPORTS (V3)
  // ========================================

  /// Liste des rapports
  Future<List<dynamic>> getReports() async {
    final response = await _apiService.get(
      ApiEndpoints.adminReports,
      requiresAuth: true,
    );
    return response['reports'] as List<dynamic>? ?? response['data'] as List<dynamic>? ?? [];
  }

  /// Générer un rapport
  Future<Map<String, dynamic>> generateReport({required String type, String? name, Map<String, dynamic>? parameters}) async {
    final body = <String, dynamic>{'type': type};
    if (name != null) body['name'] = name;
    if (parameters != null) body['parameters'] = parameters;
    final response = await _apiService.post(
      ApiEndpoints.adminReportsGenerate,
      body: body,
      requiresAuth: true,
    );
    return response['report'] as Map<String, dynamic>? ?? response['data'] as Map<String, dynamic>? ?? response;
  }

  /// Télécharger un rapport (URL)
  String getReportDownloadUrl(String reportId) => '${ApiEndpoints.adminReports}/$reportId/download';

  // ========================================
  // Player Progression
  // ========================================

  /// Liste des configurations de niveaux joueur
  Future<List<dynamic>> getPlayerProgressionLevels() async {
    final response = await _apiService.get(
      ApiEndpoints.adminPlayerProgressionLevels,
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>;
  }

  /// Met à jour la configuration d'un niveau
  Future<Map<String, dynamic>> updatePlayerLevel(String tier, Map<String, dynamic> config) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminPlayerProgressionLevels}/$tier',
      body: config,
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Calcule le tier pour un XP donné
  Future<Map<String, dynamic>> calculateTier(int xp) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminPlayerProgressionCalculate}/$xp',
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  // ========================================
  // Platform Config
  // ========================================

  /// Récupère toutes les configurations plateforme groupées par catégorie
  Future<Map<String, dynamic>> getPlatformConfig() async {
    final response = await _apiService.get(
      ApiEndpoints.adminPlatformConfig,
      requiresAuth: true,
    );
    return response;
  }

  /// Récupère les configurations d'une catégorie
  Future<List<dynamic>> getPlatformConfigByCategory(String category) async {
    final response = await _apiService.get(
      '${ApiEndpoints.adminPlatformConfig}/$category',
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>;
  }

  /// Met à jour une valeur de configuration
  Future<Map<String, dynamic>> updatePlatformConfig(String category, String key, String value) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminPlatformConfig}/$category/$key',
      body: {'value': value},
      requiresAuth: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Met à jour plusieurs configurations d'une catégorie
  Future<Map<String, dynamic>> batchUpdatePlatformConfig(String category, List<Map<String, String>> updates) async {
    final response = await _apiService.put(
      '${ApiEndpoints.adminPlatformConfig}/$category/batch',
      body: {'updates': updates},
      requiresAuth: true,
    );
    return response;
  }

  /// Santé de la configuration
  Future<List<dynamic>> getPlatformConfigHealth() async {
    final response = await _apiService.get(
      ApiEndpoints.adminPlatformConfigHealth,
      requiresAuth: true,
    );
    return response['data'] as List<dynamic>;
  }
}

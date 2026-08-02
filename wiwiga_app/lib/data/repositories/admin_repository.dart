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

  /// Liste des rôles avec permissions
  Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await _apiService.get(
      ApiEndpoints.adminRoles,
      requiresAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return (data['roles'] as List).cast<Map<String, dynamic>>();
  }
}

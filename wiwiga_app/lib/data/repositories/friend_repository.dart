// ============================================================
// Fichier: friend_repository.dart
// Description: Repository pour le système d'amis
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:convert';
import '../services/api_service.dart';
import '../models/friend_model.dart';
import '../../core/constants/api_constants.dart';

/// Repository pour la gestion des amis
class FriendRepository {
  final ApiService _apiService;

  FriendRepository(this._apiService);

  /// Liste les amis
  Future<List<FriendModel>> listFriends() async {
    final response = await _apiService.get(ApiEndpoints.friendsList);
    final data = response['data'] as List<dynamic>;
    return data.map((f) => FriendModel.fromJson(f as Map<String, dynamic>)).toList();
  }

  /// Liste les demandes en attente
  Future<List<FriendRequestModel>> listPendingRequests() async {
    final response = await _apiService.get(ApiEndpoints.friendsRequests);
    final data = response['data'] as List<dynamic>;
    return data.map((r) => FriendRequestModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Envoie une demande d'ami
  Future<void> sendRequest({String? phone, String? username, int? userId}) async {
    final body = <String, dynamic>{};
    if (phone != null) body['phone'] = phone;
    if (username != null) body['username'] = username;
    if (userId != null) body['user_id'] = userId;

    await _apiService.post(ApiEndpoints.friendsSendRequest, body: jsonEncode(body));
  }

  /// Accepte une demande d'ami
  Future<void> acceptRequest(int requestId) async {
    await _apiService.post('${ApiEndpoints.friendsSendRequest}/$requestId/accept');
  }

  /// Rejette une demande d'ami
  Future<void> rejectRequest(int requestId) async {
    await _apiService.post('${ApiEndpoints.friendsSendRequest}/$requestId/reject');
  }

  /// Supprime un ami
  Future<void> removeFriend(int friendId) async {
    await _apiService.delete('${ApiEndpoints.friendsList}/$friendId');
  }

  /// Bloque un utilisateur
  Future<void> blockUser(int userId) async {
    await _apiService.post('${ApiEndpoints.friendsList}/$userId/block');
  }

  /// Recherche un joueur
  Future<List<PlayerSearchResult>> searchPlayer(String query) async {
    final response = await _apiService.get(ApiEndpoints.friendsSearch, queryParams: {'q': query});
    final data = response['data'] as List<dynamic>;
    return data.map((r) => PlayerSearchResult.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Leaderboard entre amis
  Future<List<FriendLeaderboardEntry>> getLeaderboard() async {
    final response = await _apiService.get(ApiEndpoints.friendsLeaderboard);
    final data = response['data'] as List<dynamic>;
    return data.map((e) => FriendLeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Feed d'activité
  Future<List<FriendActivityModel>> getActivity() async {
    final response = await _apiService.get(ApiEndpoints.friendsActivity);
    final data = response['data'] as List<dynamic>;
    return data.map((a) => FriendActivityModel.fromJson(a as Map<String, dynamic>)).toList();
  }

  /// Ajoute un ami depuis une partie
  Future<void> addFromGame(int opponentId) async {
    await _apiService.post('${ApiEndpoints.friendsList}/$opponentId/add-from-game');
  }
}

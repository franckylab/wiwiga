// ============================================================
// Fichier: room_repository.dart
// Description: Repository pour les salles de jeu
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-07-29
// ============================================================

import 'dart:convert';
import '../services/api_service.dart';
import '../models/game_room_model.dart';
import '../../core/constants/api_constants.dart';

/// Repository pour la gestion des salles de jeu
class RoomRepository {
  final ApiService _apiService;

  RoomRepository(this._apiService);

  /// Crée une nouvelle salle
  Future<GameRoomModel> createRoom(CreateGameConfig config, {String? creatorName}) async {
    final body = config.toJson();
    if (creatorName != null) body['creator_name'] = creatorName;

    final response = await _apiService.post(ApiEndpoints.roomsCreate, body: jsonEncode(body));
    final data = response['data'] as Map<String, dynamic>;
    return GameRoomModel.fromJson(data);
  }

  /// Rejoint une salle par ID
  Future<GameRoomModel> joinRoom(String roomId, {String? playerName}) async {
    final body = <String, dynamic>{};
    if (playerName != null) body['player_name'] = playerName;

    final response = await _apiService.post('${ApiEndpoints.roomsShow}/$roomId/join', body: jsonEncode(body));
    final data = response['data'] as Map<String, dynamic>;
    return GameRoomModel.fromJson(data);
  }

  /// Rejoint une salle par code
  Future<GameRoomModel> joinByCode(String code, {String? playerName}) async {
    final body = <String, dynamic>{'code': code};
    if (playerName != null) body['player_name'] = playerName;

    final response = await _apiService.post(ApiEndpoints.roomsJoinByCode, body: jsonEncode(body));
    final data = response['data'] as Map<String, dynamic>;
    return GameRoomModel.fromJson(data);
  }

  /// Quitte une salle
  Future<void> leaveRoom(String roomId) async {
    await _apiService.post('${ApiEndpoints.roomsShow}/$roomId/leave');
  }

  /// Démarre le match (créateur uniquement)
  Future<Map<String, dynamic>> startMatch(String roomId) async {
    final response = await _apiService.post('${ApiEndpoints.roomsShow}/$roomId/start');
    return response['data'] as Map<String, dynamic>;
  }

  /// Annule une salle
  Future<void> cancelRoom(String roomId) async {
    await _apiService.post('${ApiEndpoints.roomsShow}/$roomId/cancel');
  }

  /// Récupère les détails d'une salle
  Future<GameRoomModel> getRoom(String roomId) async {
    final response = await _apiService.get('${ApiEndpoints.roomsShow}/$roomId');
    final data = response['data'] as Map<String, dynamic>;
    return GameRoomModel.fromJson(data);
  }

  /// Liste les salles en attente
  Future<List<GameRoomModel>> listWaitingRooms({String? gameType, String? mode}) async {
    final queryParams = <String, String>{};
    if (gameType != null) queryParams['game_type'] = gameType;
    if (mode != null) queryParams['mode'] = mode;

    final response = await _apiService.get(ApiEndpoints.roomsList, queryParams: queryParams);
    final data = response['data'] as List<dynamic>;
    return data.map((r) => GameRoomModel.fromJson(r as Map<String, dynamic>)).toList();
  }
}

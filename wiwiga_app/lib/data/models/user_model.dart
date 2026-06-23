// ============================================================
// Fichier: user_model.dart
// Description: Modèle utilisateur WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

/// Modèle représentant un utilisateur
class UserModel {
  final String id;
  final String phone;
  final String? email;
  final String? username;
  final double balance;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const UserModel({
    required this.id,
    required this.phone,
    this.email,
    this.username,
    required this.balance,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Crée un UserModel depuis une réponse JSON API
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      username: json['username'],
      balance: (json['balance'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? false,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  /// Convertit le modèle en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'username': username,
      'balance': balance,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  /// Crée une copie avec des champs modifiés
  UserModel copyWith({
    String? id,
    String? phone,
    String? email,
    String? username,
    double? balance,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      username: username ?? this.username,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

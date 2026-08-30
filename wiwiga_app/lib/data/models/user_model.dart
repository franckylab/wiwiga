// ============================================================
// Fichier: user_model.dart
// Description: Modèle utilisateur WIWIGA avec RBAC et avatars
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

/// Rôles RBAC
enum UserRole {
  superAdmin,
  admin,
  moderator,
  test,
  user;

  String get value {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.moderator:
        return 'moderator';
      case UserRole.test:
        return 'test';
      case UserRole.user:
        return 'user';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Administrateur';
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.moderator:
        return 'Modérateur';
      case UserRole.test:
        return 'Compte Test';
      case UserRole.user:
        return 'Joueur';
    }
  }

  String get color {
    switch (this) {
      case UserRole.superAdmin:
        return '#FF0000';
      case UserRole.admin:
        return '#FF6600';
      case UserRole.moderator:
        return '#0066FF';
      case UserRole.test:
        return '#9900FF';
      case UserRole.user:
        return '#00CC66';
    }
  }

  static UserRole fromString(String? role) {
    switch (role) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      case 'test':
        return UserRole.test;
      default:
        return UserRole.user;
    }
  }
}

/// Types d'avatar prédéfinis
enum AvatarType {
  defaultAvatar,
  wiwiga1,
  wiwiga2,
  wiwiga3,
  wiwiga4,
  wiwiga5,
  wiwiga6,
  wiwiga7,
  wiwiga8;

  String get value {
    switch (this) {
      case AvatarType.defaultAvatar:
        return 'default';
      case AvatarType.wiwiga1:
        return 'wiwiga_1';
      case AvatarType.wiwiga2:
        return 'wiwiga_2';
      case AvatarType.wiwiga3:
        return 'wiwiga_3';
      case AvatarType.wiwiga4:
        return 'wiwiga_4';
      case AvatarType.wiwiga5:
        return 'wiwiga_5';
      case AvatarType.wiwiga6:
        return 'wiwiga_6';
      case AvatarType.wiwiga7:
        return 'wiwiga_7';
      case AvatarType.wiwiga8:
        return 'wiwiga_8';
    }
  }

  String get displayName {
    switch (this) {
      case AvatarType.defaultAvatar:
        return 'Avatar par défaut';
      case AvatarType.wiwiga1:
        return 'Casque Gaming';
      case AvatarType.wiwiga2:
        return 'Manette Néon';
      case AvatarType.wiwiga3:
        return 'Dé Chanceux';
      case AvatarType.wiwiga4:
        return 'Champion';
      case AvatarType.wiwiga5:
        return 'Robot';
      case AvatarType.wiwiga6:
        return 'Dragon';
      case AvatarType.wiwiga7:
        return 'Phoenix';
      case AvatarType.wiwiga8:
        return 'Étoile';
    }
  }

  String get color {
    switch (this) {
      case AvatarType.defaultAvatar:
        return '#00FF88';
      case AvatarType.wiwiga1:
        return '#FF00FF';
      case AvatarType.wiwiga2:
        return '#00FFFF';
      case AvatarType.wiwiga3:
        return '#FFFF00';
      case AvatarType.wiwiga4:
        return '#FFD700';
      case AvatarType.wiwiga5:
        return '#00FF00';
      case AvatarType.wiwiga6:
        return '#FF4400';
      case AvatarType.wiwiga7:
        return '#FF6600';
      case AvatarType.wiwiga8:
        return '#AA00FF';
    }
  }

  static AvatarType fromString(String? type) {
    switch (type) {
      case 'default':
        return AvatarType.defaultAvatar;
      case 'wiwiga_1':
        return AvatarType.wiwiga1;
      case 'wiwiga_2':
        return AvatarType.wiwiga2;
      case 'wiwiga_3':
        return AvatarType.wiwiga3;
      case 'wiwiga_4':
        return AvatarType.wiwiga4;
      case 'wiwiga_5':
        return AvatarType.wiwiga5;
      case 'wiwiga_6':
        return AvatarType.wiwiga6;
      case 'wiwiga_7':
        return AvatarType.wiwiga7;
      case 'wiwiga_8':
        return AvatarType.wiwiga8;
      default:
        return AvatarType.defaultAvatar;
    }
  }
}

/// Modèle représentant un utilisateur
class UserModel {
  final String id;
  final String? phone;
  final String? email;
  final String username;
  final String? name;
  final UserRole role;
  final AvatarType avatarType;
  final String? avatarUrl;
  @deprecated
  /// Solde legacy en FCFA (centimes/100) — conserver pour compatibilité, UI doit utiliser tokenBalance
  final double balance;
  final int tokenBalance; // wiga — source de vérité pour toutes transactions
  final bool isActive;
  final bool hasVerifiedKyc;
  final bool selfExcluded;
  final int loginCount;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    this.phone,
    this.email,
    this.username = '',
    this.name,
    this.role = UserRole.user,
    this.avatarType = AvatarType.defaultAvatar,
    this.avatarUrl,
    this.balance = 0,
    this.tokenBalance = 0,
    this.isActive = true,
    this.hasVerifiedKyc = false,
    this.selfExcluded = false,
    this.loginCount = 0,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Si l'utilisateur est admin (super_admin ou admin)
  bool get isAdmin => role == UserRole.superAdmin || role == UserRole.admin;

  /// Si l'utilisateur est super_admin
  bool get isSuperAdmin => role == UserRole.superAdmin;

  /// Si l'utilisateur est modérateur ou supérieur
  bool get isModerator =>
      role == UserRole.superAdmin ||
      role == UserRole.admin ||
      role == UserRole.moderator;

  /// Initiales pour l'avatar
  String get initials {
    if (username.isNotEmpty) {
      return username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().substring(0, username.length.clamp(0, 2).clamp(2, 2));
    }
    if (name != null && name!.isNotEmpty) {
      final parts = name!.split(' ');
      return parts.map((p) => p.isNotEmpty ? p[0] : '').join('').toUpperCase().substring(0, 2.clamp(0, 2));
    }
    return '??';
  }

  static double _parseBalance(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble() / 100.0;
    if (v is String) return (double.tryParse(v) ?? 0) / 100.0;
    return 0;
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Crée un UserModel depuis une réponse JSON API
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      username: (json['username'] ?? '').toString(),
      name: json['name']?.toString(),
      role: UserRole.fromString(json['role']?.toString()),
      avatarType: AvatarType.fromString(json['avatar_type']?.toString()),
      avatarUrl: json['avatar_url']?.toString(),
      balance: _parseBalance(json['balance']),
      tokenBalance: _parseInt(json['wiga_balance'] ?? json['token_balance']),
      isActive: json['is_active'] ?? true,
      hasVerifiedKyc: json['has_verified_kyc'] ?? false,
      selfExcluded: json['self_excluded'] ?? false,
      loginCount: _parseInt(json['login_count']),
      lastLoginAt: json['last_login_at'] != null ? DateTime.tryParse(json['last_login_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Convertit le modèle en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'username': username,
      'name': name,
      'role': role.value,
      'avatar_type': avatarType.value,
      'avatar_url': avatarUrl,
      'balance': balance,
      'token_balance': tokenBalance,
      'is_active': isActive,
      'has_verified_kyc': hasVerifiedKyc,
      'self_excluded': selfExcluded,
      'login_count': loginCount,
      'last_login_at': lastLoginAt?.toIso8601String(),
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
    String? name,
    UserRole? role,
    AvatarType? avatarType,
    String? avatarUrl,
    double? balance,
    int? tokenBalance,
    bool? isActive,
    bool? hasVerifiedKyc,
    bool? selfExcluded,
    int? loginCount,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarType: avatarType ?? this.avatarType,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      balance: balance ?? this.balance,
      tokenBalance: tokenBalance ?? this.tokenBalance,
      isActive: isActive ?? this.isActive,
      hasVerifiedKyc: hasVerifiedKyc ?? this.hasVerifiedKyc,
      selfExcluded: selfExcluded ?? this.selfExcluded,
      loginCount: loginCount ?? this.loginCount,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ============================================================
// Fichier: notification_model.dart
// Description: Modèles inbox notifications multi-canal
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

/// Notification inbox joueur (canal in_app)
class NotificationModel {
  final int id;
  final String eventType;
  final String title;
  final String body;
  final String category;
  final String priority;
  final String status;
  final bool isRead;
  final String? readAt;
  final String insertedAt;
  final String? action;

  const NotificationModel({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.status,
    required this.isRead,
    this.readAt,
    required this.insertedAt,
    this.action,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'transactional',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'queued',
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] as String?,
      insertedAt: json['inserted_at'] as String? ?? '',
      action: json['action'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': eventType,
      'title': title,
      'body': body,
      'category': category,
      'priority': priority,
      'status': status,
      'is_read': isRead,
      'read_at': readAt,
      'inserted_at': insertedAt,
      'action': action,
    };
  }

  /// Routes autorisées pour les deep-links serveur (anti open-redirect interne).
  static const allowedActions = {
    '/home',
    '/games',
    '/friends',
    '/transactions',
    '/tokens',
    '/notifications',
    '/profile',
    '/settings',
    '/leaderboard',
  };

  /// Deep-link sûr (null si absent ou non autorisé).
  String? get safeAction {
    final route = action?.trim() ?? '';
    if (route.isEmpty) return null;
    final path = route.split('?').first;
    return allowedActions.contains(path) ? route : null;
  }
}

/// Préférence utilisateur (catégorie × canal)
class NotificationPreferenceModel {
  final int id;
  final String category;
  final String channel;
  final bool enabled;

  const NotificationPreferenceModel({
    required this.id,
    required this.category,
    required this.channel,
    required this.enabled,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'channel': channel,
      'enabled': enabled,
    };
  }
}

/// Provider de notification (config admin)
class NotificationProviderModel {
  final int id;
  final String channel;
  final String name;
  final String displayName;
  final bool isActive;
  final bool isDefault;
  final int priority;
  final String lastHealthStatus;
  final String? lastError;
  final int configKeys;
  final int secretsSet;

  const NotificationProviderModel({
    required this.id,
    required this.channel,
    required this.name,
    required this.displayName,
    required this.isActive,
    required this.isDefault,
    required this.priority,
    required this.lastHealthStatus,
    this.lastError,
    this.configKeys = 0,
    this.secretsSet = 0,
  });

  factory NotificationProviderModel.fromJson(Map<String, dynamic> json) {
    return NotificationProviderModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      channel: json['channel'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      lastHealthStatus: json['last_health_status'] as String? ?? 'unchecked',
      lastError: json['last_error'] as String?,
      configKeys: (json['config_keys'] as num?)?.toInt() ?? 0,
      secretsSet: (json['secrets_set'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Template de notification (config admin)
class NotificationTemplateModel {
  final int id;
  final String key;
  final String channel;
  final String locale;
  final int version;
  final String? subject;
  final String bodyTpl;
  final List<String> requiredVariables;
  final String category;
  final bool isActive;

  const NotificationTemplateModel({
    required this.id,
    required this.key,
    required this.channel,
    required this.locale,
    required this.version,
    this.subject,
    required this.bodyTpl,
    required this.requiredVariables,
    required this.category,
    required this.isActive,
  });

  factory NotificationTemplateModel.fromJson(Map<String, dynamic> json) {
    return NotificationTemplateModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      key: json['key'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      locale: json['locale'] as String? ?? 'fr',
      version: (json['version'] as num?)?.toInt() ?? 1,
      subject: json['subject'] as String?,
      bodyTpl: json['body_tpl'] as String? ?? '',
      requiredVariables: (json['required_variables'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      category: json['category'] as String? ?? 'transactional',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

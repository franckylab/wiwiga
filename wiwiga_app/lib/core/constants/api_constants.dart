// ============================================================
// Fichier: api_constants.dart
// Description: Constantes des endpoints API WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

/// Endpoints de l'API REST
class ApiEndpoints {
  // Authentication
  static const String sendOtp = '/api/auth/send-otp';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String setPassword = '/api/auth/set-password';
  static const String checkAvailability = '/api/auth/check-availability';
  static const String completeRegistration = '/api/auth/complete-registration';
  static const String avatars = '/api/auth/avatars';
  static const String refreshToken = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';
  static const String authSettings = '/api/auth/settings';
  static const String profileUpdate = '/api/auth/profile';
  static const String profileStats = '/api/auth/profile/stats';
  static const String achievements = '/api/auth/profile/achievements';
  static const String preferences = '/api/auth/preferences';
  static const String avatarUpload = '/api/auth/avatar/upload';
  static const String sessions = '/api/auth/sessions';
  static const String changePassword = '/api/auth/change-password';
  
  // Wallet
  static const String walletBalance = '/api/wallet/balance';
  static const String deposit = '/api/wallet/deposit';
  static const String withdraw = '/api/wallet/withdraw';
  static const String transactions = '/api/wallet/transactions';
  
  // Jetons virtuels
  static const String tokenBalance = '/api/tokens/balance';
  static const String tokenSummary = '/api/tokens/summary';
  static const String tokenPurchase = '/api/tokens/purchase';
  static const String tokenExchange = '/api/tokens/exchange';
  static const String tokenTransfer = '/api/tokens/transfer';
  static const String tokenGift = '/api/tokens/gift';
  static const String tokenTransactions = '/api/tokens/transactions';
  static const String tokenPromos = '/api/tokens/promos';
  
  // Games
  static const String gamesList = '/api/games';
  static const String gameShow = '/api/games'; // + /:game_id
  static const String joinGame = '/api/games'; // + /:game_id/join
  static const String gameState = '/api/games'; // + /:game_id/state
  
  // Game stats & contenus (base + /:game_type + suffixe)
  static const String gameStats = '/stats';
  static const String gameLeaderboard = '/leaderboard';
  static const String gameMyStats = '/my-stats';
  static const String gameActivity = '/activity';
  static const String gameRules = '/rules';
  static const String gameTips = '/tips';
  
  // Rooms (Salles de jeu)
  static const String roomsList = '/api/rooms/waiting';
  static const String roomsCreate = '/api/rooms';
  static const String roomsJoinByCode = '/api/rooms/join-by-code';
  static const String roomsShow = '/api/rooms'; // + /:room_id
  static const String roomsJoin = '/api/rooms'; // + /:room_id/join
  static const String roomsLeave = '/api/rooms'; // + /:room_id/leave
  static const String roomsStart = '/api/rooms'; // + /:room_id/start
  static const String roomsCancel = '/api/rooms'; // + /:room_id/cancel
  
  // Friends (Amis)
  static const String friendsList = '/api/friends';
  static const String friendsRequests = '/api/friends/requests';
  static const String friendsSendRequest = '/api/friends/request';
  static const String friendsSearch = '/api/friends/search';
  static const String friendsLeaderboard = '/api/friends/leaderboard';
  static const String friendsActivity = '/api/friends/activity';
  
  // Webhooks
  static const String campayWebhook = '/api/webhooks/campay';
  
  // Health
  static const String health = '/api/health';
  static const String healthReady = '/api/health/ready';
  
  // User
  static const String profile = '/api/users/profile';
  
  // Admin
  static const String adminUsers = '/api/admin/users';
  static const String adminRoles = '/api/admin/roles';
  static const String adminStats = '/api/admin/stats';
  static const String adminAuditLogs = '/api/admin/audit-logs';
  static const String adminSystemHealth = '/api/admin/system-health';
  static const String adminConfigTheme = '/api/admin/config/theme';
  static const String adminConfigFeatures = '/api/admin/config/features';
  static const String adminConfigGames = '/api/admin/config/games';
  static const String adminConfigPayments = '/api/admin/config/payments';
  static const String adminConfigTokens = '/api/admin/config/tokens';
  
  // Admin - Métriques
  static const String adminMetricsDashboard = '/api/admin/metrics/dashboard';
  static const String adminMetricsFinancial = '/api/admin/metrics/financial';
  static const String adminMetricsGames = '/api/admin/metrics/games';
  static const String adminMetricsUsers = '/api/admin/metrics/users';
  static const String adminMetricsPayments = '/api/admin/metrics/payments';
  static const String adminMetricsSecurity = '/api/admin/metrics/security';
  static const String adminMetricsTimeseries = '/api/admin/metrics/timeseries';
  
  // Admin - Gestion des parties
  static const String adminGamesActive = '/api/admin/games/active';
  static const String adminGamesStatsSummary = '/api/admin/games/stats/summary';
  
  // Admin - Sécurité
  static const String adminSecurityOverview = '/api/admin/security/overview';
  static const String adminSecurityFailedAuths = '/api/admin/security/failed-auths';
  static const String adminSecurityRateLimits = '/api/admin/security/rate-limits';
  static const String adminSecurityIpWhitelist = '/api/admin/security/ip-whitelist';
  
  // Admin - Jeu responsable
  static const String adminResponsibleGamingOverview = '/api/admin/responsible-gaming/overview';
  static const String adminResponsibleGamingSelfExclusions = '/api/admin/responsible-gaming/self-exclusions';
  static const String adminResponsibleGamingRiskIndicators = '/api/admin/responsible-gaming/risk-indicators';
  
  // Admin - Notifications
  static const String adminNotifications = '/api/admin/notifications';
  static const String adminNotificationsBroadcast = '/api/admin/notifications/broadcast';
  static const String adminNotificationsUnreadCount = '/api/admin/notifications/unread-count';
  
  // Admin - Config historique & rollback
  static const String adminConfigHistory = '/api/admin/config/history';
  
  // Admin - Export
  static const String adminExportUsers = '/api/admin/export/users';
  static const String adminExportTransactions = '/api/admin/export/transactions';
  static const String adminExportGames = '/api/admin/export/games';
  
  // Admin - CRM
  static const String adminCrmSegments = '/api/admin/crm/segments';
  static const String adminCrmVip = '/api/admin/crm/vip';
  static const String adminCrmAtRisk = '/api/admin/crm/at-risk';
  static const String adminCrmPlayerSummary = '/api/admin/crm/players'; // + /:id/summary
  static const String adminCrmPlayerNotes = '/api/admin/crm/players'; // + /:id/notes
  static const String adminCrmVipTier = '/api/admin/crm/players'; // + /:id/vip-tier
  
  // Admin - Réconciliation
  static const String adminReconciliationDaily = '/api/admin/reconciliation/daily';
  static const String adminReconciliationDiscrepancies = '/api/admin/reconciliation/discrepancies';
  static const String adminReconciliationCommissions = '/api/admin/reconciliation/commissions';
  static const String adminReconciliationBalance = '/api/admin/reconciliation/balance';
  
  // Admin - Settings
  static const String adminSettings = '/api/admin/settings';
  static const String adminSettingsCategory = '/api/admin/settings/category'; // + /:category
  
  // Admin - Impersonation
  static const String adminImpersonateStart = '/api/admin/impersonate'; // + /:user_id/start
  static const String adminImpersonateStop = '/api/admin/impersonate/stop';
  static const String adminImpersonateStatus = '/api/admin/impersonate/status';
  
  // Admin - Alert Thresholds
  static const String adminAlertThresholds = '/api/admin/alert-thresholds';
  static String adminAlertResolve(String alertId) => '/api/admin/alerts/$alertId/resolve';
  
  // Admin - Analytics KPI Gaming (V3)
  static const String adminAnalyticsRevenue = '/api/admin/analytics/revenue';
  static const String adminAnalyticsPlayers = '/api/admin/analytics/players';
  static const String adminAnalyticsCohorts = '/api/admin/analytics/cohorts';
  static const String adminAnalyticsLtv = '/api/admin/analytics/ltv';
  static const String adminAnalyticsGames = '/api/admin/analytics/games';
  static const String adminAnalyticsMonetaryFlow = '/api/admin/analytics/monetary-flow';
  static const String adminAnalyticsWealthDistribution = '/api/admin/analytics/wealth-distribution';
  static const String adminAnalyticsConversionFunnel = '/api/admin/analytics/conversion-funnel';
  
  // Admin - Game Config (V3)
  static const String adminGameConfigs = '/api/admin/game-configs';
  
  // Admin - Bonuses & Promotions (V3)
  static const String adminBonuses = '/api/admin/bonuses';
  
  // Admin - Reports (V3)
  static const String adminReports = '/api/admin/reports';
  static const String adminReportsGenerate = '/api/admin/reports/generate';

  // Admin - Player Progression (V3)
  static const String adminPlayerProgressionLevels = '/api/admin/player-progression/levels';
  static const String adminPlayerProgressionCalculate = '/api/admin/player-progression/calculate';

  // Admin - Platform Config (V3)
  static const String adminPlatformConfig = '/api/admin/platform-config';
  static const String adminPlatformConfigHealth = '/api/admin/platform-config/health';
}

/// Canaux WebSocket Phoenix
class WebSocketChannels {
  // Canal matchmaking
  static const String matchmaking = 'matchmaking:lobby';
  
  // Canal jeu (dynamique: game:{game_id})
  static const String gamePrefix = 'game:';
  
  // Canal salle (dynamique: room:{room_id})
  static const String roomPrefix = 'room:';
  
  // Canal amis
  static const String friendNotif = 'friend:notif';
  
  // Canal pour notifications utilisateur
  static const String userNotifications = 'user:notifications';
  
  // Canal admin (métriques en temps réel)
  static const String adminMetrics = 'admin:metrics';
  static const String adminAlerts = 'admin:alerts';
}

/// Événements WebSocket
class WebSocketEvents {
  // Matchmaking
  static const String joinQueue = 'join_queue';
  static const String leaveQueue = 'leave_queue';
  static const String queueStatus = 'queue_status';
  static const String gameMatched = 'game_matched';
  
  // Game
  static const String phxJoin = 'phx_join';
  static const String phxLeave = 'phx_leave';
  static const String placeBet = 'place_bet';
  static const String betPlaced = 'bet_placed';
  static const String executeTurn = 'execute_turn';
  static const String turnExecuted = 'turn_executed';
  static const String gameResult = 'game_result';
  static const String playerJoined = 'player_joined';
  static const String gameStarted = 'game_started';
  
  // Room
  static const String roomUpdated = 'room_updated';
  static const String playerLeft = 'player_left';
  static const String matchStarted = 'match_started';
  static const String roomCancelled = 'room_cancelled';
  static const String playerReady = 'player_ready';
  
  // Friend
  static const String friendRequest = 'friend_request';
  static const String friendAccepted = 'friend_accepted';
  static const String friendOnline = 'friend_online';
  static const String gameInvitation = 'game_invitation';
  static const String activityUpdate = 'activity_update';
  static const String chatMessage = 'chat_message';
  
  // Match (GameMatch)
  static const String setStarted = 'set_started';
  static const String diceRolled = 'dice_rolled';
  static const String setResult = 'set_result';
  static const String matchResult = 'match_result';
  static const String voteTarget = 'vote_target';
  static const String targetCalculated = 'target_calculated';
}

/// Messages d'erreur standards
class ApiErrors {
  static const String networkError = 'Erreur de connexion réseau';
  static const String timeoutError = 'Délai d\'attente dépassé';
  static const String unauthorized = 'Non autorisé. Veuillez vous reconnecter';
  static const String serverError = 'Erreur serveur. Veuillez réessayer';
  static const String invalidResponse = 'Réponse invalide du serveur';
  static const String insufficientBalance = 'Solde insuffisant';
  static const String invalidAmount = 'Montant invalide';
}

/// Statuts de réponse API
class ApiStatus {
  static const String success = 'success';
  static const String error = 'error';
}

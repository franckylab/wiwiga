# ==================================
# WIWIGA - Router API Phoenix
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.Router
# Description: Routes API REST + WebSocket
# Refactorisé: Routes publiques (guest) vs protégées (auth)

defmodule GameHubWeb.Router do
  use Phoenix.Router
  
  import Plug.Conn
  import Phoenix.Controller
  
  # Pipeline API (public, sans auth)
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug GameHubWeb.CORSPlug
    plug GameHubWeb.SecurityHeaders
  end
  
  # Pipeline API avec authentification optionnelle (public + contexte user)
  pipeline :api_optional_auth do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug GameHubWeb.CORSPlug
    plug GameHubWeb.SecurityHeaders
    plug GameHubWeb.OptionalAuthPlug
  end
  
  # Pipeline API avec authentification JWT obligatoire
  pipeline :api_auth do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug GameHubWeb.CORSPlug
    plug GameHubWeb.SecurityHeaders
    plug GameHubWeb.AuthPlug
  end
  
  # Pipeline WebSocket
  pipeline :socket do
    # plug :socket_auth
  end
  
  # Pipeline Admin
  pipeline :admin_only do
    plug GameHubWeb.AdminAuthPlug
  end
  
  ## Route Welcome (racine)
  
  scope "/", GameHubWeb do
    pipe_through :api
    
    get "/", WelcomeController, :index
  end
  
  ## ========================================
  ## Routes API PUBLIQUES (accessibles sans auth)
  ## ========================================
  
  scope "/api", GameHubWeb do
    pipe_through :api
    
    # Health Checks (public pour monitoring)
    get "/health", HealthController, :health
    get "/health/ready", HealthController, :ready
    get "/health/db", HealthController, :db_health
    get "/health/redis", HealthController, :redis_health
    
    # Authentification
    post "/auth/send-otp", AuthController, :send_otp
    post "/auth/verify-otp", AuthController, :verify_otp
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/check-availability", AuthController, :check_availability
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
    get "/auth/avatars", AuthController, :avatars
    
    # Debug endpoints (DEV ONLY)
    post "/auth/debug-reset-passwords", AuthController, :debug_reset_passwords
    post "/auth/debug-inspect-login", AuthController, :debug_inspect_login
    
    # Webhooks paiement (signature vérification interne)
    post "/webhooks/campay", PaymentWebhookController, :campay_callback
  end
  
  ## ========================================
  ## Routes API PUBLIQUES avec auth optionnelle
  ## (contenu accessible sans auth, mais enrichi si connecté)
  ## ========================================
  
  scope "/api", GameHubWeb do
    pipe_through :api_optional_auth
    
    # Catalogue de jeux (PUBLIC)
    get "/games", GameController, :index
    get "/games/:game_id", GameController, :show
    
    # Contenu informatif des jeux (PUBLIC)
    get "/games/:game_type/rules", GameStatsController, :rules
    get "/games/:game_type/tips", GameStatsController, :tips
    
    # Stats globales et activité communauté (PUBLIC)
    get "/games/:game_type/stats", GameStatsController, :stats
    get "/games/:game_type/activity", GameStatsController, :activity
    
    # Leaderboard global (PUBLIC, my_rank enrichi si connecté)
    get "/games/:game_type/leaderboard", GameStatsController, :leaderboard
    
    # Promotions (PUBLIC)
    get "/tokens/promos", TokenController, :promos
  end
  
  ## ========================================
  ## Routes API AUTHENTIFIÉES (JWT obligatoire)
  ## ========================================
  
  scope "/api", GameHubWeb do
    pipe_through :api_auth
    
    # Vérification de session / Profil
    get "/auth/me", AuthController, :me
    post "/auth/complete-registration", AuthController, :complete_registration
    post "/auth/set-password", AuthController, :set_password
    put "/auth/profile", AuthController, :update_profile
    get "/auth/profile/stats", AuthController, :get_profile_stats
    get "/auth/profile/achievements", AuthController, :get_achievements
    
    # Préférences utilisateur
    get "/auth/preferences", AuthController, :get_preferences
    put "/auth/preferences", AuthController, :update_preferences
    
    # Sessions utilisateur
    get "/auth/sessions", AuthController, :get_sessions
    delete "/auth/sessions/:id", AuthController, :revoke_session
    
    # Changement de mot de passe
    post "/auth/change-password", AuthController, :change_password
    
    # Upload avatar
    post "/auth/avatar/upload", AuthController, :upload_avatar
    
    # Préférences auth (OTP)
    get "/auth/settings", AuthController, :get_settings
    put "/auth/settings", AuthController, :update_settings
    
    # Compte monétaire
    get "/wallet/balance", WalletController, :balance
    post "/wallet/deposit", WalletController, :deposit
    post "/wallet/withdraw", WalletController, :withdraw
    get "/wallet/transactions", WalletController, :list_transactions
    
    # Jetons virtuels — seuls achat, cadeau ami et promos
    get "/tokens/balance", TokenController, :balance
    get "/tokens/summary", TokenController, :summary
    post "/tokens/purchase", TokenController, :purchase
    post "/tokens/gift", TokenController, :gift
    get "/tokens/transactions", TokenController, :transactions
    post "/tokens/promos/:id/redeem", TokenController, :redeem_promo
    
    # Partie active pour redirection auto (doit être avant :game_id pour éviter collision)
    get "/games/me/active", GameController, :active
    # Debug match (test tours)
    get "/debug/match/:game_id", GameController, :debug_match
    post "/debug/match/:game_id/roll", GameController, :debug_roll
    post "/debug/match/:game_id/start_set", GameController, :debug_start_set
    # REST fallback temps réel pour jeu de dés (si WebSocket indisponible)
    post "/games/:game_id/roll", GameController, :roll
    post "/games/:game_id/vote", GameController, :vote
    post "/games/:game_id/start_set", GameController, :start_set_rest
    # Revanche opt-out (fin de partie) + sortie d'interface
    post "/games/:game_id/rematch/propose", GameController, :propose_rematch
    post "/games/:game_id/rematch/respond", GameController, :respond_rematch
    post "/games/:game_id/rematch/start", GameController, :start_rematch
    post "/games/:game_id/rematch/cancel", GameController, :cancel_rematch
    post "/games/:game_id/leave", GameController, :leave_match
    # Actions de jeu (PROTÉGÉ) — Partie rapide unifiée (mise+rule) lobby synchronisé
    post "/games/:game_id/join", GameController, :join
    delete "/games/:game_id/queue", GameController, :leave_queue
    get "/games/:game_id/queue/status", GameController, :queue_status
    get "/games/:game_id/quick-lobby", GameController, :quick_lobby
    post "/games/:game_id/quick-ready", GameController, :quick_ready
    get "/games/:game_id/state", GameController, :game_state
    
    # Stats personnelles (PROTÉGÉ)
    get "/games/:game_type/my-stats", GameStatsController, :my_stats
    
    # Salles de jeu (Rooms)
    get "/rooms/waiting", RoomController, :waiting
    post "/rooms", RoomController, :create
    post "/rooms/join-by-code", RoomController, :join_by_code
    get "/rooms/:room_id", RoomController, :show
    post "/rooms/:room_id/join", RoomController, :join
    post "/rooms/:room_id/leave", RoomController, :leave
    post "/rooms/:room_id/start", RoomController, :start
    post "/rooms/:room_id/cancel", RoomController, :cancel
    
    # Amis (Friend System)
    get "/friends", FriendController, :index
    get "/friends/requests", FriendController, :pending_requests
    post "/friends/request", FriendController, :send_request
    post "/friends/request/:id/accept", FriendController, :accept_request
    post "/friends/request/:id/reject", FriendController, :reject_request
    delete "/friends/:id", FriendController, :remove_friend
    post "/friends/:id/block", FriendController, :block_friend
    get "/friends/search", FriendController, :search
    get "/friends/leaderboard", FriendController, :leaderboard
    get "/friends/activity", FriendController, :activity
    post "/friends/:id/add-from-game", FriendController, :add_from_game
    
    # Jeu responsable (utilisateur)
    get "/responsible-gaming/limits", ResponsibleGamingController, :get_my_limits
    put "/responsible-gaming/limits", ResponsibleGamingController, :update_my_limits
    post "/responsible-gaming/self-exclude", ResponsibleGamingController, :self_exclude
  end
  
  ## WebSocket
  ## Les channels sont défins dans GameHubWeb.UserSocket
  ## Route: /socket → UserSocket → channel "game:*"
  
  ## ========================================
  ## Routes Admin (auth admin obligatoire)
  ## ========================================
  
  scope "/api/admin", GameHubWeb do
    pipe_through [:api_auth, :admin_only]
    
    # Gestion utilisateurs (RBAC)
    get "/users", AdminController, :list_users
    get "/users/:id", AdminController, :get_user
    post "/users", AdminController, :create_user
    put "/users/:id", AdminController, :get_user  # fallback
    put "/users/:id/role", AdminController, :update_user_role
    put "/users/:id/activate", AdminController, :toggle_user_active
    
    # Rôles et permissions
    get "/roles", AdminController, :list_roles
    
    # Logs d'audit
    get "/audit-logs", AdminController, :list_audit_logs
    
    # Feature flags
    post "/feature-flags", AdminController, :create_feature_flag
    put "/feature-flags/:flag_name", AdminController, :update_feature_flag
    
    # Réconciliation
    post "/reconciliation", AdminController, :trigger_reconciliation
    
    # Statistiques
    get "/stats", AdminController, :stats
    
    # Supervision / Monitoring
    get "/system-health", AdminController, :system_health
    
    # ========================================
    # Configuration Dynamique
    # ========================================
    
    # Thème UI (singleton)
    get "/config/theme", API.Admin.ConfigController, :get_theme_config
    put "/config/theme", API.Admin.ConfigController, :update_theme_config
    
    # Features (singleton)
    get "/config/features", API.Admin.ConfigController, :get_feature_config
    put "/config/features", API.Admin.ConfigController, :update_feature_config
    
    # Jeux (par type)
    get "/config/games", API.Admin.ConfigController, :list_game_configs
    get "/config/games/:type", API.Admin.ConfigController, :get_game_config
    put "/config/games/:type", API.Admin.ConfigController, :update_game_config
    
    # Paiements (par provider)
    get "/config/payments", API.Admin.ConfigController, :list_payment_configs
    get "/config/payments/:provider", API.Admin.ConfigController, :get_payment_config
    put "/config/payments/:provider", API.Admin.ConfigController, :update_payment_config
    
    # Jetons (config)
    get "/config/tokens", TokenConfigController, :get_config
    put "/config/tokens", TokenConfigController, :update_config
    
    # Promotions
    get "/promos", TokenConfigController, :list_promos
    post "/promos", TokenConfigController, :create_promo
    put "/promos/:id", TokenConfigController, :update_promo
    
    # ========================================
    # Métriques Admin
    # ========================================
    get "/metrics/dashboard", AdminMetricsController, :dashboard
    get "/metrics/financial", AdminMetricsController, :financial
    get "/metrics/games", AdminMetricsController, :games
    get "/metrics/users", AdminMetricsController, :users
    get "/metrics/payments", AdminMetricsController, :payments
    get "/metrics/security", AdminMetricsController, :security
    get "/metrics/timeseries", AdminMetricsController, :timeseries
    
    # ========================================
    # Gestion des Parties (Supervision)
    # ========================================
    get "/games/active", AdminGameManagerController, :active_games
    get "/games/active/:id", AdminGameManagerController, :active_game_detail
    post "/games/:id/force-close", AdminGameManagerController, :force_close
    get "/games/stats/summary", AdminGameManagerController, :stats_summary
    
    # ========================================
    # Sécurité Admin
    # ========================================
    get "/security/overview", AdminSecurityController, :overview
    get "/security/failed-auths", AdminSecurityController, :failed_auths
    get "/security/rate-limits", AdminSecurityController, :rate_limits
    get "/security/ip-whitelist", AdminSecurityController, :list_whitelist
    post "/security/ip-whitelist", AdminSecurityController, :add_to_whitelist
    delete "/security/ip-whitelist/:ip", AdminSecurityController, :remove_from_whitelist
    post "/security/ban-user/:id", AdminSecurityController, :ban_user
    delete "/security/ban-user/:id", AdminSecurityController, :unban_user
    
    # ========================================
    # Jeu Responsable
    # ========================================
    get "/responsible-gaming/overview", AdminResponsibleGamingController, :overview
    put "/responsible-gaming/users/:id/limits", AdminResponsibleGamingController, :set_limits
    get "/responsible-gaming/self-exclusions", AdminResponsibleGamingController, :self_exclusions
    post "/responsible-gaming/self-exclusions/:id/override", AdminResponsibleGamingController, :override_self_exclusion
    get "/responsible-gaming/risk-indicators", AdminResponsibleGamingController, :risk_indicators
    
    # ========================================
    # Notifications Admin
    # ========================================
    get "/notifications", AdminNotificationsController, :list
    put "/notifications/:id/read", AdminNotificationsController, :mark_read
    post "/notifications/broadcast", AdminNotificationsController, :broadcast
    get "/notifications/unread-count", AdminNotificationsController, :unread_count
    
    # ========================================
    # Alertes Admin
    # ========================================
    get "/alerts", AdminSecurityController, :overview
    
    # ========================================
    # Export de données (CSV)
    # ========================================
    get "/export/users", AdminExportController, :export_users
    get "/export/transactions", AdminExportController, :export_transactions
    get "/export/games", AdminExportController, :export_games
    
    # ========================================
    # Historique et Rollback Configuration
    # ========================================
    get "/config/history", API.Admin.ConfigController, :config_history
    post "/config/rollback/:log_id", API.Admin.ConfigController, :rollback_config
    
    # ========================================
    # CRM Joueurs + Segmentation
    # ========================================
    get "/crm/segments", AdminCRMController, :segments
    get "/crm/players/:id/summary", AdminCRMController, :player_summary
    post "/crm/players/:id/notes", AdminCRMController, :add_note
    get "/crm/players/:id/notes", AdminCRMController, :list_notes
    get "/crm/vip", AdminCRMController, :vip_players
    put "/crm/players/:id/vip-tier", AdminCRMController, :set_vip_tier
    get "/crm/at-risk", AdminCRMController, :at_risk_players
    
    # ========================================
    # Réconciliation Financière
    # ========================================
    get "/reconciliation/daily", AdminReconciliationController, :daily
    get "/reconciliation/discrepancies", AdminReconciliationController, :discrepancies
    get "/reconciliation/commissions", AdminReconciliationController, :commissions
    get "/reconciliation/balance", AdminReconciliationController, :balance
    
    # ========================================
    # Settings Système
    # ========================================
    get "/settings", AdminSettingsController, :index
    get "/settings/category/:category", AdminSettingsController, :by_category
    put "/settings/:key", AdminSettingsController, :update
    
    # ========================================
    # Impersonation
    # ========================================
    post "/impersonate/:user_id/start", AdminImpersonationController, :start
    post "/impersonate/stop", AdminImpersonationController, :stop
    get "/impersonate/status", AdminImpersonationController, :status
    
    # ========================================
    # Alert Thresholds (monitoring auto)
    # ========================================
    get "/alert-thresholds", AdminMetricsController, :list_thresholds
    put "/alert-thresholds/:id", AdminMetricsController, :update_threshold
    post "/alert-thresholds/check", AdminMetricsController, :trigger_check
    post "/alerts/:id/resolve", AdminMetricsController, :resolve_alert
    
    # ========================================
    # Analytics KPI Gaming (V3)
    # ========================================
    get "/analytics/revenue", AdminAnalyticsController, :revenue
    get "/analytics/players", AdminAnalyticsController, :players
    get "/analytics/cohorts", AdminAnalyticsController, :cohorts
    get "/analytics/ltv", AdminAnalyticsController, :ltv
    get "/analytics/games", AdminAnalyticsController, :games
    get "/analytics/monetary-flow", AdminAnalyticsController, :monetary_flow
    get "/analytics/wealth-distribution", AdminAnalyticsController, :wealth_distribution
    get "/analytics/conversion-funnel", AdminAnalyticsController, :conversion_funnel
    
    # ========================================
    # Game Config (V3)
    # ========================================
    get "/game-configs", AdminGameConfigController, :index
    put "/game-configs/:game_type", AdminGameConfigController, :update
    post "/game-configs", AdminGameConfigController, :create

    # ========================================
    # Règles Moteur — sets/dés (source GameRules)
    # ========================================
    get "/game-rules", AdminGameRulesController, :index
    get "/game-rules/:game_type/:rule_type", AdminGameRulesController, :show
    put "/game-rules/:game_type/:rule_type", AdminGameRulesController, :update
    
    # ========================================
    # Bonuses & Promotions (V3)
    # ========================================
    get "/bonuses", AdminBonusesController, :index
    post "/bonuses", AdminBonusesController, :create
    put "/bonuses/:id", AdminBonusesController, :update
    post "/bonuses/:id/toggle", AdminBonusesController, :toggle
    get "/bonuses/:id/stats", AdminBonusesController, :stats
    
    # ========================================
    # Reports (V3)
    # ========================================
    get "/reports", AdminReportsController, :index
    post "/reports/generate", AdminReportsController, :generate
    get "/reports/:id/download", AdminReportsController, :download

    # ========================================
    # Player Progression (V3)
    # ========================================
    get "/player-progression/levels", AdminPlayerProgressionController, :levels
    post "/player-progression/levels", AdminPlayerProgressionController, :create_level
    put "/player-progression/levels/:tier", AdminPlayerProgressionController, :update_level
    delete "/player-progression/levels/:tier", AdminPlayerProgressionController, :delete_level
    get "/player-progression/calculate/:xp", AdminPlayerProgressionController, :calculate_tier

    # ========================================
    # XP Rules (Règles de gain XP par jeu)
    # ========================================
    get "/xp-rules", AdminXPRulesController, :index
    get "/xp-rules/:game_type", AdminXPRulesController, :show
    post "/xp-rules", AdminXPRulesController, :upsert
    put "/xp-rules/:game_type", AdminXPRulesController, :upsert
    delete "/xp-rules/:game_type", AdminXPRulesController, :delete
    post "/xp-rules/calculate", AdminXPRulesController, :calculate

    # ========================================
    # Platform Config (V3)
    # ========================================
    get "/platform-config", AdminPlatformConfigController, :index
    get "/platform-config/health", AdminPlatformConfigController, :health
    get "/platform-config/:category", AdminPlatformConfigController, :show
    put "/platform-config/:category/:key", AdminPlatformConfigController, :update
    put "/platform-config/:category/batch", AdminPlatformConfigController, :batch_update
  end
end

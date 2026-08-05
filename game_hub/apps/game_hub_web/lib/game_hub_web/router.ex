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
    
    # Jetons virtuels
    get "/tokens/balance", TokenController, :balance
    get "/tokens/summary", TokenController, :summary
    post "/tokens/purchase", TokenController, :purchase
    post "/tokens/exchange", TokenController, :exchange
    post "/tokens/transfer", TokenController, :transfer
    post "/tokens/gift", TokenController, :gift
    get "/tokens/transactions", TokenController, :transactions
    post "/tokens/promos/:id/redeem", TokenController, :redeem_promo
    
    # Actions de jeu (PROTÉGÉ)
    post "/games/:game_id/join", GameController, :join
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
  end
end

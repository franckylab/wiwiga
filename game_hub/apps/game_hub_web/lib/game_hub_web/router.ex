# ==================================
# WIWIGA - Router API Phoenix
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.Router
# Description: Routes API REST + WebSocket

defmodule GameHubWeb.Router do
  use Phoenix.Router
  
  import Plug.Conn
  import Phoenix.Controller
  
  # Les controllers seront référencés directement dans les routes
  
  # Pipeline API avec CORS
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug GameHubWeb.CORSPlug
  end
  
  # Pipeline API avec authentification JWT
  pipeline :api_auth do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug GameHubWeb.CORSPlug
    plug GameHubWeb.AuthPlug
  end
  
  # Pipeline WebSocket
  pipeline :socket do
    # plug :socket_auth
  end
  
  ## Route Welcome (racine)
  
  scope "/", GameHubWeb do
    pipe_through :api
    
    get "/", WelcomeController, :index
  end
  
  ## Routes API Publiques
  
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
    post "/auth/refresh", AuthController, :refresh
    
    # Webhooks paiement (signature verification interne)
    post "/webhooks/campay", PaymentWebhookController, :campay_callback
  end
  
  ## Routes API Authentifiées
  
  scope "/api", GameHubWeb do
    pipe_through :api_auth
    
    # Portefeuille
    get "/wallet/balance", WalletController, :balance
    post "/wallet/deposit", WalletController, :deposit
    post "/wallet/withdraw", WalletController, :withdraw
    get "/wallet/transactions", WalletController, :list_transactions
    
    # Jeux
    get "/games", GameController, :index
    get "/games/:game_id", GameController, :show
    post "/games/:game_id/join", GameController, :join
    get "/games/:game_id/state", GameController, :game_state
  end
  
  ## WebSocket
  ## Les channels sont défins dans GameHubWeb.UserSocket
  ## Route: /socket → UserSocket → channel "game:*"
  
  ## Routes Admin (futur)
  
  # scope "/api/admin", GameHubWeb do
  #   pipe_through [:api_auth, :admin_only]
  #   
  #   # Gestion utilisateurs
  #   # Gestion commissions
  #   # Statistiques
  # end
end

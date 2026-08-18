# ==================================
# WIWIGA - Supervision Tree GameHub
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Application do
  @moduledoc """
  Application OTP GameHub - Point d'entrée supervision tree.
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Repo PostgreSQL
      {GameHub.Repo, []},
      
      # Connection Redis (config depuis env vars)
      {Redix, [
        name: GameHub.Redis,
        host: GameHub.EnvConfig.get("REDIS_HOST", "localhost"),
        port: GameHub.EnvConfig.get_integer("REDIS_PORT", 6379)
      ]},
      
      # PubSub pour WebSocket
      {Phoenix.PubSub, name: GameHub.PubSub, pool_size: 4},
      
      # Registry plugins jeux
      {Registry, keys: :unique, name: GameHub.GameRegistry},
      
      # Game State Manager (GenServer)
      GameHub.GameStateManager,
      
      # Game Rules Cache (ETS)
      {GameHub.GameRules, []},
      
      # Game Match Manager (GenServer)
      GameHub.GameMatch,
      
      # Game Room Manager (GenServer)
      GameHub.GameRoom,
      
      # Admin Alert Thresholds Monitor (GenServer)
      GameHub.Admin.AlertThresholds
    ]
    
    opts = [strategy: :one_for_one, name: GameHub.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

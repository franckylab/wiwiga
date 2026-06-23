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
      
      # Connection Redis
      {Redix, [
        name: GameHub.Redis,
        host: "redis",
        port: 6379
      ]},
      
      # PubSub pour WebSocket
      {Phoenix.PubSub, name: GameHub.PubSub, pool_size: 4},
      
      # Registry plugins jeux
      {Registry, keys: :unique, name: GameHub.GameRegistry},
      
      # Module Portefeuille (GenServer)
      # GameHub.WalletSupervisor
    ]
    
    opts = [strategy: :one_for_one, name: GameHub.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

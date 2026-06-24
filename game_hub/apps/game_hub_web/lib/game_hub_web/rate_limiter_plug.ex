# ==================================
# WIWIGA - Plug Rate Limiting
# ==================================
# Limitation du nombre de requêtes par IP

defmodule GameHubWeb.RateLimiterPlug do
  @moduledoc """
  Plug pour limiter le nombre de requêtes par IP.
  
  ## Configuration
  Variables d'environnement:
  - ENABLE_RATE_LIMITING: true/false
  - RATE_LIMIT_REQUESTS: Nombre de requêtes autorisées
  - RATE_LIMIT_WINDOW_SECONDS: Fenêtre de temps en secondes
  
  ## Usage
  Dans le router:
  ```
  pipeline :api do
    plug GameHubWeb.RateLimiterPlug
  end
  ```
  
  ## Stockage
  Utilise Redis pour le stockage distribué.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias GameHub.{EnvConfig, Redis}
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    unless EnvConfig.get_boolean("ENABLE_RATE_LIMITING", false) do
      # Rate limiting désactivé
      conn
    else
      check_rate_limit(conn)
    end
  end
  
  @doc """
  Vérifie le rate limiting pour une IP.
  """
  def check_rate_limit(conn) do
    ip = get_ip(conn)
    key = "rate_limit:#{ip}"
    
    max_requests = EnvConfig.get_integer("RATE_LIMIT_REQUESTS", 100)
    window_seconds = EnvConfig.get_integer("RATE_LIMIT_WINDOW_SECONDS", 3600)
    
    case Redix.command(Redis, ["INCR", key]) do
      {:ok, count} ->
        # Définir TTL si première requête
        if count == 1 do
          Redix.command(Redis, ["EXPIRE", key, to_string(window_seconds)])
        end
        
        if count > max_requests do
          # Rate limit exceeded
          conn
          |> put_resp_header("x-ratelimit-limit", to_string(max_requests))
          |> put_resp_header("x-ratelimit-remaining", "0")
          |> put_resp_header("retry-after", to_string(window_seconds))
          |> put_status(429)
          |> json(%{
            error: %{
              message: "Trop de requêtes. Réessayez plus tard.",
              code: "RATE_LIMIT_EXCEEDED"
            }
          })
          |> halt()
        else
          # OK
          remaining = max(0, max_requests - count)
          
          conn
          |> put_resp_header("x-ratelimit-limit", to_string(max_requests))
          |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        end
      
      {:error, _} ->
        # Redis error - laisser passer
        conn
    end
  end
  
  # Fonctions privées
  
  defp get_ip(conn) do
    # Récupérer IP depuis headers (support proxy)
    conn
    |> get_req_header("x-forwarded-for")
    |> List.first()
    |> case do
      nil ->
        # IP directe
        conn.remote_ip
        |> Tuple.to_list()
        |> Enum.join(".")
      
      forwarded ->
        # Premier IP dans la liste (client original)
        forwarded
        |> String.split(",")
        |> hd()
        |> String.trim()
    end
  end
end

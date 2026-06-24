# ==================================
# WIWIGA - Plug CORS Sécurisé
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.CORSPlug
# Description: Configuration CORS sécurisée pour WIWIGA

defmodule GameHubWeb.CORSPlug do
  @moduledoc """
  Plug CORS (Cross-Origin Resource Sharing) sécurisé.
  
  ## Configuration
  - Origins whitelist uniquement
  - Méthodes autorisées limitées
  - Headers sécurisés
  - Credentials autorisés
  
  ## Sécurité
  - JAMAIS d'origine wildcard (*)
  - JAMAIS de headers wildcard
  - Max age 24h
  """
  
  @behaviour Plug
  
  import Plug.Conn
  
  @doc """
  Options CORS sécurisées.
  """
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts
  
  @doc """
  Applique headers CORS.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    origin = get_req_header(conn, "origin") |> List.first()
    
    if allowed_origin?(origin) do
      conn
      |> put_resp_header("access-control-allow-origin", origin)
      |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-Requested-With")
      |> put_resp_header("access-control-allow-credentials", "true")
      |> put_resp_header("access-control-max-age", "86400")
      |> handle_preflight()
    else
      conn
    end
  end
  
  # === Fonctions Privées ===
  
  defp allowed_origin?(nil), do: false
  
  defp allowed_origin?(origin) do
    allowed = get_allowed_origins()
    origin in allowed
  end
  
  defp get_allowed_origins do
    # Depuis config ou variables d'environnement
    Application.get_env(:game_hub_web, :cors_origins, [
      "http://localhost:3000", # Flutter dev
      "http://localhost:8080", # Flutter web dev
      "https://wiwiga.com", # Production
      "https://app.wiwiga.com" # Production app
    ])
  end
  
  defp handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(204, "")
    |> halt()
  end
  
  defp handle_preflight(conn), do: conn
end
# ==================================
# WIWIGA - Plug CORS
# ==================================
# Gestion des Cross-Origin Resource Sharing

defmodule GameHubWeb.CORSPlug do
  @moduledoc """
  Plug pour gérer les headers CORS.
  
  ## Configuration
  Variables d'environnement:
  - ALLOWED_ORIGINS: Liste des origines autorisées (séparées par virgules)
  - En développement: * (toutes)
  - En production: domaines spécifiques uniquement
  
  ## Usage
  Dans le router:
  ```
  pipeline :api do
    plug GameHubWeb.CORSPlug
  end
  ```
  """
  
  import Plug.Conn
  alias GameHub.EnvConfig
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    conn
    |> put_cors_headers()
    |> handle_preflight()
  end
  
  @doc """
  Récupère la liste des origines autorisées.
  """
  def allowed_origins do
    case EnvConfig.get("ALLOWED_ORIGINS", "*") do
      "*" -> ["*"]
      origins -> String.split(origins, ",") |> Enum.map(&String.trim/1)
    end
  end
  
  # Fonctions privées
  
  defp put_cors_headers(conn) do
    allowed = allowed_origins()
    
    origin = get_req_header(conn, "origin") |> List.first()
    
    # Vérifier si l'origine est autorisée
    allowed_origin =
      cond do
        "*" in allowed -> "*"
        origin in allowed -> origin
        true -> List.first(allowed) || "*"
      end
    
    conn
    |> put_resp_header("access-control-allow-origin", allowed_origin)
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-Requested-With")
    |> put_resp_header("access-control-expose-headers", "X-Request-Id")
    |> put_resp_header("access-control-max-age", "86400") # 24h
  end
  
  defp handle_preflight(conn) do
    if conn.method == "OPTIONS" do
      conn
      |> send_resp(204, "")
      |> halt()
    else
      conn
    end
  end
end

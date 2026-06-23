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

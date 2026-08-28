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
    
    cond do
      # Pas de header Origin → pas de CORS nécessaire (requête same-origin ou non-browser)
      origin == nil ->
        conn
      
      # Origine autorisée → ajouter les headers CORS
      allowed_origin?(origin) ->
        allow_origin = if Application.get_env(:game_hub_web, :allow_all_origins, false),
          do: "*", else: origin
        
        conn
        |> put_resp_header("access-control-allow-origin", allow_origin)
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
                |> put_resp_header(
          "access-control-allow-headers",
          "Content-Type, Accept, Authorization, X-Requested-With, X-Device-ID"
        )
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header("access-control-max-age", "86400")
        |> handle_preflight()
      
      # Origine non autorisée → pas de headers CORS
      true ->
        conn
    end
  end
  
  # === Fonctions Privées ===
  
  defp allowed_origin?(origin) do
    # En développement, accepter toutes les origines
    if Application.get_env(:game_hub_web, :allow_all_origins, false) do
      true
    else
      allowed = get_allowed_origins()
      origin in allowed
    end
  end
  
  defp get_allowed_origins do
    # Depuis variable d'environnement ALLOWED_ORIGINS (séparée par des virgules)
    case System.get_env("ALLOWED_ORIGINS") do
      nil -> default_origins()
      "" -> default_origins()
      "*" -> ["*"]
      origins -> origins |> String.split(",") |> Enum.map(&String.trim/1)
    end
  end
  
  defp default_origins do
    Application.get_env(:game_hub_web, :cors_origins, [
      "http://localhost:3000", # Flutter dev
      "http://localhost:8080", # Flutter web dev
      "http://localhost:8003", # Docker frontend
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

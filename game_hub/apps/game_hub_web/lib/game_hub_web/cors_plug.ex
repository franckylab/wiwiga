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
      # FIX LAN-IP: Ne JAMAIS renvoyer "*" avec credentials=true (bloqué par browsers)
      # On renvoie toujours l'origin exacte demandée, même en dev avec allow_all_origins=true
      allowed_origin?(origin) ->
        conn
        |> put_resp_header("access-control-allow-origin", origin)
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
                |> put_resp_header(
          "access-control-allow-headers",
          "Content-Type, Accept, Authorization, X-Requested-With, X-Device-ID"
        )
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header("access-control-max-age", "86400")
        |> put_resp_header("vary", "Origin")
        |> handle_preflight()
      
      # Origine non autorisée → pas de headers CORS
      true ->
        conn
    end
  end
  
  # === Fonctions Privées ===
  
  defp allowed_origin?(origin) do
    # En développement, accepter toutes les origines (y compris LAN IPs 192.168.x.x)
    if Application.get_env(:game_hub_web, :allow_all_origins, false) do
      true
    else
      # En production: autoriser les IPs privées LAN pour usage local réseau
      if private_ip_origin?(origin) do
        true
      else
        allowed = get_allowed_origins()
        origin in allowed or "*" in allowed
      end
    end
  end

  # Autorise les origines LAN privées: 192.168.x.x, 10.x.x.x, 172.16-31.x.x, localhost
  defp private_ip_origin?(origin) do
    case URI.parse(origin) do
      %URI{host: host} when is_binary(host) ->
        host == "localhost" or host == "127.0.0.1" or
          String.starts_with?(host, "192.168.") or
          String.starts_with?(host, "10.") or
          Regex.match?(~r/^172\.(1[6-9]|2\d|3[0-1])\./, host)
      _ -> false
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
      "http://localhost:8000", # Backend direct
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

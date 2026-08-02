# ==================================
# WIWIGA - Plug Authentification Optionnelle
# ==================================
# Tente d'extraire l'utilisateur sans bloquer si pas de token.
# Utilisé pour les routes publiques qui enrichissent la réponse
# avec des données utilisateur (ex: leaderboard avec my_rank).

defmodule GameHubWeb.OptionalAuthPlug do
  @moduledoc """
  Plug d'authentification optionnelle.
  
  Contrairement à AuthPlug, ce plug ne bloque PAS la requête
  si aucun token n'est présent. Il tente d'extraire l'utilisateur
  et met `nil` dans `current_user_id` si non authentifié.
  
  ## Usage
  ```
  pipeline :api_optional_auth do
    plug GameHubWeb.OptionalAuthPlug
  end
  ```
  """
  
  import Plug.Conn
  alias GameHub.Auth
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case extract_token(conn) do
      {:ok, user_id} ->
        Plug.Conn.put_private(conn, :current_user_id, user_id)
      
      {:error, _} ->
        # Pas de token ou token invalide → pas bloquant
        Plug.Conn.put_private(conn, :current_user_id, nil)
    end
  end
  
  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Auth.verify_jwt_token(token) do
          {:ok, %{user_id: user_id}} -> {:ok, to_string(user_id)}
          {:error, reason} -> {:error, reason}
        end
      
      _ ->
        {:error, :no_token}
    end
  end
end

# ==================================
# WIWIGA - Plug Authentification JWT
# ==================================
# Plug pour vérifier les tokens JWT
# Mode développement désactivé en production

defmodule GameHubWeb.AuthPlug do
  @moduledoc """
  Plug d'authentification JWT.
  
  ## Usage
  Dans le router:
  ```
  pipeline :api_auth do
    plug GameHubWeb.AuthPlug
  end
  ```
  
  ## Sécurité Production
  - En production: JWT OBLIGATOIRE
  - En développement: fallback user autorisé
  
  ## Grace Period
  Pour les routes de jeu, accepte les tokens expirés depuis
  moins de 5 minutes (grace period) pour ne pas interrompre
  une partie en cours.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias GameHub.{Auth, EnvConfig}
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    grace_period = Keyword.get(opts, :grace_period, false)
    
    case extract_and_verify_token(conn, grace_period) do
      {:ok, user_id} ->
        # Utilisateur authentifié
        conn
        |> Plug.Conn.put_private(:current_user_id, user_id)
      
      {:ok, user_id, :grace} ->
        # Utilisateur authentifié via grace period
        conn
        |> Plug.Conn.put_private(:current_user_id, user_id)
        |> Plug.Conn.put_private(:auth_grace, true)
      
      {:error, reason} ->
        # Token invalide ou manquant
        conn
        |> put_status(401)
        |> json(%{
          error: %{
            message: authentication_error_message(reason),
            code: error_code(reason)
          }
        })
        |> halt()
    end
  end
  
  @doc """
  Récupère l'ID utilisateur depuis le conn.
  """
  def get_current_user_id(conn) do
    conn.private[:current_user_id]
  end
  
  @doc """
  Récupère l'utilisateur complet depuis le conn.
  """
  def get_current_user(conn) do
    user_id = get_current_user_id(conn)
    if user_id do
      GameHub.Repo.get(GameHub.Users.User, user_id)
    else
      nil
    end
  end
  
  # Fonctions privées
  
  defp extract_and_verify_token(conn, grace_period) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_token_with_grace(token, grace_period)
      
      _ ->
        # Pas de token
        {:error, :missing_token}
    end
  end
  
  defp verify_token_with_grace(token, true) do
    # Grace period activée (routes de jeu)
    case Auth.verify_jwt_token_with_grace(token) do
      {:ok, %{user_id: user_id, grace: true}} ->
        {:ok, to_string(user_id), :grace}
      
      {:ok, %{user_id: user_id}} ->
        {:ok, to_string(user_id)}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp verify_token_with_grace(token, false) do
    case Auth.verify_jwt_token(token) do
      {:ok, %{user_id: user_id}} -> {:ok, to_string(user_id)}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp authentication_error_message(:invalid_token), do: "Token invalide ou expiré"
  defp authentication_error_message(:missing_token), do: "Token d'authentification requis"
  defp authentication_error_message(:token_expired), do: "Session expirée. Veuillez vous reconnecter."
  defp authentication_error_message(:token_revoked), do: "Session révoquée. Veuillez vous reconnecter."
  defp authentication_error_message({:invalid_token_type, actual, expected}),
    do: "Type de token invalide (#{actual} au lieu de #{expected})"
  defp authentication_error_message(_), do: "Authentification échouée"
  
  defp error_code(:token_expired), do: "SESSION_EXPIRED"
  defp error_code(:token_revoked), do: "TOKEN_REVOKED"
  defp error_code(:missing_token), do: "UNAUTHORIZED"
  defp error_code(_), do: "UNAUTHORIZED"
end
